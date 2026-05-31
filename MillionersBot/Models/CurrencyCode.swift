//
//  CurrencyCode.swift
//  MillionersBot
//
//  Поддерживаемые валюты. Храним в моделях как String (raw value),
//  чтобы данные легко зеркалились в Firestore.
//

import Foundation

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case rub = "RUB"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case kzt = "KZT"
    case gel = "GEL"
    case trh = "TRY"
    case amd = "AMD"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .rub: return "₽"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .kzt: return "₸"
        case .gel: return "₾"
        case .trh: return "₺"
        case .amd: return "֏"
        }
    }

    var displayName: String {
        switch self {
        case .rub: return "Рубль"
        case .usd: return "Доллар США"
        case .eur: return "Евро"
        case .gbp: return "Фунт стерлингов"
        case .kzt: return "Тенге"
        case .gel: return "Лари"
        case .trh: return "Турецкая лира"
        case .amd: return "Драм"
        }
    }

    static let `default`: CurrencyCode = .rub
}
