//
//  Category.swift
//  MillionersBot
//
//  Категория трат. Управляется пользователем, шарится внутри домохозяйства.
//

import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: String
    var name: String
    var iconSystemName: String
    var colorHex: String
    var householdID: String?
    var isArchived: Bool
    var sortOrder: Int
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        iconSystemName: String = "tag",
        colorHex: String = "#8E8E93",
        householdID: String? = nil,
        isArchived: Bool = false,
        sortOrder: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.colorHex = colorHex
        self.householdID = householdID
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
    }
}
