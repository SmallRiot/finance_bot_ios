//
//  Money.swift
//  MillionersBot
//
//  Форматирование и парсинг денежных сумм (Decimal + код валюты).
//

import Foundation

enum Money {

    /// "1 250 ₽" — число + символ валюты. Для RUB-стиля символ идёт после суммы.
    static func string(_ amount: Decimal, code: String, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = "\u{00A0}" // неразрывный пробел
        let number = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        let symbol = CurrencyCode(rawValue: code)?.symbol ?? code
        return "\(number)\u{00A0}\(symbol)"
    }

    /// Парсит пользовательский ввод ("1250,50" или "1250.50") в Decimal.
    static func parse(_ text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized)
    }
}
