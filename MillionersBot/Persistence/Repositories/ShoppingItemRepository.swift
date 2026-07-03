//
//  ShoppingItemRepository.swift
//  MillionersBot
//
//  CRUD по совместному списку покупок. Новые позиции — наверху (меньший sortOrder).
//

import Foundation
import SwiftData

struct ShoppingItemRepository {
    let context: ModelContext

    /// Живые позиции текущей области, новые сверху (некупленные над купленными).
    func active(in householdID: String?) -> [ShoppingItem] {
        let all = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        return all
            .filter { !$0.isDeleted && $0.householdID == householdID }
            .sorted { lhs, rhs in
                if lhs.isPurchased != rhs.isPurchased { return !lhs.isPurchased }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    @discardableResult
    func add(
        title: String,
        note: String? = nil,
        authorID: String? = nil,
        householdID: String? = nil
    ) -> ShoppingItem {
        // Новая позиция встаёт над всеми: минимальный sortOrder в области − 1.
        let minOrder = active(in: householdID).map(\.sortOrder).min() ?? 0
        let item = ShoppingItem(
            title: title,
            note: note,
            authorID: authorID,
            householdID: householdID,
            sortOrder: minOrder - 1
        )
        context.insert(item)
        return item
    }

    /// Отметить купленным / вернуть в список.
    func togglePurchased(_ item: ShoppingItem) {
        item.isPurchased.toggle()
        item.updatedAt = .now
    }

    func rename(_ item: ShoppingItem, title: String, note: String?) {
        item.title = title
        item.note = note
        item.updatedAt = .now
    }

    func softDelete(_ item: ShoppingItem) {
        item.isDeleted = true
        item.updatedAt = .now
    }

    /// Убирает из списка всё купленное (soft delete для корректного синка).
    func clearPurchased(in householdID: String?) {
        for item in active(in: householdID) where item.isPurchased {
            item.isDeleted = true
            item.updatedAt = .now
        }
    }
}
