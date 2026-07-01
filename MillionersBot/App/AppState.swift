//
//  AppState.swift
//  MillionersBot
//
//  Глобальное состояние сессии: текущий пользователь, домохозяйство, статус синка.
//  Пробрасывается во вьюхи через .environment(...).
//

import Foundation
import Observation

@Observable
final class AppState {
    var currentUserID: String?
    var currentHouseholdID: String?
    var syncStatus: SyncStatus = .idle

    /// Запрос на открытие формы добавления траты (например, из виджета).
    var pendingAddExpense: Bool = false

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case offline
        case error(String)
    }

    var isSignedIn: Bool { currentUserID != nil }
    var hasHousehold: Bool { currentHouseholdID != nil }
}
