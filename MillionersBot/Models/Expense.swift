//
//  Expense.swift
//  MillionersBot
//
//  Трата. Деньги храним в Decimal (точность), а не Double.
//  `isDeleted` — soft delete для корректной синхронизации с Firestore.
//

import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var currencyCode: String
    var categoryID: String?
    var authorID: String?
    var note: String?
    var date: Date
    var householdID: String?
    var isDeleted: Bool
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        currencyCode: String = CurrencyCode.default.rawValue,
        categoryID: String? = nil,
        authorID: String? = nil,
        note: String? = nil,
        date: Date = .now,
        householdID: String? = nil,
        isDeleted: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.categoryID = categoryID
        self.authorID = authorID
        self.note = note
        self.date = date
        self.householdID = householdID
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}
