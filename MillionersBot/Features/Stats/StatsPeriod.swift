//
//  StatsPeriod.swift
//  MillionersBot
//
//  Период для статистики и помощники по агрегации трат во времени.
//  Поддерживает смещение (offset) — навигацию по прошлым неделям/месяцам/годам.
//

import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week = "Неделя"
    case month = "Месяц"
    case year = "Год"

    var id: String { rawValue }

    /// Календарная компонента, по которой бьём период на столбики.
    private var bucketComponent: Calendar.Component {
        self == .year ? .month : .day
    }

    /// Компонента самого периода (неделя/месяц/год).
    private var periodComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// Интервал периода со смещением: offset 0 — текущий, -1 — предыдущий и т.д.
    func interval(now: Date, calendar: Calendar, offset: Int = 0) -> DateInterval {
        let reference = calendar.date(byAdding: periodComponent, value: offset, to: now) ?? now
        return calendar.dateInterval(of: periodComponent, for: reference)
            ?? DateInterval(start: reference, end: reference)
    }

    /// Список начал каждого столбика (с нулями) внутри интервала.
    func bucketStarts(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: bucketComponent, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Начало столбика, в который попадает дата.
    func bucketStart(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: bucketComponent, for: date)?.start ?? date
    }

    /// Подпись столбика на оси X.
    func label(for date: Date) -> String {
        switch self {
        case .week: return date.formatted(.dateTime.weekday(.abbreviated))
        case .month: return date.formatted(.dateTime.day())
        case .year: return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    /// Заголовок периода для навигации (например, «Июнь 2026»).
    func title(for interval: DateInterval) -> String {
        switch self {
        case .week:
            let last = interval.end.addingTimeInterval(-1)
            let from = interval.start.formatted(.dateTime.day().month(.abbreviated))
            let to = last.formatted(.dateTime.day().month(.abbreviated))
            return "\(from) – \(to)"
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year()).capitalized
        case .year:
            return interval.start.formatted(.dateTime.year())
        }
    }
}
