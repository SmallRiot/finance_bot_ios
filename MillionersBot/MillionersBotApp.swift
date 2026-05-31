//
//  MillionersBotApp.swift
//  MillionersBot
//
//  Created by danila on 29.05.2026.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct MillionersBotApp: App {
    @State private var appState = AppState()
    @State private var auth = AuthService()
    @State private var groupService = GroupService()
    @State private var currency = CurrencyService()
    @State private var sync: SyncService
    private let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()
        let container = PersistenceController.makeContainer()
        modelContainer = container
        _sync = State(initialValue: SyncService(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(auth)
                .environment(groupService)
                .environment(currency)
                .environment(sync)
                .task {
                    await auth.bootstrap()
                }
                .task {
                    await currency.refreshIfNeeded()
                }
                .onChange(of: auth.uid, initial: true) { _, newValue in
                    appState.currentUserID = newValue
                }
        }
        .modelContainer(modelContainer)
    }
}
