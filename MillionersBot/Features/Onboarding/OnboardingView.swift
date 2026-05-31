//
//  OnboardingView.swift
//  MillionersBot
//
//  Приветственный экран при первом запуске.
//

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 22)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0.0, to: 0.28)
                    .stroke(Color(red: 0.18, green: 0.85, blue: 0.74), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                Text("₽")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 24)

            Text("MillionersBot")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Общий бюджет для всей семьи")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 44)

            VStack(alignment: .leading, spacing: 22) {
                FeatureRow(icon: "bolt.fill", title: "Быстрые траты",
                           text: "Добавляйте расходы в пару тапов с категориями и валютами.")
                FeatureRow(icon: "chart.pie.fill", title: "Наглядная статистика",
                           text: "Куда уходят деньги — по категориям и периодам.")
                FeatureRow(icon: "target", title: "Цели и накопления",
                           text: "Копите на мечты и следите за прогрессом.")
                FeatureRow(icon: "person.2.fill", title: "Семейный доступ",
                           text: "Общий бюджет на всех устройствах в реальном времени.")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Начать")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.85))
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.43, green: 0.41, blue: 0.96),
                         Color(red: 0.23, green: 0.18, blue: 0.80)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingView(onContinue: {})
}
