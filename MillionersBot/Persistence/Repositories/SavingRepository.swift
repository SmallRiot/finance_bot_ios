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
    func addContribution(_ saving: Saving, amount: Decimal) {
        saving.currentAmount = max(0, saving.currentAmount + amount)
        saving.updatedAt = .now
    }

    func softDelete(_ saving: Saving) {
        saving.isDeleted = true
        saving.updatedAt = .now
    }
}
