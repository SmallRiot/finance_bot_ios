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
    @AppStorage("householdID") private var householdID: String = ""

    @State private var editorCategory: Category?
    @State private var isAddingNew = false

    private var scopedCategories: [Category] {
        categories.filter { inScope($0.householdID, current: householdID) }
    }

    var body: some View {
        List {
            ForEach(scopedCategories) { category in
                Button {
                    editorCategory = category
                } label: {
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
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: archive)
        }
        .navigationTitle("Категории")
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
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(PersistenceController.preview)
}
