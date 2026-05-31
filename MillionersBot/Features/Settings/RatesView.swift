//
//  RatesView.swift
//  MillionersBot
//
//  Курсы валют + живой конвертер: вводишь сумму в выбранной валюте и сразу
//  видишь её во всех остальных. База ("ratesBaseCurrency") — отдельная
//  настройка, не связана с основной валютой аккаунта ("baseCurrency").
//

import SwiftUI

struct RatesView: View {
    @Environment(CurrencyService.self) private var currency
    @AppStorage("ratesBaseCurrency") private var ratesBase: String = CurrencyCode.default.rawValue

    @State private var amountText: String = "1000"
    @FocusState private var amountFocused: Bool

    private var amount: Decimal { Money.parse(amountText) ?? 0 }

    private var others: [CurrencyCode] {
        CurrencyCode.allCases.filter { $0.rawValue != ratesBase }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    TextField("Сумма", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .focused($amountFocused)
                    Menu {
                        Picker("Валюта", selection: $ratesBase) {
                            ForEach(CurrencyCode.allCases) { code in
                                Text("\(code.symbol)  \(code.rawValue)").tag(code.rawValue)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(CurrencyCode(rawValue: ratesBase)?.symbol ?? ratesBase)
                                .font(.title.weight(.bold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.tint)
                    }
                }
            } footer: {
                if let updatedAt = currency.updatedAt {
                    Text("Курс обновлён \(updatedAt.formatted(.relative(presentation: .named))). Потяните вниз для обновления.")
                } else {
                    Text("Курсы ещё не загружены. Потяните вниз для обновления.")
                }
            }

            Section("В других валютах") {
                if currency.rates.isEmpty {
                    ContentUnavailableView("Нет данных о курсах", systemImage: "wifi.slash")
                } else {
                    ForEach(others) { code in
                        HStack(spacing: 12) {
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
                            Text(convertedString(to: code))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Конвертер валют")
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { amountFocused = false }
            }
        }
        .task { await currency.refreshIfNeeded() }
    }

    private func convertedString(to code: CurrencyCode) -> String {
        guard let value = currency.convert(amount, from: ratesBase, to: code.rawValue) else { return "—" }
        return Money.string(value, code: code.rawValue)
    }
}

#Preview {
    NavigationStack {
        RatesView()
    }
    .environment(CurrencyService())
}
