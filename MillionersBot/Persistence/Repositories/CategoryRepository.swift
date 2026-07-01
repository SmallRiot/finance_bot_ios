//
//  CategoryRepository.swift
//  MillionersBot
//
//  CRUD по категориям + сид категорий по умолчанию.
//

import Foundation
import SwiftData

struct CategoryRepository {
    let context: ModelContext

    /// Все активные категории, отсортированные по порядку.
    func active() throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<Category>())
    }

    @discardableResult
    func add(name: String, icon: String, colorHex: String, householdID: String? = nil) -> Category {
        let nextOrder = ((try? active().count) ?? 0)
        let category = Category(
            name: name,
            iconSystemName: icon,
            colorHex: colorHex,
            householdID: householdID,
            sortOrder: nextOrder
        )
        context.insert(category)
        return category
    }

    func update(_ category: Category, name: String, icon: String, colorHex: String) {
        category.name = name
        category.iconSystemName = icon
        category.colorHex = colorHex
        category.updatedAt = .now
    }

    /// Переписывает sortOrder по новому порядку. updatedAt обновляется
    /// только у реально сдвинутых категорий — иначе лишний трафик синка
    /// и ложные конфликты last-write-wins.
    func reorder(_ ordered: [Category]) {
        for (index, category) in ordered.enumerated() where category.sortOrder != index {
            category.sortOrder = index
            category.updatedAt = .now
        }
    }

    /// Архивирование вместо удаления — чтобы не «осиротить» старые траты.
    func archive(_ category: Category) {
        category.isArchived = true
        category.updatedAt = .now
    }

    func delete(_ category: Category) {
        context.delete(category)
    }

    /// Создаёт стандартный набор категорий при первом запуске (если пусто).
    func seedDefaultsIfNeeded(householdID: String? = nil) throws {
        guard try count() == 0 else { return }
        for (index, item) in Self.defaults.enumerated() {
            let category = Category(
                name: item.name,
                iconSystemName: item.icon,
                colorHex: item.color,
                householdID: householdID,
                sortOrder: index
            )
            context.insert(category)
        }
        try context.save()
    }

    static let defaults: [(name: String, icon: String, color: String)] = [
        ("Продукты", "cart.fill", "#34C759"),
        ("Кафе и рестораны", "fork.knife", "#FF9500"),
        ("Транспорт", "car.fill", "#007AFF"),
        ("Дом", "house.fill", "#A2845E"),
        ("Развлечения", "gamecontroller.fill", "#AF52DE"),
        ("Здоровье", "cross.case.fill", "#FF3B30"),
        ("Одежда", "tshirt.fill", "#FF2D55"),
        ("Связь и подписки", "wifi", "#5AC8FA"),
        ("Прочее", "ellipsis.circle.fill", "#8E8E93"),
    ]
}
