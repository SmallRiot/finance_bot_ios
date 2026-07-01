//
//  SavingRepository.swift
//  MillionersBot
//
//  CRUD по накоплениям/целям + пополнения.
//

import Foundation
import SwiftData

struct SavingRepository {
    let context: ModelContext

    @discardableResult
    func add(
        title: String,
        targetAmount: Decimal?,
        currencyCode: String,
        colorHex: String,
        householdID: String? = nil
    ) -> Saving {
        let saving = Saving(
            title: title,
            targetAmount: targetAmount,
            currentAmount: 0,
            currencyCode: currencyCode,
            colorHex: colorHex,
            householdID: householdID
        )
        context.insert(saving)
        return saving
    }

    func update(
        _ saving: Saving,
        title: String,
        targetAmount: Decimal?,
        currencyCode: String,
        colorHex: String
    ) {
        saving.title = title
        saving.targetAmount = targetAmount
        saving.currencyCode = currencyCode
        saving.colorHex = colorHex
        saving.updatedAt = .now
    }

    /// Пополнение/списание (amount может быть отрицательным).
    /// Дополнительно фиксирует операцию в истории (`SavingTransaction`).
    func addContribution(
        _ saving: Saving,
        amount: Decimal,
        note: String? = nil,
        authorID: String? = nil,
        householdID: String? = nil
    ) {
        saving.currentAmount = max(0, saving.currentAmount + amount)
        saving.updatedAt = .now
        context.insert(SavingTransaction(
            savingID: saving.id,
            amount: amount,
            note: note,
            authorID: authorID,
            householdID: householdID ?? saving.householdID,
            date: .now
        ))
    }

    /// Мягко удаляет операцию и корректирует текущий баланс накопления.
    func softDeleteTransaction(_ transaction: SavingTransaction, from saving: Saving) {
        transaction.isDeleted = true
        transaction.updatedAt = .now
        saving.currentAmount = max(0, saving.currentAmount - transaction.amount)
        saving.updatedAt = .now
    }

    /// Легаси: если у накопления есть баланс, но нет истории операций —
    /// заводим открывающую операцию, чтобы сумма операций сходилась с `currentAmount`.
    func ensureOpeningBalance(_ saving: Saving, transactions: [SavingTransaction]) {
        guard transactions.isEmpty, saving.currentAmount != 0 else { return }
        context.insert(SavingTransaction(
            savingID: saving.id,
            amount: saving.currentAmount,
            note: "Начальный баланс",
            authorID: nil,
            householdID: saving.householdID,
            date: saving.updatedAt
        ))
        try? context.save()
    }

    func softDelete(_ saving: Saving) {
        saving.isDeleted = true
        saving.updatedAt = .now
    }
}
