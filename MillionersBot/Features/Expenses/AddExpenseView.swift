//
//  AddExpenseView.swift
//  MillionersBot
//
//  Быстрое добавление / редактирование траты.
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    /// Если передана — режим редактирования.
    var expense: Expense?

    @Query(
        filter: #Predicate<Category> { !$0.isArchived },
        sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)]
    )
    private var categories: [Category]

    @Query private var profiles: [UserProfile]

    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue
    @AppStorage("householdID") private var householdID: String = ""

    @State private var amountText: String = ""
    @State private var selectedCategoryID: String?
    @State private var currencyCode: String = CurrencyCode.default.rawValue
    @State private var note: String = ""
    @State private var date: Date = .now
    @FocusState private var amountFocused: Bool

    private var scopedCategories: [Category] {
        categories.filter { inScope($0.householdID, current: householdID) }
    }

    private var parsedAmount: Decimal? {
        guard let value = Money.parse(amountText), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool { parsedAmount != nil }

    private func authorName(for expense: Expense) -> String? {
        guard let authorID = expense.authorID else { return nil }
        if authorID == auth.uid { return "Вы" }
        if let profile = profiles.first(where: { $0.id == authorID }) { return profile.displayName }
        return "Участник " + authorID.prefix(4)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .focused($amountFocused)
                        Menu {
                            Picker("Валюта", selection: $currencyCode) {
                                ForEach(CurrencyCode.allCases) { code in
                                    Text("\(code.symbol)  \(code.rawValue)").tag(code.rawValue)
                                }
                            }
                        } label: {
                            Text(CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode)
                                .font(.title.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                        }
                    }
                }

                Section("Категория") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 78), spacing: 10)],
                        spacing: 14
                    ) {
                        ForEach(scopedCategories) { category in
                            CategoryGridCell(
                                category: category,
                                isSelected: selectedCategoryID == category.id
                            ) {
                                selectedCategoryID = category.id
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    TextField("Заметка (необязательно)", text: $note, axis: .vertical)
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                if let expense, let authorName = authorName(for: expense) {
                    Section {
                        LabeledContent("Добавил", value: authorName)
                    }
                }
            }
            .navigationTitle(expense == nil ? "Новая трата" : "Редактировать")
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
        if let expense {
            amountText = "\(expense.amount)"
            selectedCategoryID = expense.categoryID
            currencyCode = expense.currencyCode
            note = expense.note ?? ""
            date = expense.date
        } else {
            currencyCode = baseCurrency
            selectedCategoryID = selectedCategoryID ?? scopedCategories.first?.id
            amountFocused = true
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let repo = ExpenseRepository(context: context)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let expense {
            repo.update(
                expense,
                amount: amount,
                currencyCode: currencyCode,
                categoryID: selectedCategoryID,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                date: date
            )
        } else {
            repo.add(
                amount: amount,
                currencyCode: currencyCode,
                categoryID: selectedCategoryID,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                date: date,
                authorID: auth.uid,
                householdID: householdID.isEmpty ? nil : householdID
            )
        }
        dismiss()
    }
}

private struct CategoryGridCell: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let color = Color(hex: category.colorHex)
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.iconSystemName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : color)
                    .frame(width: 54, height: 54)
                    .background(
                        isSelected ? color : color.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                Text(category.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? color : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 26, alignment: .top)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddExpenseView()
        .environment(AuthService())
        .modelContainer(PersistenceController.preview)
}
