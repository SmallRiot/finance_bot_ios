//
//  SettingsView.swift
//  MillionersBot
//
//  Настройки: базовая валюта, категории. Профиль и синк — на следующих этапах.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue
    @AppStorage("householdID") private var householdID: String = ""
    @Environment(CurrencyService.self) private var currency
    @Environment(SyncService.self) private var sync
    @Environment(AuthService.self) private var auth

    private var syncStatusText: String {
        guard !householdID.isEmpty else { return "Только на этом устройстве" }
        switch sync.status {
        case .idle: return "Не активна"
        case .syncing: return "В сети"
        case .error(let message): return "Ошибка: \(message)"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Валюта") {
                    Picker("Основная валюта", selection: $baseCurrency) {
                        ForEach(CurrencyCode.allCases) { code in
                            Text("\(code.displayName) (\(code.symbol))").tag(code.rawValue)
                        }
                    }
                }

                Section("Курсы валют") {
                    if let updatedAt = currency.updatedAt {
                        LabeledContent("Обновлено", value: updatedAt.formatted(.relative(presentation: .named)))
                    } else {
                        LabeledContent("Обновлено", value: "нет данных")
                    }
                    Button {
                        Task { await currency.refresh() }
                    } label: {
                        if currency.isLoading {
                            ProgressView()
                        } else {
                            Text("Обновить курсы")
                        }
                    }
                    .disabled(currency.isLoading)
                }

                Section("Данные") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Категории", systemImage: "tag")
                    }
                }

                Section("Синхронизация") {
                    LabeledContent("Статус", value: syncStatusText)
                    if let uid = auth.uid {
                        LabeledContent("ID профиля", value: String(uid.prefix(8)))
                    } else {
                        LabeledContent("Профиль", value: "Вход…")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(CurrencyService())
        .environment(AuthService())
        .environment(SyncService(context: PersistenceController.preview.mainContext))
        .modelContainer(PersistenceController.preview)
}
