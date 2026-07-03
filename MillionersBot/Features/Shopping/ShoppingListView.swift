//
//  ShoppingListView.swift
//  MillionersBot
//
//  Совместный список покупок. Открыл в магазине — отметил купленное.
//  Быстрое добавление сверху, купленное уезжает вниз зачёркнутым.
//

import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth

    @Query(
        filter: #Predicate<ShoppingItem> { !$0.isDeleted },
        sort: \ShoppingItem.sortOrder
    )
    private var allItems: [ShoppingItem]

    @AppStorage("householdID") private var householdID: String = ""

    @State private var newTitle: String = ""
    @FocusState private var addFocused: Bool

    private var scoped: [ShoppingItem] {
        allItems.filter { inScope($0.householdID, current: householdID) }
    }
    private var toBuy: [ShoppingItem] { scoped.filter { !$0.isPurchased } }
    private var purchased: [ShoppingItem] { scoped.filter { $0.isPurchased } }

    private var repo: ShoppingItemRepository { ShoppingItemRepository(context: context) }
    private var scopedHousehold: String? { householdID.isEmpty ? nil : householdID }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                        TextField("Добавить покупку", text: $newTitle)
                            .focused($addFocused)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Добавить", action: addItem)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                if !toBuy.isEmpty {
                    Section {
                        ForEach(toBuy) { row($0) }
                            .onDelete { delete(toBuy, at: $0) }
                    }
                }

                if !purchased.isEmpty {
                    Section {
                        ForEach(purchased) { row($0) }
                            .onDelete { delete(purchased, at: $0) }
                    } header: {
                        HStack {
                            Text("Куплено")
                            Spacer()
                            Button("Убрать", action: clearPurchased)
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("Покупки")
            .overlay {
                if scoped.isEmpty { emptyState }
            }
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            repo.togglePurchased(item)
            try? context.save()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPurchased ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.isPurchased)
                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Список пуст", systemImage: "cart")
        } description: {
            Text("Добавьте, что нужно купить — список виден всей семье.")
        }
    }

    private func addItem() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        repo.add(title: trimmed, authorID: auth.uid, householdID: scopedHousehold)
        try? context.save()
        newTitle = ""
        addFocused = true // держим фокус — можно быстро добавлять дальше
    }

    private func delete(_ items: [ShoppingItem], at offsets: IndexSet) {
        for index in offsets { repo.softDelete(items[index]) }
        try? context.save()
    }

    private func clearPurchased() {
        repo.clearPurchased(in: scopedHousehold)
        try? context.save()
    }
}

#Preview {
    ShoppingListView()
        .environment(AuthService())
        .modelContainer(PersistenceController.preview)
}
