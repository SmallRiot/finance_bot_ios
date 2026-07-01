//
//  RecurringExpense.swift
//  MillionersBot
//
//  Правило ежемесячной траты. Хранит «якорную» дату (число месяца + время суток)
//  и последний созданный месяц. Движок постинга сам создаёт Expense каждый месяц.
//  `isDeleted` — soft delete для корректной синхронизации с Firestore.
//

import Foundation
import SwiftData

@Model
final class RecurringExpense {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var currencyCode: String
    var categoryID: String?
    var note: String?
    var authorID: String?
    var householdID: String?
    /// Исходная дата: даёт число месяца и время суток для будущих occurrence.
    var anchorDate: Date
    /// "yyyy-MM" последнего созданного месяца ("" — ни разу).
    var lastPostedPeriod: String
    var isActive: Bool
    var isDeleted: Bool
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        currencyCode: String = CurrencyCode.default.rawValue,
        categoryID: String? = nil,
        note: String? = nil,
        authorID: String? = nil,
        householdID: String? = nil,
        anchorDate: Date = .now,
        lastPostedPeriod: String = "",
        isActive: Bool = true,
        isDeleted: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.categoryID = categoryID
        self.note = note
        self.authorID = authorID
        self.householdID = householdID
        self.anchorDate = anchorDate
        self.lastPostedPeriod = lastPostedPeriod
        self.isActive = isActive
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}
