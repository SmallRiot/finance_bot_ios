//
//  RecurringService.swift
//  MillionersBot
//
//  Движок постинга регулярных (ежемесячных) трат.
//  Для каждого активного правила автоматически создаёт Expense за каждый
//  пропущенный месяц вплоть до текущего. Occurrence id детерминированный
//  ("\(ruleID)#\(yyyy-MM)"), поэтому два устройства семьи не задваивают трату.
//

import Foundation
import SwiftData

enum RecurringService {

    /// Создаёт недостающие ежемесячные траты по всем активным правилам.
    @MainActor
    static func postDue(context: ModelContext) {
        let now = Date()
        let cal = Calendar.current

        let rules = (try? context.fetch(FetchDescriptor<RecurringExpense>(
            predicate: #Predicate { $0.isActive && !$0.isDeleted }
        ))) ?? []

        for rule in rules {
            let anchor = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: rule.anchorDate)
            guard let anchorDay = anchor.day else { continue }

            // Начальный месяц: следующий после lastPostedPeriod, иначе — месяц anchorDate.
            var year: Int
            var month: Int
            if let (ly, lm) = parsePeriod(rule.lastPostedPeriod) {
                (year, month) = advance(year: ly, month: lm)
            } else if let ay = anchor.year, let am = anchor.month {
                (year, month) = (ay, am)
            } else {
                continue
            }

            var changed = false
            var iterations = 0
            while iterations < 60 {
                iterations += 1
                let period = periodString(year: year, month: month)

                // День месяца ограничиваем длиной месяца (например, 31 → 28/29 в феврале).
                guard let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)),
                      let daysRange = cal.range(of: .day, in: .month, for: firstOfMonth) else { break }
                let day = min(anchorDay, daysRange.count)

                guard let occDate = cal.date(from: DateComponents(
                    year: year, month: month, day: day,
                    hour: anchor.hour, minute: anchor.minute, second: anchor.second
                )) else { break }

                if occDate > now { break }

                let occID = "\(rule.id)#\(period)"
                if fetchExpense(occID, context: context) == nil {
                    let expense = Expense(
                        id: occID,
                        amount: rule.amount,
                        currencyCode: rule.currencyCode,
                        categoryID: rule.categoryID,
                        authorID: rule.authorID,
                        note: rule.note,
                        date: occDate,
                        householdID: rule.householdID
                    )
                    context.insert(expense)
                }

                rule.lastPostedPeriod = period
                changed = true
                (year, month) = advance(year: year, month: month)
            }

            if changed { rule.updatedAt = now }
        }

        try? context.save()
    }

    // MARK: - Helpers

    private static func fetchExpense(_ id: String, context: ModelContext) -> Expense? {
        try? context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })).first
    }

    /// "yyyy-MM" из года и месяца.
    private static func periodString(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    /// Разбирает "yyyy-MM" в (год, месяц). "" или мусор → nil.
    private static func parsePeriod(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        return (y, m)
    }

    /// Следующий месяц.
    private static func advance(year: Int, month: Int) -> (Int, Int) {
        month == 12 ? (year + 1, 1) : (year, month + 1)
    }
}
