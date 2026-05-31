//
//  CurrencyService.swift
//  MillionersBot
//
//  Курсы валют и конвертация. Источник — бесплатный open.er-api.com (без ключа),
//  курсы заданы относительно USD. Кэш в UserDefaults, обновление раз в ~12 часов.
//  Конвертация — только для отображения (исходная сумма/валюта не меняются).
//

import Foundation
import Observation

@MainActor
@Observable
final class CurrencyService {
    private(set) var rates: [String: Double] = [:]   // сколько единиц валюты за 1 USD
    private(set) var updatedAt: Date?
    private(set) var isLoading = false

    private let cacheKey = "currencyRatesCacheV1"
    private let endpoint = "https://open.er-api.com/v6/latest/USD"
    private let refreshInterval: TimeInterval = 12 * 3600

    init() {
        loadCache()
    }

    func refreshIfNeeded() async {
        if let updatedAt, !rates.isEmpty, Date().timeIntervalSince(updatedAt) < refreshInterval {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard let url = URL(string: endpoint) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ERAPIResponse.self, from: data)
            guard decoded.result == "success", !decoded.rates.isEmpty else { return }
            rates = decoded.rates
            updatedAt = Date()
            saveCache()
        } catch {
            // Оставляем прошлый кэш — оффлайн не должен ломать экран.
        }
    }

    /// Конвертирует сумму между валютами. nil — если курса нет (например, оффлайн на первом запуске).
    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        if from == to { return amount }
        guard let fromRate = rates[from], let toRate = rates[to], fromRate > 0 else { return nil }
        let value = (amount as NSDecimalNumber).doubleValue
        let result = value / fromRate * toRate
        return Decimal(result)
    }

    // MARK: - Кэш

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(RatesCache.self, from: data) else { return }
        rates = cache.rates
        updatedAt = cache.updatedAt
    }

    private func saveCache() {
        guard let updatedAt else { return }
        let cache = RatesCache(rates: rates, updatedAt: updatedAt)
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

private struct ERAPIResponse: Decodable {
    let result: String
    let rates: [String: Double]
}

private struct RatesCache: Codable {
    let rates: [String: Double]
    let updatedAt: Date
}
