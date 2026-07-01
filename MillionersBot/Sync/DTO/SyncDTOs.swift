//
//  SyncDTOs.swift
//  MillionersBot
//
//  Codable-зеркала моделей для документов Firestore.
//  Деньги храним строкой, чтобы не терять точность Decimal через Double.
//

import Foundation

struct MemberDTO: Codable {
    var id: String
    var displayName: String
    var avatarColorHex: String
    var updatedAt: Date

    init(_ m: UserProfile) {
        id = m.id
        displayName = m.displayName
        avatarColorHex = m.avatarColorHex
        updatedAt = m.updatedAt
    }
}

struct CategoryDTO: Codable {
    var id: String
    var name: String
    var iconSystemName: String
    var colorHex: String
    var isArchived: Bool
    var sortOrder: Int
    var monthlyLimit: String?
    var updatedAt: Date

    init(_ m: Category) {
        id = m.id
        name = m.name
        iconSystemName = m.iconSystemName
        colorHex = m.colorHex
        isArchived = m.isArchived
        sortOrder = m.sortOrder
        monthlyLimit = m.monthlyLimit.map { "\($0)" }
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

struct SavingTransactionDTO: Codable {
    var id: String
    var savingID: String
    var amount: String
    var note: String?
    var authorID: String?
    var date: Date
    var isDeleted: Bool
    var updatedAt: Date

    init(_ m: SavingTransaction) {
        id = m.id
        savingID = m.savingID
        amount = "\(m.amount)"
        note = m.note
        authorID = m.authorID
        date = m.date
        isDeleted = m.isDeleted
        updatedAt = m.updatedAt
    }
}

struct RecurringExpenseDTO: Codable {
    var id: String
    var amount: String
    var currencyCode: String
    var categoryID: String?
    var note: String?
    var authorID: String?
    var anchorDate: Date
    var lastPostedPeriod: String
    var isActive: Bool
    var isDeleted: Bool
    var updatedAt: Date

    init(_ m: RecurringExpense) {
        id = m.id
        amount = "\(m.amount)"
        currencyCode = m.currencyCode
        categoryID = m.categoryID
        note = m.note
        authorID = m.authorID
        anchorDate = m.anchorDate
        lastPostedPeriod = m.lastPostedPeriod
        isActive = m.isActive
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
