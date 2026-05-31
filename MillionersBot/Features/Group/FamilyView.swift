//
//  FamilyView.swift
//  MillionersBot
//
//  Семейный доступ: создание группы, инвайт-код, вступление по коду, выход.
//

import SwiftUI
import SwiftData

struct FamilyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth
    @Environment(GroupService.self) private var groupService
    @Environment(SyncService.self) private var sync

    @AppStorage("householdID") private var householdID: String = ""
    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue
    @AppStorage("displayName") private var displayName: String = ""

    @Query private var households: [Household]
    @Query private var profiles: [UserProfile]

    @State private var showCreate = false
    @State private var showJoin = false
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool

    private var currentHousehold: Household? {
        households.first { $0.id == householdID }
    }

    private func memberName(_ id: String) -> String {
        if id == auth.uid {
            return displayName.isEmpty ? "Вы" : "\(displayName) (вы)"
        }
        if let profile = profiles.first(where: { $0.id == id }), !profile.displayName.isEmpty {
            return profile.displayName
        }
        return "Участник " + id.prefix(4)
    }

    var body: some View {
        NavigationStack {
            Group {
                if householdID.isEmpty {
                    noGroupState
                } else {
                    groupDetails
                }
            }
            .navigationTitle("Семья")
            .sheet(isPresented: $showCreate) {
                CreateHouseholdSheet { apply($0, adopt: true) }
            }
            .sheet(isPresented: $showJoin) {
                JoinHouseholdSheet { apply($0, adopt: false) }
            }
        }
    }

    private var noGroupState: some View {
        ContentUnavailableView {
            Label("Семейный доступ", systemImage: "person.2")
        } description: {
            Text("Создайте семью и пригласите близких по коду — бюджет будет общим.")
        } actions: {
            VStack(spacing: 12) {
                Button("Создать семью") { showCreate = true }
                    .buttonStyle(.borderedProminent)
                Button("Войти по коду") { showJoin = true }
                    .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var groupDetails: some View {
        List {
            Section {
                HStack {
                    TextField("Как вас зовут", text: $nameDraft)
                        .focused($nameFocused)
                        .onSubmit(saveName)
                    if nameDraft.trimmingCharacters(in: .whitespaces) != displayName
                        && !nameDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Сохранить", action: saveName)
                            .font(.subheadline)
                    }
                }
            } header: {
                Text("Ваше имя")
            } footer: {
                Text("Это имя увидят другие участники семьи рядом с вашими тратами.")
            }

            Section {
                LabeledContent("Название", value: currentHousehold?.name ?? "Семья")
                if let code = currentHousehold?.inviteCode {
                    HStack {
                        Text("Код приглашения")
                        Spacer()
                        Text(code)
                            .font(.body.monospaced().weight(.bold))
                        ShareLink(item: "Присоединяйся к нашему бюджету в MillionersBot. Код: \(code)") {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            } footer: {
                Text("Поделитесь кодом — близкие смогут войти в общий бюджет на своём устройстве.")
            }

            Section("Участники") {
                ForEach(currentHousehold?.memberIDs ?? [], id: \.self) { member in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                        Text(memberName(member))
                    }
                }
            }

            Section {
                Button("Выйти из семьи", role: .destructive, action: leave)
            }
        }
        .onAppear { nameDraft = displayName }
    }

    private func saveName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uid = auth.uid, !trimmed.isEmpty else { return }
        displayName = trimmed
        nameFocused = false
        if let profile = profiles.first(where: { $0.id == uid }) {
            profile.displayName = trimmed
            if !householdID.isEmpty { profile.householdID = householdID }
            profile.updatedAt = .now
        } else {
            let profile = UserProfile(id: uid, displayName: trimmed,
                                      householdID: householdID.isEmpty ? nil : householdID)
            context.insert(profile)
        }
        try? context.save()
    }

    /// Применяет результат создания/вступления: зеркалит в SwiftData + сохраняет id.
    /// adopt=true (создание) — привязывает существующие локальные данные к семье.
    private func apply(_ info: HouseholdInfo, adopt: Bool) {
        if let existing = households.first(where: { $0.id == info.id }) {
            existing.name = info.name
            existing.inviteCode = info.inviteCode
            existing.memberIDs = info.memberIDs
            existing.baseCurrencyCode = info.baseCurrency
            existing.updatedAt = .now
        } else {
            let household = Household(
                id: info.id,
                name: info.name,
                inviteCode: info.inviteCode,
                memberIDs: info.memberIDs,
                baseCurrencyCode: info.baseCurrency
            )
            context.insert(household)
        }
        householdID = info.id              // запускает sync.start через RootView.onChange
        ensureProfileInHousehold(info.id)
        if adopt {
            sync.adoptLocalData(into: info.id)
        }
    }

    /// Гарантирует, что профиль пользователя привязан к семье и уедет в синк.
    private func ensureProfileInHousehold(_ hid: String) {
        guard let uid = auth.uid else { return }
        if let profile = profiles.first(where: { $0.id == uid }) {
            profile.householdID = hid
            profile.updatedAt = .now
        } else {
            let name = displayName.isEmpty ? "Участник \(uid.prefix(4))" : displayName
            context.insert(UserProfile(id: uid, displayName: name, householdID: hid))
        }
        try? context.save()
    }

    private func leave() {
        guard let uid = auth.uid, !householdID.isEmpty else { return }
        let leavingID = householdID
        Task { await groupService.leaveHousehold(id: leavingID, uid: uid) }
        if let household = households.first(where: { $0.id == leavingID }) {
            context.delete(household)
        }
        householdID = ""
    }
}

// MARK: - Создание группы

private struct CreateHouseholdSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(GroupService.self) private var groupService
    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue

    let onCreated: (HouseholdInfo) -> Void
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название семьи", text: $name)
                if let error = groupService.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Новая семья")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать", action: create)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || groupService.isWorking)
                }
            }
        }
    }

    private func create() {
        guard let uid = auth.uid else { return }
        Task {
            if let info = await groupService.createHousehold(
                name: name.trimmingCharacters(in: .whitespaces),
                uid: uid,
                baseCurrency: baseCurrency
            ) {
                onCreated(info)
                dismiss()
            }
        }
    }
}

// MARK: - Вступление по коду

private struct JoinHouseholdSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(GroupService.self) private var groupService

    let onJoined: (HouseholdInfo) -> Void
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Код приглашения", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title3.monospaced())
                if let error = groupService.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Войти по коду")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Войти", action: join)
                        .disabled(code.trimmingCharacters(in: .whitespaces).count < 4 || groupService.isWorking)
                }
            }
        }
    }

    private func join() {
        guard let uid = auth.uid else { return }
        Task {
            if let info = await groupService.joinHousehold(inviteCode: code, uid: uid) {
                onJoined(info)
                dismiss()
            }
        }
    }
}

#Preview {
    FamilyView()
        .environment(AppState())
        .environment(AuthService())
        .environment(GroupService())
        .modelContainer(PersistenceController.preview)
}
