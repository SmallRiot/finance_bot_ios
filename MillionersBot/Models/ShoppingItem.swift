//
//  ShoppingItem.swift
//  MillionersBot
//
//  Позиция совместного списка покупок. Кто-то в магазине — открыл, отметил
//  купленное (`isPurchased`). `isDeleted` — soft delete для синка семьи.
//

import Foundation
import SwiftData

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: String
    var title: String
    var note: String?           // необязательно: «2 л», «зелёный» и т.п.
    var isPurchased: Bool       // отмечено купленным
    var authorID: String?
    var householdID: String?
    var sortOrder: Int          // порядок в списке (новые сверху)
    var isDeleted: Bool
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        note: String? = nil,
        isPurchased: Bool = false,
        authorID: String? = nil,
        householdID: String? = nil,
        sortOrder: Int = 0,
        isDeleted: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isPurchased = isPurchased
        self.authorID = authorID
        self.householdID = householdID
        self.sortOrder = sortOrder
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}
