//
//  AddSavingView.swift
//  MillionersBot
//
//  Создание / редактирование накопления (цели).
//

import SwiftUI
import SwiftData

struct AddSavingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var saving: Saving?

    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue
    @AppStorage("householdID") private var householdID: String = ""

    @State private var title: String = ""
    @State private var hasTarget: Bool = true
    @State private var targetText: String = ""
    @State private var currencyCode: String = CurrencyCode.default.rawValue
    @State private var colorHex: String = CategoryEditorView.palette.first ?? "#34C759"

    private var parsedTarget: Decimal? {
        guard hasTarget else { return nil }
        guard let value = Money.parse(targetText), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (!hasTarget || parsedTarget != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название цели", text: $title)
                }

                Section("Цель") {
                    Toggle("Задать целевую сумму", isOn: $hasTarget.animation())
                    if hasTarget {
                        HStack {
                            TextField("Сумма", text: $targetText)
                                .keyboardType(.decimalPad)
                            Picker("", selection: $currencyCode) {
                                ForEach(CurrencyCode.allCases) { Text($0.symbol).tag($0.rawValue) }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section("Цвет") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(CategoryEditorView.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(saving == nil ? "Новая цель" : "Цель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save).disabled(!isValid)
                }
            }
            .onAppear(perform: configure)
        }
    }

    private func configure() {
        if let saving {
            title = saving.title
            currencyCode = saving.currencyCode
            colorHex = saving.colorHex
            if let target = saving.targetAmount {
                hasTarget = true
                targetText = "\(target)"
            } else {
                hasTarget = false
            }
        } else {
            currencyCode = baseCurrency
        }
    }

    private func save() {
        let repo = SavingRepository(context: context)
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let saving {
            repo.update(saving, title: trimmed, targetAmount: parsedTarget, currencyCode: currencyCode, colorHex: colorHex)
        } else {
            repo.add(title: trimmed, targetAmount: parsedTarget, currencyCode: currencyCode, colorHex: colorHex,
                     householdID: householdID.isEmpty ? nil : householdID)
        }
        dismiss()
    }
}

#Preview {
    AddSavingView()
        .modelContainer(PersistenceController.preview)
}
