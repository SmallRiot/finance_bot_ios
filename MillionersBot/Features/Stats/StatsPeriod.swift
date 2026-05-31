//
//  StatsPeriod.swift
//  MillionersBot
//
//  Период для статистики и помощники по агрегации трат во времени.
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

    /// Компонента самого периода (текущая неделя/месяц/год).
    private var periodComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    func interval(now: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: periodComponent, for: now)
            ?? DateInterval(start: now, end: now)
    }

    /// Список начал каждого столбика (с нулями) внутри периода.
    func bucketStarts(now: Date, calendar: Calendar) -> [Date] {
        let interval = interval(now: now, calendar: calendar)
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
}
