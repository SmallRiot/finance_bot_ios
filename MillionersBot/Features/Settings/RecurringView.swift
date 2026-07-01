//
//  RecurringView.swift
//  MillionersBot
//
//  Управление регулярными (ежемесячными) правилами: список активных
//  и остановка (мягкое удаление, которое перестаёт постить и синкается).
//

import SwiftUI
import SwiftData

struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("householdID") private var householdID: String = ""

    @Query(
        filter: #Predicate<RecurringExpense> { $0.isActive && !$0.isDeleted },
        sort: [SortDescriptor(\RecurringExpense.updatedAt, order: .reverse)]
    )
    private var rules: [RecurringExpense]

    @Query private var categories: [Category]

    private var scopedRules: [RecurringExpense] {
        rules.filter { inScope($0.householdID, current: householdID) }
    }

    private func category(_ id: String?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    var body: some View {
        List {
            if scopedRules.isEmpty {
                ContentUnavailableView(
                    "Нет регулярных платежей",
                    systemImage: "arrow.clockwise",
                    description: Text("Включите «Повторять каждый месяц» при добавлении траты.")
                )
            } else {
                ForEach(scopedRules) { rule in
                    RecurringRow(rule: rule, category: category(rule.categoryID))
                }
                .onDelete(perform: stop)
            }
        }
        .navigationTitle("Регулярные платежи")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stop(_ offsets: IndexSet) {
        for index in offsets {
            let rule = scopedRules[index]
            rule.isActive = false
            rule.isDeleted = true
            rule.updatedAt = .now
        }
        try? context.save()
    }
}

private struct RecurringRow: View {
    let rule: RecurringExpense
    let category: Category?

    private var day: Int {
        Calendar.current.component(.day, from: rule.anchorDate)
    }

    private var title: String {
        if let category { return category.name }
        let note = rule.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return note.isEmpty ? "Без категории" : note
    }

    var body: some View {
        HStack(spacing: 12) {
            let color = category.map { Color(hex: $0.colorHex) } ?? .secondary
            Image(systemName: category?.iconSystemName ?? "arrow.clockwise")
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text("каждое \(day) число")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.string(rule.amount, code: rule.currencyCode))
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RecurringView()
            .modelContainer(PersistenceController.preview)
    }
}
