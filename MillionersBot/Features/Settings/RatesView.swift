//
//  RatesView.swift
//  MillionersBot
//
//  Курсы валют с выбором базовой валюты. База для просмотра курсов —
//  отдельная настройка ("ratesBaseCurrency"), не связана с основной
//  валютой аккаунта ("baseCurrency").
//

import SwiftUI

struct RatesView: View {
    @Environment(CurrencyService.self) private var currency
    @AppStorage("ratesBaseCurrency") private var ratesBase: String = CurrencyCode.default.rawValue

    private var baseSymbol: String {
        CurrencyCode(rawValue: ratesBase)?.symbol ?? ratesBase
    }

    private var others: [CurrencyCode] {
        CurrencyCode.allCases.filter { $0.rawValue != ratesBase }
    }

    var body: some View {
        List {
            Section {
                Picker("Относительно валюты", selection: $ratesBase) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text("\(code.displayName) (\(code.symbol))").tag(code.rawValue)
                    }
                }
            } footer: {
                if let updatedAt = currency.updatedAt {
                    Text("Обновлено \(updatedAt.formatted(.relative(presentation: .named))). Потяните вниз, чтобы обновить.")
                } else {
                    Text("Курсы ещё не загружены. Потяните вниз, чтобы обновить.")
                }
            }

            Section("За 1 \(baseSymbol)") {
                if currency.rates.isEmpty {
                    ContentUnavailableView("Нет данных о курсах", systemImage: "wifi.slash")
                } else {
                    ForEach(others) { code in
                        HStack {
                            Text(code.symbol)
                                .font(.headline)
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(code.rawValue)
                                Text(code.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(rateString(for: code))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Курсы валют")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await currency.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if currency.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await currency.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await currency.refreshIfNeeded() }
    }

    /// Сколько единиц `code` стоит 1 единица базовой валюты.
    private func rateString(for code: CurrencyCode) -> String {
        guard let value = currency.convert(1, from: ratesBase, to: code.rawValue) else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let double = (value as NSDecimalNumber).doubleValue
        formatter.maximumFractionDigits = double >= 100 ? 1 : (double >= 1 ? 2 : 4)
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        return "\(number) \(code.symbol)"
    }
}

#Preview {
    NavigationStack {
        RatesView()
    }
    .environment(CurrencyService())
}
