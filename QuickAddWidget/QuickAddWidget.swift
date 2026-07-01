//
//  QuickAddWidget.swift
//  QuickAddWidget
//
//  Кнопка «+ Трата» для домашнего экрана И экрана блокировки.
//  Тап открывает приложение сразу на форме добавления (deep-link millionersbot://add).
//

import WidgetKit
import SwiftUI

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: Date())], policy: .never))
    }
}

struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuickAddEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.40, blue: 0.90),
                                 Color(red: 0.30, green: 0.28, blue: 0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }
            }
            .widgetURL(URL(string: "millionersbot://add"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            // Локскрин: круглая кнопка «+».
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
            }

        case .accessoryRectangular:
            // Локскрин: строка «+ Трата».
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Быстрая трата")
                        .font(.headline)
                    Text("Добавить")
                        .font(.caption)
                }
                Spacer(minLength: 0)
            }

        default:
            // Домашний экран: большая кнопка.
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                Text("Трата")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct QuickAddWidget: Widget {
    let kind = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Быстрая трата")
        .description("Открывает форму добавления траты одним тапом.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
