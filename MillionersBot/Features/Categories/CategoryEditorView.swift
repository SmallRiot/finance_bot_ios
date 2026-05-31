//
//  CategoryEditorView.swift
//  MillionersBot
//
//  Создание / редактирование категории: имя, иконка, цвет.
//

import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var category: Category?

    @AppStorage("householdID") private var householdID: String = ""
    @State private var name: String = ""
    @State private var icon: String = "tag"
    @State private var colorHex: String = Self.palette.first ?? "#8E8E93"

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: colorHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        TextField("Название", text: $name)
                            .font(.title3)
                    }
                }

                Section("Иконка") {
                    iconGrid
                }

                Section("Цвет") {
                    colorRow
                }
            }
            .navigationTitle(category == nil ? "Новая категория" : "Категория")
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

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(Self.icons, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(icon == symbol ? Color.white : .primary)
                    .background(icon == symbol ? Color(hex: colorHex) : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { icon = symbol }
            }
        }
        .padding(.vertical, 4)
    }

    private var colorRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(Self.palette, id: \.self) { hex in
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

    private func configure() {
        guard let category else { return }
        name = category.name
        icon = category.iconSystemName
        colorHex = category.colorHex
    }

    private func save() {
        let repo = CategoryRepository(context: context)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            repo.update(category, name: trimmed, icon: icon, colorHex: colorHex)
        } else {
            repo.add(name: trimmed, icon: icon, colorHex: colorHex,
                     householdID: householdID.isEmpty ? nil : householdID)
        }
        dismiss()
    }

    static let icons = [
        "cart.fill", "fork.knife", "car.fill", "house.fill", "gamecontroller.fill",
        "cross.case.fill", "tshirt.fill", "wifi", "gift.fill", "airplane",
        "fuelpump.fill", "pawprint.fill", "book.fill", "graduationcap.fill", "pills.fill",
        "bag.fill", "creditcard.fill", "cup.and.saucer.fill", "bus.fill", "tram.fill",
        "dumbbell.fill", "scissors", "wrench.and.screwdriver.fill", "ellipsis.circle.fill",
    ]

    static let palette = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#5AC8FA",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93",
    ]
}

#Preview {
    CategoryEditorView()
        .modelContainer(PersistenceController.preview)
}
