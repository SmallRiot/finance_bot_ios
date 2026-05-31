//
//  HouseholdScope.swift
//  MillionersBot
//
//  Область видимости данных: в семье показываем записи этой семьи,
//  вне семьи — локальные (householdID == nil).
//

import Foundation

/// Принадлежит ли запись текущей области (семье или «локально»).
func inScope(_ entityHouseholdID: String?, current householdID: String) -> Bool {
    householdID.isEmpty ? entityHouseholdID == nil : entityHouseholdID == householdID
}
