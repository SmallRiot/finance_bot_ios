//
//  PersistenceController.swift
//  MillionersBot
//
//  Конфигурация SwiftData ModelContainer — локальный слой данных.
//

import Foundation
import SwiftData

enum PersistenceController {

    /// Полная схема приложения. При добавлении новой @Model — дописать сюда.
    static let schema = Schema([
        UserProfile.self,
        Household.self,
        Category.self,
        Expense.self,
        Saving.self,
    ])

    /// Основной контейнер. `inMemory` используется для превью и тестов.
    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    /// Контейнер в памяти для SwiftUI-превью.
    @MainActor
    static let preview: ModelContainer = makeContainer(inMemory: true)
}
