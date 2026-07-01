# Фича 6 (улучшение №9) — Единая базовая валюта в итогах ленты

Прочитать сперва `00-codebase-map.md` и `BUILD.md`.

## Цель
Сейчас дневные итоги в ленте трат показываются отдельно по каждой валюте и
склеиваются через « · » (в `ExpensesView.dayTotal` есть комментарий «конвертация в M6»).
Свести все суммы к БАЗОВОЙ валюте через уже готовый `CurrencyService`, как это делает
`StatsView` (`inBase`).

## Изменения (`Features/Expenses/ExpensesView.swift`)
- Добавить, если ещё нет: `@Environment(CurrencyService.self) private var currency` (уже есть),
  `@AppStorage("baseCurrency") private var baseCurrency: String = CurrencyCode.default.rawValue`.
- Хелпер `inBase(_ e: Expense) -> Decimal`: `currency.convert(e.amount, from: e.currencyCode, to: baseCurrency) ?? e.amount`
  (тот же приём, что в `StatsView` — посмотреть и переиспользовать один-в-один).
- `dayTotal(_ items:)`: суммировать `inBase` по всем тратам дня и показывать одной суммой
  в базовой валюте: `Money.string(sum, code: baseCurrency)`. Убрать группировку по валютам и « · ».
- Проверить, нет ли других мест с той же per-currency-склейкой (напр. общий итог) — при наличии
  привести к базовой аналогично. НЕ трогать саму модель/суммы трат (конвертация только для отображения).

## Важно
- Конвертация — только визуальная; `Expense.amount`/`currencyCode` не менять.
- Если курс недоступен (`convert` вернул nil) — фолбэк на исходную сумму (как в StatsView).

## Критерии приёмки
1. `BUILD SUCCEEDED`, старт без краша.
2. Дневной итог в ленте — одна сумма в базовой валюте (не «100 ₽ · 5 $»).
3. Трата в другой валюте корректно входит в итог по текущему курсу; при отсутствии курса — фолбэк.

## Коммит и пуш
Отдельный коммит, затем `git push origin feature/finance-tracker`.
```
Единая базовая валюта в дневных итогах ленты

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
