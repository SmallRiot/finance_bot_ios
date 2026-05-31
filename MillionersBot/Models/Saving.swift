//
//  Saving.swift
//  MillionersBot
//
//  Накопление / финансовая цель.
//

import Foundation
import SwiftData

@Model
final class Saving {
    @Attribute(.unique) var id: String
    var title: String
    var targetAmount: Decimal?
    var currentAmount: Decimal
    var currencyCode: String
    var colorHex: String
    var householdID: String?
    var isDeleted: Bool
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        targetAmount: Decimal? = nil,
        currentAmount: Decimal = 0,
        currencyCode: String = CurrencyCode.default.rawValue,
        colorHex: String = "#34C759",
        householdID: String? = nil,
        isDeleted: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.currencyCode = currencyCode
        self.colorHex = colorHex
        self.householdID = householdID
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }

    /// Прогресс к цели в диапазоне 0...1. Если цель не задана — 0.
    var progress: Double {
        guard let target = targetAmount, target > 0 else { return 0 }
        let ratio = (currentAmount as NSDecimalNumber).doubleValue
            / (target as NSDecimalNumber).doubleValue
        return min(max(ratio, 0), 1)
    }
}
