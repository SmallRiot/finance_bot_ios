//
//  StatsView.swift
//  MillionersBot
//
//  Статистика: переключатель периода, пончик по категориям, столбики по времени.
//  Суммы конвертируются в базовую валюту через CurrencyService (M6).
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue

    @Query(filter: #Predicate<Expense> { !$0.isDeleted }, sort: \Expense.date)
    private var allExpenses: [Expense]

    @Query private var categories: [Category]
    @Query private var profiles: [UserProfile]
    @Environment(CurrencyService.self) private var currency
    @Environment(AuthService.self) private var auth

    @State private var period: StatsPeriod = .month
    @State private var periodOffset: Int = 0
    @State private var selectedAngle: Double?

    private let calendar = Calendar.current

    private var interval: DateInterval {
        period.interval(now: .now, calendar: calendar, offset: periodOffset)
    }

    /// Категория, на сектор которой нажали (по выбранному углу пончика).
    private var selectedSlice: CategorySlice? {
        guard let selectedAngle else { return nil }
        var cumulative = 0.0
        for slice in slices {
            let value = (slice.amount as NSDecimalNumber).doubleValue
            if selectedAngle >= cumulative && selectedAngle < cumulative + value { return slice }
            cumulative += value
        }
        return nil
    }

    /// Сумма траты, приведённая к базовой валюте (если курс есть).
    private func inBase(_ expense: Expense) -> Decimal {
        currency.convert(expense.amount, from: expense.currencyCode, to: baseCurrency) ?? expense.amount
    }

    /// Серединный угол сектора категории — чтобы выделять его при тапе по списку.
    private func midAngle(for slice: CategorySlice) -> Double {
        var cumulative = 0.0
        for s in slices {
            let value = (s.amount as NSDecimalNumber).doubleValue
            if s.id == slice.id { return cumulative + value / 2 }
            cumulative += value
        }
        return 0
    }

    private var categoriesByID: [String: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    @AppStorage("householdID") private var householdID: String = ""

    private var expensesInPeriod: [Expense] {
        allExpenses.filter {
            inScope($0.householdID, current: householdID)
                && $0.date >= interval.start && $0.date < interval.end
        }
    }

    private var total: Decimal {
        expensesInPeriod.reduce(0) { $0 + inBase($1) }
    }

    private var slices: [CategorySlice] {
        let grouped = Dictionary(grouping: expensesInPeriod, by: { $0.categoryID ?? "—" })
        let sum = total
        return grouped.map { key, items in
            let category = categoriesByID[key]
            let amount = items.reduce(Decimal(0)) { $0 + inBase($1) }
            return CategorySlice(
                id: key,
                name: category?.name ?? "Без категории",
                color: Color(hex: category?.colorHex ?? "#8E8E93"),
                amount: amount,
                fraction: sum > 0 ? (amount as NSDecimalNumber).doubleValue / (sum as NSDecimalNumber).doubleValue : 0
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var trend: [TrendBucket] {
        var sums: [Date: Decimal] = [:]
        for expense in expensesInPeriod {
            let key = period.bucketStart(for: expense.date, calendar: calendar)
            sums[key, default: 0] += inBase(expense)
        }
        return period.bucketStarts(in: interval, calendar: calendar).map { start in
            TrendBucket(date: start, label: period.label(for: start), amount: sums[start] ?? 0)
        }
    }

    /// Топ трат выбранной категории за период (по убыванию суммы в базовой валюте).
    private func topExpenses(for categoryID: String) -> [Expense] {
        expensesInPeriod
            .filter { ($0.categoryID ?? "—") == categoryID }
            .sorted { inBase($0) > inBase($1) }
    }

    private func authorName(_ expense: Expense) -> String? {
        guard let authorID = expense.authorID, !householdID.isEmpty else { return nil }
        if authorID == auth.uid { return "Вы" }
        if let profile = profiles.first(where: { $0.id == authorID }), !profile.displayName.isEmpty {
            return profile.displayName
        }
        return "Участник " + authorID.prefix(4)
    }

    var body: some View {
        NavigationStack {
            Group {
                if expensesInPeriod.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Статистика")
            .safeAreaInset(edge: .top) {
                VStack(spacing: 10) {
                    Picker("Период", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    periodNav
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .onChange(of: period) {
                periodOffset = 0
                selectedAngle = nil
            }
        }
    }

    private var periodNav: some View {
        HStack {
            Button {
                periodOffset -= 1
                selectedAngle = nil
            } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            Spacer()
            Text(period.title(for: interval))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                periodOffset += 1
                selectedAngle = nil
            } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .disabled(periodOffset >= 0)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                totalHeader
                donutChart
                if selectedSlice != nil { selectedDetail }
                trendChart
                categoryList
            }
            .padding()
        }
        .refreshable { await currency.refresh() }
    }

    @ViewBuilder
    private var selectedDetail: some View {
        if let slice = selectedSlice {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(slice.color)
                    Text("Топ трат — \(slice.name)")
                        .font(.headline)
                }
                ForEach(topExpenses(for: slice.id)) { expense in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.note?.isEmpty == false ? expense.note! : slice.name)
                            HStack(spacing: 6) {
                                Text(expense.date.formatted(.dateTime.day().month()))
                                if let author = authorName(expense) {
                                    Text("· \(author)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.string(expense.amount, code: expense.currencyCode))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            .padding()
            .background(slice.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var totalHeader: some View {
        VStack(spacing: 4) {
            Text("Всего за период")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Money.string(total, code: baseCurrency))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var donutChart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Сумма", (slice.amount as NSDecimalNumber).doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .foregroundStyle(slice.color)
            .cornerRadius(4)
            // Приглушаем невыбранные сектора, когда что-то выбрано.
            .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.35)
            // Подпись процента прямо на крупных секторах.
            .annotation(position: .overlay) {
                if slice.fraction >= 0.07 {
                    Text("\(Int((slice.fraction * 100).rounded()))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 240)
        .chartOverlay { _ in
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleDonutTap(at: location, in: geo.frame(in: .local))
                    }
            }
        }
        .overlay { centerLabel.allowsHitTesting(false) }
        .animation(.easeInOut(duration: 0.2), value: selectedSlice?.id)
    }

    /// Тап по сектору бублика — то же действие, что тап по категории в списке.
    private func handleDonutTap(at point: CGPoint, in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        let radius = Double(min(rect.width, rect.height)) / 2
        // Тап вне кольца или в центральную дырку — снять выделение.
        guard distance <= radius, distance >= radius * 0.38 else {
            withAnimation { selectedAngle = nil }
            return
        }
        var degrees = atan2(dy, dx) * 180 / .pi + 90 // 0° — сверху, по часовой
        if degrees < 0 { degrees += 360 }
        let total = (self.total as NSDecimalNumber).doubleValue
        guard total > 0 else { return }
        let target = degrees / 360 * total
        let tapped = slice(atCumulative: target)
        withAnimation {
            selectedAngle = (selectedSlice?.id == tapped?.id) ? nil : target
        }
    }

    private func slice(atCumulative value: Double) -> CategorySlice? {
        var cumulative = 0.0
        for slice in slices {
            let amount = (slice.amount as NSDecimalNumber).doubleValue
            if value >= cumulative && value < cumulative + amount { return slice }
            cumulative += amount
        }
        return slices.last
    }

    @ViewBuilder
    private var centerLabel: some View {
        if let selectedSlice {
            VStack(spacing: 2) {
                Text(selectedSlice.name)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(Money.string(selectedSlice.amount, code: baseCurrency))
                    .font(.headline)
                    .monospacedDigit()
                Text("\(Int((selectedSlice.fraction * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
        } else {
            VStack {
                Text("\(slices.count)")
                    .font(.title2.bold())
                Text("категорий")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("По времени")
                .font(.headline)
            Chart(trend) { bucket in
                BarMark(
                    x: .value("Период", bucket.label),
                    y: .value("Сумма", (bucket.amount as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .frame(height: 180)
        }
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("По категориям")
                .font(.headline)
            ForEach(slices) { slice in
                Button {
                    withAnimation {
                        selectedAngle = (selectedSlice?.id == slice.id) ? nil : midAngle(for: slice)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle().fill(slice.color).frame(width: 12, height: 12)
                        Text(slice.name)
                        Spacer()
                        Text("\(Int((slice.fraction * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(Money.string(slice.amount, code: baseCurrency))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        selectedSlice?.id == slice.id ? slice.color.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Нет данных за период", systemImage: "chart.pie")
        } description: {
            Text("Добавьте траты — здесь появятся графики.")
        }
    }
}

private struct CategorySlice: Identifiable {
    let id: String
    let name: String
    let color: Color
    let amount: Decimal
    let fraction: Double
}

private struct TrendBucket: Identifiable {
    var id: Date { date }
    let date: Date
    let label: String
    let amount: Decimal
}

#Preview {
    StatsView()
        .environment(CurrencyService())
        .environment(AuthService())
        .modelContainer(PersistenceController.preview)
}
