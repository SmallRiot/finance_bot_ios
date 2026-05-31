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
    @Environment(CurrencyService.self) private var currency
    @AppStorage("householdID") private var householdID: String = ""

    @State private var editorExpense: Expense?
    @State private var isAddingNew = false

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
                            ExpenseRow(expense: expense, category: categoriesByID[expense.categoryID ?? ""])
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

    /// Сумма за день по каждой валюте (конвертация — в M6).
    private func dayTotal(_ items: [Expense]) -> String {
        let byCurrency = Dictionary(grouping: items, by: \.currencyCode)
        return byCurrency
            .sorted { $0.key < $1.key }
            .map { code, group in
                Money.string(group.reduce(0) { $0 + $1.amount }, code: code)
            }
            .joined(separator: " · ")
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
                if let note = expense.note, !note.isEmpty {
                    Text(note)
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
        .modelContainer(PersistenceController.preview)
}
