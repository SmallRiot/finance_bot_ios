//
//  UserProfile.swift
//  MillionersBot
//
//  Профиль пользователя. `id` совпадает с Firebase UID (на этапе синка).
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var displayName: String
    var avatarColorHex: String
    var householdID: String?
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        displayName: String,
        avatarColorHex: String = "#4F8EF7",
        householdID: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarColorHex = avatarColorHex
        self.householdID = householdID
        self.updatedAt = updatedAt
    }
}
