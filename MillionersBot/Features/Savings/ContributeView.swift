//
//  ContributeView.swift
//  MillionersBot
//
//  Пополнение накопления на сумму.
//

import SwiftUI
import SwiftData

struct ContributeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let saving: Saving

    @State private var amountText: String = ""
    @State private var isWithdrawal = false
    @FocusState private var focused: Bool

    private var parsedAmount: Decimal? {
        guard let value = Money.parse(amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $isWithdrawal) {
                        Text("Пополнить").tag(false)
                        Text("Снять").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .focused($focused)
                        Text(CurrencyCode(rawValue: saving.currencyCode)?.symbol ?? saving.currencyCode)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Сейчас накоплено: \(Money.string(saving.currentAmount, code: saving.currencyCode))")
                }
            }
            .navigationTitle(saving.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", action: apply).disabled(parsedAmount == nil)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func apply() {
        guard let amount = parsedAmount else { return }
        SavingRepository(context: context).addContribution(saving, amount: isWithdrawal ? -amount : amount)
        dismiss()
    }
}
