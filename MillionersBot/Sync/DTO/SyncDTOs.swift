//
//  SyncDTOs.swift
//  MillionersBot
//
//  Codable-зеркала моделей для документов Firestore.
//  Деньги храним строкой, чтобы не терять точность Decimal через Double.
//

import Foundation

struct CategoryDTO: Codable {
    var id: String
    var name: String
    var iconSystemName: String
    var colorHex: String
    var isArchived: Bool
    var sortOrder: Int
    var updatedAt: Date

    init(_ m: Category) {
        id = m.id
        name = m.name
        iconSystemName = m.iconSystemName
        colorHex = m.colorHex
        isArchived = m.isArchived
        sortOrder = m.sortOrder
        updatedAt = m.updatedAt
    }
}

struct ExpenseDTO: Codable {
    var id: String
    var amount: String
    var currencyCode: String
    var categoryID: String?
    var authorID: String?
    var note: String?
    var date: Date
    var isDeleted: Bool
    var updatedAt: Date

    init(_ m: Expense) {
        id = m.id
        amount = "\(m.amount)"
        currencyCode = m.currencyCode
        categoryID = m.categoryID
        authorID = m.authorID
        note = m.note
        date = m.date
        isDeleted = m.isDeleted
        updatedAt = m.updatedAt
    }
}

struct SavingDTO: Codable {
    var id: String
    var title: String
    var targetAmount: String?
    var currentAmount: String
    var currencyCode: String
    var colorHex: String
    var isDeleted: Bool
    var updatedAt: Date

    init(_ m: Saving) {
        id = m.id
        title = m.title
        targetAmount = m.targetAmount.map { "\($0)" }
        currentAmount = "\(m.currentAmount)"
        currencyCode = m.currencyCode
        colorHex = m.colorHex
        isDeleted = m.isDeleted
        updatedAt = m.updatedAt
    }
}
