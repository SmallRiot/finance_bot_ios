//
//  SyncService.swift
//  MillionersBot
//
//  Двусторонняя синхронизация SwiftData ↔ Firestore в рамках одной семьи.
//
//  Pull: snapshot-listeners на households/{hid}/{expenses,categories,savings}
//        → upsert в SwiftData по правилу last-write-wins (updatedAt).
//  Push: после локального сохранения отправляем «свежие» записи в Firestore.
//
//  Защита от эха: после применения удалённых изменений двигаем watermark
//  до их updatedAt, поэтому они не считаются «свежими» и не уезжают обратно.
//

import Foundation
import Observation
import SwiftData
import FirebaseFirestore

@MainActor
@Observable
final class SyncService {
    enum Status: Equatable {
        case idle, syncing, error(String)
    }

    private(set) var status: Status = .idle

    private let context: ModelContext
    private var db: Firestore { Firestore.firestore() }

    private var householdID: String?
    private var listeners: [ListenerRegistration] = []
    private var saveObserver: NSObjectProtocol?

    /// Записи новее этого момента считаются локально изменёнными и пушатся.
    private var watermark: Date = .distantPast
    private var isApplyingRemote = false

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Жизненный цикл

    func start(householdID: String) {
        guard self.householdID != householdID else { return }
        stop()
        self.householdID = householdID
        status = .syncing
        attachListeners(householdID)
        observeLocalSaves()
        pushDirty() // отправим то, что накопилось локально
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
            self.saveObserver = nil
        }
        householdID = nil
        watermark = .distantPast
        status = .idle
    }

    // MARK: - Pull (Firestore → SwiftData)

    private func collection(_ hid: String, _ name: String) -> CollectionReference {
        db.collection("households").document(hid).collection(name)
    }

    private func attachListeners(_ hid: String) {
        listeners.append(collection(hid, "categories").addSnapshotListener { snapshot, _ in
            let dtos = snapshot?.documents.compactMap { try? $0.data(as: CategoryDTO.self) } ?? []
            Task { @MainActor in self.applyCategories(dtos) }
        })
        listeners.append(collection(hid, "expenses").addSnapshotListener { snapshot, _ in
            let dtos = snapshot?.documents.compactMap { try? $0.data(as: ExpenseDTO.self) } ?? []
            Task { @MainActor in self.applyExpenses(dtos) }
        })
        listeners.append(collection(hid, "savings").addSnapshotListener { snapshot, _ in
            let dtos = snapshot?.documents.compactMap { try? $0.data(as: SavingDTO.self) } ?? []
            Task { @MainActor in self.applySavings(dtos) }
        })
        listeners.append(collection(hid, "members").addSnapshotListener { snapshot, _ in
            let dtos = snapshot?.documents.compactMap { try? $0.data(as: MemberDTO.self) } ?? []
            Task { @MainActor in self.applyMembers(dtos) }
        })
        listeners.append(collection(hid, "recurring").addSnapshotListener { snapshot, _ in
            let dtos = snapshot?.documents.compactMap { try? $0.data(as: RecurringExpenseDTO.self) } ?? []
            Task { @MainActor in self.applyRecurring(dtos) }
        })
    }

    private func applyMembers(_ dtos: [MemberDTO]) {
        withRemoteApply {
            for dto in dtos {
                if let existing = fetchProfile(dto.id) {
                    guard dto.updatedAt > existing.updatedAt else { continue }
                    existing.displayName = dto.displayName
                    existing.avatarColorHex = dto.avatarColorHex
                    existing.updatedAt = dto.updatedAt
                } else {
                    let profile = UserProfile(id: dto.id, displayName: dto.displayName,
                                              avatarColorHex: dto.avatarColorHex,
                                              householdID: householdID, updatedAt: dto.updatedAt)
                    context.insert(profile)
                }
                watermark = max(watermark, dto.updatedAt)
            }
        }
    }

    private func applyCategories(_ dtos: [CategoryDTO]) {
        guard let hid = householdID else { return }
        withRemoteApply {
            for dto in dtos {
                let existing = fetchCategory(dto.id)
                if let existing {
                    guard dto.updatedAt > existing.updatedAt else { continue }
                    existing.name = dto.name
                    existing.iconSystemName = dto.iconSystemName
                    existing.colorHex = dto.colorHex
                    existing.isArchived = dto.isArchived
                    existing.sortOrder = dto.sortOrder
                    existing.monthlyLimit = dto.monthlyLimit.flatMap { Decimal(string: $0) }
                    existing.householdID = hid
                    existing.updatedAt = dto.updatedAt
                } else {
                    let c = Category(id: dto.id, name: dto.name, iconSystemName: dto.iconSystemName,
                                     colorHex: dto.colorHex, householdID: hid, isArchived: dto.isArchived,
                                     sortOrder: dto.sortOrder,
                                     monthlyLimit: dto.monthlyLimit.flatMap { Decimal(string: $0) },
                                     updatedAt: dto.updatedAt)
                    context.insert(c)
                }
                watermark = max(watermark, dto.updatedAt)
            }
        }
    }

    private func applyExpenses(_ dtos: [ExpenseDTO]) {
        guard let hid = householdID else { return }
        withRemoteApply {
            for dto in dtos {
                let existing = fetchExpense(dto.id)
                if let existing {
                    guard dto.updatedAt > existing.updatedAt else { continue }
                    existing.amount = Money.parse(dto.amount) ?? existing.amount
                    existing.currencyCode = dto.currencyCode
                    existing.categoryID = dto.categoryID
                    existing.authorID = dto.authorID
                    existing.note = dto.note
                    existing.date = dto.date
                    existing.isDeleted = dto.isDeleted
                    existing.householdID = hid
                    existing.updatedAt = dto.updatedAt
                } else {
                    let e = Expense(id: dto.id, amount: Money.parse(dto.amount) ?? 0,
                                    currencyCode: dto.currencyCode, categoryID: dto.categoryID,
                                    authorID: dto.authorID, note: dto.note, date: dto.date,
                                    householdID: hid, isDeleted: dto.isDeleted, updatedAt: dto.updatedAt)
                    context.insert(e)
                }
                watermark = max(watermark, dto.updatedAt)
            }
        }
    }

    private func applyRecurring(_ dtos: [RecurringExpenseDTO]) {
        guard let hid = householdID else { return }
        withRemoteApply {
            for dto in dtos {
                let existing = fetchRecurring(dto.id)
                if let existing {
                    guard dto.updatedAt > existing.updatedAt else { continue }
                    existing.amount = Money.parse(dto.amount) ?? existing.amount
                    existing.currencyCode = dto.currencyCode
                    existing.categoryID = dto.categoryID
                    existing.note = dto.note
                    existing.authorID = dto.authorID
                    existing.anchorDate = dto.anchorDate
                    existing.lastPostedPeriod = dto.lastPostedPeriod
                    existing.isActive = dto.isActive
                    existing.isDeleted = dto.isDeleted
                    existing.householdID = hid
                    existing.updatedAt = dto.updatedAt
                } else {
                    let r = RecurringExpense(id: dto.id, amount: Money.parse(dto.amount) ?? 0,
                                             currencyCode: dto.currencyCode, categoryID: dto.categoryID,
                                             note: dto.note, authorID: dto.authorID, householdID: hid,
                                             anchorDate: dto.anchorDate, lastPostedPeriod: dto.lastPostedPeriod,
                                             isActive: dto.isActive, isDeleted: dto.isDeleted,
                                             updatedAt: dto.updatedAt)
                    context.insert(r)
                }
                watermark = max(watermark, dto.updatedAt)
            }
        }
    }

    private func applySavings(_ dtos: [SavingDTO]) {
        guard let hid = householdID else { return }
        withRemoteApply {
            for dto in dtos {
                let existing = fetchSaving(dto.id)
                if let existing {
                    guard dto.updatedAt > existing.updatedAt else { continue }
                    existing.title = dto.title
                    existing.targetAmount = dto.targetAmount.flatMap { Money.parse($0) }
                    existing.currentAmount = Money.parse(dto.currentAmount) ?? existing.currentAmount
                    existing.currencyCode = dto.currencyCode
                    existing.colorHex = dto.colorHex
                    existing.isDeleted = dto.isDeleted
                    existing.householdID = hid
                    existing.updatedAt = dto.updatedAt
                } else {
                    let s = Saving(id: dto.id, title: dto.title,
                                   targetAmount: dto.targetAmount.flatMap { Money.parse($0) },
                                   currentAmount: Money.parse(dto.currentAmount) ?? 0,
                                   currencyCode: dto.currencyCode, colorHex: dto.colorHex,
                                   householdID: hid, isDeleted: dto.isDeleted, updatedAt: dto.updatedAt)
                    context.insert(s)
                }
                watermark = max(watermark, dto.updatedAt)
            }
        }
    }

    // MARK: - Push (SwiftData → Firestore)

    private func observeLocalSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: nil
        ) { _ in
            Task { @MainActor in self.pushDirty() }
        }
    }

    private func pushDirty() {
        guard let hid = householdID, !isApplyingRemote else { return }
        var newWatermark = watermark

        for e in (fetchAll(Expense.self)) where e.householdID == hid && e.updatedAt > watermark {
            try? collection(hid, "expenses").document(e.id).setData(from: ExpenseDTO(e))
            newWatermark = max(newWatermark, e.updatedAt)
        }
        for c in (fetchAll(Category.self)) where c.householdID == hid && c.updatedAt > watermark {
            try? collection(hid, "categories").document(c.id).setData(from: CategoryDTO(c))
            newWatermark = max(newWatermark, c.updatedAt)
        }
        for s in (fetchAll(Saving.self)) where s.householdID == hid && s.updatedAt > watermark {
            try? collection(hid, "savings").document(s.id).setData(from: SavingDTO(s))
            newWatermark = max(newWatermark, s.updatedAt)
        }
        for p in (fetchAll(UserProfile.self)) where p.householdID == hid && p.updatedAt > watermark {
            try? collection(hid, "members").document(p.id).setData(from: MemberDTO(p))
            newWatermark = max(newWatermark, p.updatedAt)
        }
        for r in (fetchAll(RecurringExpense.self)) where r.householdID == hid && r.updatedAt > watermark {
            try? collection(hid, "recurring").document(r.id).setData(from: RecurringExpenseDTO(r))
            newWatermark = max(newWatermark, r.updatedAt)
        }
        watermark = newWatermark
    }

    // MARK: - Усыновление локальных данных при создании семьи

    /// Привязывает все «ничейные» локальные записи к семье (и пушит их).
    func adoptLocalData(into hid: String) {
        let now = Date()
        for e in fetchAll(Expense.self) where e.householdID == nil {
            e.householdID = hid; e.updatedAt = now
        }
        for c in fetchAll(Category.self) where c.householdID == nil {
            c.householdID = hid; c.updatedAt = now
        }
        for s in fetchAll(Saving.self) where s.householdID == nil {
            s.householdID = hid; s.updatedAt = now
        }
        for p in fetchAll(UserProfile.self) where p.householdID == nil {
            p.householdID = hid; p.updatedAt = now
        }
        for r in fetchAll(RecurringExpense.self) where r.householdID == nil {
            r.householdID = hid; r.updatedAt = now
        }
        try? context.save()
    }

    // MARK: - Helpers

    private func withRemoteApply(_ work: () -> Void) {
        isApplyingRemote = true
        work()
        try? context.save()
        isApplyingRemote = false
    }

    private func fetchCategory(_ id: String) -> Category? {
        try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchExpense(_ id: String) -> Expense? {
        try? context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchSaving(_ id: String) -> Saving? {
        try? context.fetch(FetchDescriptor<Saving>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchRecurring(_ id: String) -> RecurringExpense? {
        try? context.fetch(FetchDescriptor<RecurringExpense>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchProfile(_ id: String) -> UserProfile? {
        try? context.fetch(FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}
