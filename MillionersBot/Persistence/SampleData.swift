//
//  SampleData.swift
//  MillionersBot
//
//  Демо-данные для разработки и превью. Активируется только в DEBUG
//  через launch-аргумент `-seedSampleData` (см. RootView).
//

import Foundation
import SwiftData

enum SampleData {

    /// Засевает категории (если пусто) и набор трат за последние ~50 дней.
    /// Идемпотентно по флагу: повторно не добавляет, если траты уже есть.
    @MainActor
    static func seed(into context: ModelContext) {
        let categoryRepo = CategoryRepository(context: context)
        try? categoryRepo.seedDefaultsIfNeeded()

        let existing = (try? context.fetchCount(FetchDescriptor<Expense>())) ?? 0
        guard existing == 0 else { return }

        let categories = (try? categoryRepo.active()) ?? []
        guard !categories.isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()
        var rng = SystemRandomNumberGenerator()

        let notes = ["", "", "Магнит", "обед", "такси", "кофе", "подписка", "аптека"]
        let expenseRepo = ExpenseRepository(context: context)

        for dayOffset in 0..<50 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let countToday = Int.random(in: 0...3, using: &rng)
            for _ in 0..<countToday {
                let category = categories.randomElement(using: &rng)!
                // В основном рубли, иногда USD/EUR — чтобы проверить конвертацию в статистике.
                let roll = Int.random(in: 0...9, using: &rng)
                let currency: CurrencyCode = roll == 0 ? .usd : (roll == 1 ? .eur : .rub)
                let amount: Decimal = currency == .rub
                    ? Decimal(Int.random(in: 50...4500, using: &rng))
                    : Decimal(Int.random(in: 5...120, using: &rng))
                expenseRepo.add(
                    amount: amount,
                    currencyCode: currency.rawValue,
                    categoryID: category.id,
                    note: notes.randomElement(using: &rng),
                    date: day
                )
            }
        }

        // Демо-цели
        let savingRepo = SavingRepository(context: context)
        let goal1 = savingRepo.add(title: "Отпуск", targetAmount: 150_000, currencyCode: CurrencyCode.default.rawValue, colorHex: "#007AFF")
        savingRepo.addContribution(goal1, amount: 92_000)
        let goal2 = savingRepo.add(title: "Подушка безопасности", targetAmount: 300_000, currencyCode: CurrencyCode.default.rawValue, colorHex: "#34C759")
        savingRepo.addContribution(goal2, amount: 120_000)
        let goal3 = savingRepo.add(title: "Новый ноутбук", targetAmount: nil, currencyCode: CurrencyCode.default.rawValue, colorHex: "#AF52DE")
        savingRepo.addContribution(goal3, amount: 35_000)

        try? context.save()
    }
}
