//
//  SavingTransaction.swift
//  MillionersBot
//
//  Операция по накоплению: пополнение (+) или снятие (−) с комментарием.
//  История формирует график баланса. `isDeleted` — soft delete для синка.
//

import Foundation
import SwiftData

@Model
final class SavingTransaction {
    @Attribute(.unique) var id: String
    var savingID: String        // FK → Saving.id
    var amount: Decimal         // + пополнение, − снятие
    var note: String?           // комментарий
    var authorID: String?
    var householdID: String?
    var date: Date
    var isDeleted: Bool
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        savingID: String,
        amount: Decimal,
        note: String? = nil,
        authorID: String? = nil,
        householdID: String? = nil,
        date: Date = .now,
        isDeleted: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.savingID = savingID
        self.amount = amount
        self.note = note
        self.authorID = authorID
        self.householdID = householdID
        self.date = date
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}
