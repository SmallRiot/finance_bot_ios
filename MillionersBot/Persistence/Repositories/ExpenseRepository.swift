//
//  ExpenseRepository.swift
//  MillionersBot
//
//  CRUD по тратам. Удаление — мягкое (isDeleted) для корректного синка.
//

import Foundation
import SwiftData

struct ExpenseRepository {
    let context: ModelContext

    @discardableResult
    func add(
        amount: Decimal,
        currencyCode: String,
        categoryID: String?,
        note: String?,
        date: Date,
        authorID: String? = nil,
        householdID: String? = nil
    ) -> Expense {
        let expense = Expense(
            amount: amount,
            currencyCode: currencyCode,
            categoryID: categoryID,
            authorID: authorID,
            note: note,
            date: date,
            householdID: householdID
        )
        context.insert(expense)
        return expense
    }

    func update(
        _ expense: Expense,
        amount: Decimal,
        currencyCode: String,
        categoryID: String?,
        note: String?,
        date: Date
    ) {
        expense.amount = amount
        expense.currencyCode = currencyCode
        expense.categoryID = categoryID
        expense.note = note
        expense.date = date
        expense.updatedAt = .now
    }

    /// Мягкое удаление: помечаем isDeleted, чтобы синк удалил запись и в облаке.
    func softDelete(_ expense: Expense) {
        expense.isDeleted = true
        expense.updatedAt = .now
    }
}
