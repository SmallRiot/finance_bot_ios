//
//  CategoriesView.swift
//  MillionersBot
//
//  Управление категориями трат.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Category> { !$0.isArchived },
        sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)]
    )
    private var categories: [Category]

    @Query(filter: #Predicate<Expense> { !$0.isDeleted })
    private var allExpenses: [Expense]

    @Environment(CurrencyService.self) private var currency
    @AppStorage("householdID") private var householdID: String = ""
    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue

    @State private var editorCategory: Category?
    @State private var isAddingNew = false

    private var scopedCategories: [Category] {
        categories.filter { inScope($0.householdID, current: householdID) }
    }

    /// Границы текущего месяца.
    private var monthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: .now)
            ?? DateInterval(start: .now, duration: 0)
    }

    /// Сумма траты в базовой валюте — тот же приём, что в StatsView.
    private func inBase(_ expense: Expense) -> Decimal {
        currency.convert(expense.amount, from: expense.currencyCode, to: baseCurrency) ?? expense.amount
    }

    /// Потрачено по категории за текущий месяц (в базовой валюте, scope семьи).
    private func spentThisMonth(_ category: Category) -> Decimal {
        let interval = monthInterval
        return allExpenses
            .filter {
                $0.categoryID == category.id
                    && inScope($0.householdID, current: householdID)
                    && $0.date >= interval.start && $0.date < interval.end
            }
            .reduce(Decimal(0)) { $0 + inBase($1) }
    }

    var body: some View {
        List {
            ForEach(scopedCategories) { category in
                Button {
                    editorCategory = category
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            let color = Color(hex: category.colorHex)
                            Image(systemName: category.iconSystemName)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(category.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        if let limit = category.monthlyLimit, limit > 0 {
                            limitBar(spent: spentThisMonth(category), limit: limit)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: archive)
            .onMove(perform: move)
        }
        .navigationTitle("Категории")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingNew = true
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingNew) {
            CategoryEditorView()
        }
        .sheet(item: $editorCategory) { category in
            CategoryEditorView(category: category)
        }
    }

    private func archive(_ offsets: IndexSet) {
        let repo = CategoryRepository(context: context)
        for index in offsets {
            repo.archive(scopedCategories[index])
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = scopedCategories
        ordered.move(fromOffsets: source, toOffset: destination)
        CategoryRepository(context: context).reorder(ordered)
    }

    /// Компактный прогресс «потрачено / лимит» за текущий месяц.
    @ViewBuilder
    private func limitBar(spent: Decimal, limit: Decimal) -> some View {
        let ratio = (spent as NSDecimalNumber).doubleValue / (limit as NSDecimalNumber).doubleValue
        let color: Color = ratio > 1 ? .red : (ratio >= 0.8 ? .orange : .green)
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(max(ratio, 0), 1))
                }
            }
            .frame(height: 6)
            HStack {
                Text(Money.string(spent, code: baseCurrency))
                    .foregroundStyle(color)
                Spacer()
                Text(Money.string(limit, code: baseCurrency))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .monospacedDigit()
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .environment(CurrencyService())
    .modelContainer(PersistenceController.preview)
}
