//
//  SavingDetailView.swift
//  MillionersBot
//
//  Детали накопления: график роста баланса во времени и история операций
//  (пополнения/снятия) с комментарием, автором и мягким удалением.
//

import SwiftUI
import SwiftData
import Charts

struct SavingDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthService.self) private var auth
    @AppStorage("householdID") private var householdID: String = ""

    let saving: Saving

    @Query private var allTransactions: [SavingTransaction]
    @Query private var profiles: [UserProfile]

    @State private var contributeWithdrawal: Bool?

    init(saving: Saving) {
        self.saving = saving
        let savingID = saving.id
        _allTransactions = Query(
            filter: #Predicate<SavingTransaction> { $0.savingID == savingID && !$0.isDeleted },
            sort: \SavingTransaction.date,
            order: .reverse
        )
    }

    /// Операции этого накопления в текущей области (семья/локально), новее — выше.
    private var transactions: [SavingTransaction] {
        allTransactions.filter { inScope($0.householdID, current: householdID) }
    }

    /// Точки графика: бегущая сумма по возрастанию даты.
    private var chartPoints: [(date: Date, balance: Decimal)] {
        var running: Decimal = 0
        return transactions.reversed().map { tx in
            running += tx.amount
            return (date: tx.date, balance: running)
        }
    }

    var body: some View {
        List {
            headerSection
            if !chartPoints.isEmpty {
                chartSection
            }
            actionsSection
            historySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(saving.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: contributeItem) { item in
            ContributeView(saving: saving, startAsWithdrawal: item.isWithdrawal)
                .presentationDetents([.medium])
        }
        .onAppear {
            SavingRepository(context: context)
                .ensureOpeningBalance(saving, transactions: transactions)
        }
    }

    // MARK: - Секции

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Money.string(saving.currentAmount, code: saving.currencyCode))
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                    if let target = saving.targetAmount {
                        Text("из \(Money.string(target, code: saving.currencyCode))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if saving.targetAmount != nil {
                    ProgressView(value: saving.progress)
                        .tint(Color(hex: saving.colorHex))
                    Text("\(Int((saving.progress * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var chartSection: some View {
        Section("Динамика баланса") {
            let color = Color(hex: saving.colorHex)
            Chart {
                ForEach(chartPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Баланс", (point.balance as NSDecimalNumber).doubleValue)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)

                    AreaMark(
                        x: .value("Дата", point.date),
                        y: .value("Баланс", (point.balance as NSDecimalNumber).doubleValue)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color.opacity(0.15))
                }
                if let target = saving.targetAmount {
                    RuleMark(y: .value("Цель", (target as NSDecimalNumber).doubleValue))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Цель")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 180)
            .padding(.vertical, 4)
        }
    }

    private var actionsSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    contributeWithdrawal = false
                } label: {
                    Label("Пополнить", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: saving.colorHex))

                Button {
                    contributeWithdrawal = true
                } label: {
                    Label("Снять", systemImage: "minus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var historySection: some View {
        Section("История") {
            if transactions.isEmpty {
                Text("Пока нет операций.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(transactions) { tx in
                    TransactionRow(
                        transaction: tx,
                        currencyCode: saving.currencyCode,
                        author: authorLabel(tx)
                    )
                }
                .onDelete(perform: delete)
            }
        }
    }

    // MARK: - Действия

    private func delete(_ offsets: IndexSet) {
        let repo = SavingRepository(context: context)
        for index in offsets {
            repo.softDeleteTransaction(transactions[index], from: saving)
        }
    }

    /// Имя автора операции — показываем только в семье.
    private func authorLabel(_ tx: SavingTransaction) -> String? {
        guard !householdID.isEmpty, let authorID = tx.authorID else { return nil }
        if authorID == auth.uid { return "Вы" }
        if let profile = profiles.first(where: { $0.id == authorID }), !profile.displayName.isEmpty {
            return profile.displayName
        }
        return "Участник " + authorID.prefix(4)
    }

    /// Обёртка для `.sheet(item:)` — какой режим ContributeView открыть.
    private var contributeItem: Binding<ContributeMode?> {
        Binding(
            get: { contributeWithdrawal.map { ContributeMode(isWithdrawal: $0) } },
            set: { contributeWithdrawal = $0?.isWithdrawal }
        )
    }

    private struct ContributeMode: Identifiable {
        let isWithdrawal: Bool
        var id: Bool { isWithdrawal }
    }
}

private struct TransactionRow: View {
    let transaction: SavingTransaction
    let currencyCode: String
    var author: String?

    private var isPositive: Bool { transaction.amount >= 0 }

    private var subtitle: String? {
        let note = (transaction.note?.isEmpty == false) ? transaction.note : nil
        switch (note, author) {
        case let (note?, author?): return "\(note) · \(author)"
        case let (note?, nil): return note
        case let (nil, author?): return author
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPositive ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(isPositive ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.date.formatted(.dateTime.day().month(.wide).year()))
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text((isPositive ? "+" : "−") + Money.string(abs(transaction.amount), code: currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isPositive ? Color.green : Color.red)
        }
        .padding(.vertical, 2)
    }
}
