//
//  ExpensesView.swift
//  MillionersBot
//
//  Главный экран — лента трат, сгруппированная по дням, и быстрое добавление.
//

import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Expense> { !$0.isDeleted },
        sort: \Expense.date,
        order: .reverse
    )
    private var expenses: [Expense]

    @Query private var categories: [Category]
    @Query private var profiles: [UserProfile]
    @Environment(CurrencyService.self) private var currency
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var appState
    @AppStorage("householdID") private var householdID: String = ""
    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue

    @State private var editorExpense: Expense?
    @State private var isAddingNew = false

    /// Имя автора траты — показываем только в семье.
    private func authorLabel(_ expense: Expense) -> String? {
        guard !householdID.isEmpty, let authorID = expense.authorID else { return nil }
        if authorID == auth.uid { return "Вы" }
        if let profile = profiles.first(where: { $0.id == authorID }), !profile.displayName.isEmpty {
            return profile.displayName
        }
        return "Участник " + authorID.prefix(4)
    }

    private var scopedExpenses: [Expense] {
        expenses.filter { inScope($0.householdID, current: householdID) }
    }

    private var categoriesByID: [String: Category] {
        Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Траты, сгруппированные по началу дня, в порядке убывания даты.
    private var days: [(day: Date, items: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: scopedExpenses) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { (day: $0, items: grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if scopedExpenses.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Траты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingNew = true
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingNew) {
                AddExpenseView()
            }
            .sheet(item: $editorExpense) { expense in
                AddExpenseView(expense: expense)
            }
            .onChange(of: appState.pendingAddExpense, initial: true) { _, pending in
                if pending {
                    isAddingNew = true
                    appState.pendingAddExpense = false
                }
            }
            #if DEBUG
            .onAppear {
                if CommandLine.arguments.contains("-addSheet") { isAddingNew = true }
            }
            #endif
        }
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { section in
                Section {
                    ForEach(section.items) { expense in
                        Button {
                            editorExpense = expense
                        } label: {
                            ExpenseRow(
                                expense: expense,
                                category: categoriesByID[expense.categoryID ?? ""],
                                author: authorLabel(expense)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        delete(offsets, in: section.items)
                    }
                } header: {
                    dayHeader(day: section.day, items: section.items)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await currency.refresh() }
    }

    private func dayHeader(day: Date, items: [Expense]) -> some View {
        HStack {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            Spacer()
            Text(dayTotal(items))
                .monospacedDigit()
        }
        .textCase(nil)
        .font(.subheadline)
    }

    /// Сумма траты, приведённая к базовой валюте (если курс есть).
    private func inBase(_ expense: Expense) -> Decimal {
        currency.convert(expense.amount, from: expense.currencyCode, to: baseCurrency) ?? expense.amount
    }

    /// Итог за день — одной суммой в базовой валюте.
    private func dayTotal(_ items: [Expense]) -> String {
        let sum = items.reduce(Decimal(0)) { $0 + inBase($1) }
        return Money.string(sum, code: baseCurrency)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Пока нет трат", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Нажмите «плюс», чтобы добавить первую трату.")
        } actions: {
            Button("Добавить трату") { isAddingNew = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func delete(_ offsets: IndexSet, in items: [Expense]) {
        let repo = ExpenseRepository(context: context)
        for index in offsets {
            repo.softDelete(items[index])
        }
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let category: Category?
    var author: String?

    private var subtitle: String? {
        let note = (expense.note?.isEmpty == false) ? expense.note : nil
        switch (note, author) {
        case let (note?, author?): return "\(note) · \(author)"
        case let (note?, nil): return note
        case let (nil, author?): return author
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            let color = Color(hex: category?.colorHex ?? "#8E8E93")
            Image(systemName: category?.iconSystemName ?? "tag")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? "Без категории")
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(Money.string(expense.amount, code: expense.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ExpensesView()
        .environment(CurrencyService())
        .environment(AuthService())
        .environment(AppState())
        .modelContainer(PersistenceController.preview)
}
