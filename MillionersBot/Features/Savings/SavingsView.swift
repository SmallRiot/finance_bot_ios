//
//  SavingsView.swift
//  MillionersBot
//
//  Сбережения: карточки целей с прогрессом и пополнением.
//

import SwiftUI
import SwiftData

struct SavingsView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Saving> { !$0.isDeleted }, sort: \Saving.updatedAt, order: .reverse)
    private var allSavings: [Saving]
    @Environment(CurrencyService.self) private var currency
    @AppStorage("householdID") private var householdID: String = ""

    @State private var editorSaving: Saving?
    @State private var contributeSaving: Saving?
    @State private var detailSaving: Saving?
    @State private var isAddingNew = false

    private var savings: [Saving] {
        allSavings.filter { inScope($0.householdID, current: householdID) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if savings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Сбережения")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingNew = true
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(item: $detailSaving) { SavingDetailView(saving: $0) }
            .sheet(isPresented: $isAddingNew) { AddSavingView() }
            .sheet(item: $editorSaving) { AddSavingView(saving: $0) }
            .sheet(item: $contributeSaving) {
                ContributeView(saving: $0)
                    .presentationDetents([.medium])
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(savings) { saving in
                    SavingCard(
                        saving: saving,
                        onOpen: { detailSaving = saving },
                        onContribute: { contributeSaving = saving },
                        onEdit: { editorSaving = saving }
                    )
                }
            }
            .padding()
        }
        .refreshable { await currency.refresh() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Нет накоплений", systemImage: "banknote")
        } description: {
            Text("Создайте цель — например «Отпуск» или «Подушка безопасности».")
        } actions: {
            Button("Добавить цель") { isAddingNew = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct SavingCard: View {
    let saving: Saving
    let onOpen: () -> Void
    let onContribute: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let color = Color(hex: saving.colorHex)
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(saving.title)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Money.string(saving.currentAmount, code: saving.currencyCode))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        if let target = saving.targetAmount {
                            Text("из \(Money.string(target, code: saving.currencyCode))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if saving.targetAmount != nil {
                        ProgressView(value: saving.progress)
                            .tint(color)
                        HStack {
                            Text("\(Int((saving.progress * 100).rounded()))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Button(action: onContribute) {
                    Label("Пополнить", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(color)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: 44)
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    SavingsView()
        .environment(CurrencyService())
        .modelContainer(PersistenceController.preview)
}
