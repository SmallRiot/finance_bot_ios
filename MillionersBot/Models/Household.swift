//
//  Household.swift
//  MillionersBot
//
//  Семья / домохозяйство — группа людей с общим бюджетом.
//  Назван `Household`, чтобы не конфликтовать со SwiftUI.Group.
//

import Foundation
import SwiftData

@Model
final class Household {
    @Attribute(.unique) var id: String
    var name: String
    var inviteCode: String
    var memberIDs: [String]
    var baseCurrencyCode: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        inviteCode: String,
        memberIDs: [String] = [],
        baseCurrencyCode: String = CurrencyCode.default.rawValue,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.memberIDs = memberIDs
        self.baseCurrencyCode = baseCurrencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
