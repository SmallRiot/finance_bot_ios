//
//  RootView.swift
//  MillionersBot
//
//  Корневой экран: TabView с пятью вкладками.
//

import SwiftUI
import SwiftData
#if DEBUG
import FirebaseFirestore
#endif

enum AppTab: Hashable {
    case expenses, shopping, stats, savings, family, settings
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncService.self) private var sync
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var appState
    @AppStorage("householdID") private var householdID: String = ""
    @AppStorage("didOnboard") private var didOnboard: Bool = false
    @State private var selection: AppTab = RootView.initialTab

    var body: some View {
        TabView(selection: $selection) {
            Tab("Траты", systemImage: "list.bullet.rectangle", value: AppTab.expenses) {
                ExpensesView()
            }
            Tab("Покупки", systemImage: "cart", value: AppTab.shopping) {
                ShoppingListView()
            }
            Tab("Статистика", systemImage: "chart.pie", value: AppTab.stats) {
                StatsView()
            }
            Tab("Сбережения", systemImage: "banknote", value: AppTab.savings) {
                SavingsView()
            }
            Tab("Семья", systemImage: "person.2", value: AppTab.family) {
                FamilyView()
            }
            Tab("Настройки", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .task {
            #if DEBUG
            if CommandLine.arguments.contains("-seedSampleData") {
                SampleData.seed(into: context)
                return
            }
            #endif
        }
        .onChange(of: householdID, initial: true) { _, id in
            if id.isEmpty {
                // Личная область: сеем дефолтные категории, если их нет
                // (первый запуск или возврат после выхода из семьи).
                try? CategoryRepository(context: context).seedDefaultsIfNeeded(householdID: nil)
                sync.stop()
            } else {
                sync.start(householdID: id)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "millionersbot", url.host == "add" else { return }
            selection = .expenses
            appState.pendingAddExpense = true
        }
        .fullScreenCover(isPresented: .constant(!didOnboard)) {
            OnboardingView { didOnboard = true }
        }
        #if DEBUG
        .task { await runDebugSyncIfRequested() }
        #endif
    }

    #if DEBUG
    /// Смоук-тест синхронизации без UI:
    /// -debugHousehold <id> — войти в общий household-док <id> (создав/доединившись).
    /// -addExpense — дополнительно добавить трату (для устройства-источника).
    private func runDebugSyncIfRequested() async {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "-debugHousehold"), idx + 1 < args.count else { return }
        let hid = args[idx + 1]

        for _ in 0..<50 where auth.uid == nil {
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard let uid = auth.uid else { return }

        let db = Firestore.firestore()
        try? await db.collection("households").document(hid).setData([
            "name": "Тест семья",
            "inviteCode": "TESTAA",
            "memberIDs": FieldValue.arrayUnion([uid]),
            "baseCurrency": "RUB",
        ], merge: true)

        householdID = hid

        if args.contains("-addExpense") {
            sync.adoptLocalData(into: hid) // как при создании семьи — шарим категории
            try? await Task.sleep(for: .seconds(1))
            let category = try? CategoryRepository(context: context).active().first
            ExpenseRepository(context: context).add(
                amount: 777,
                currencyCode: "RUB",
                categoryID: category?.id,
                note: "СинкТест",
                date: .now,
                householdID: hid
            )
            try? context.save()
        }
    }
    #endif

    /// Стартовая вкладка. В DEBUG можно переопределить аргументом `-tab stats|savings|...`.
    private static var initialTab: AppTab {
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "-tab"),
           index + 1 < CommandLine.arguments.count {
            switch CommandLine.arguments[index + 1] {
            case "shopping": return .shopping
            case "stats": return .stats
            case "savings": return .savings
            case "family": return .family
            case "settings": return .settings
            default: break
            }
        }
        #endif
        return .expenses
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .modelContainer(PersistenceController.preview)
}
