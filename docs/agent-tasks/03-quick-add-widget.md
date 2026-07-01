# Фича 3 — Виджет быстрого добавления траты (deep-link в форму)

Прочитать сперва `00-codebase-map.md` и `BUILD.md`. Реализовано (commit af6c8dc).

## Цель
Виджет (домашний/лок-экран) — одна кнопка «+ Трата». Тап открывает приложение
СРАЗУ на форме добавления траты (сумма с активной клавиатурой, выбор категории,
комментарий). Печатать внутри виджета нельзя (у iOS-виджетов нет текстовых полей),
поэтому ввод — в форме приложения.

## Почему deep-link, а не запись из виджета
Раньше была версия с пресетами и записью в App Group — отклонена: пользователь хочет
вводить произвольную сумму/категорию/коммент. Для этого нужна форма приложения,
поэтому виджет просто открывает её по URL. Ни App Group, ни очереди, ни пресетов.

## Реализация
- **Виджет** `QuickAddWidget/QuickAddWidget.swift`: `StaticConfiguration`, одна кнопка,
  `.widgetURL(URL(string: "millionersbot://add"))`. Семейства: `.systemSmall` (домашний),
  `.accessoryCircular` + `.accessoryRectangular` (экран блокировки). Вид ветвится по
  `@Environment(\.widgetFamily)`; для accessory — `AccessoryWidgetBackground()`/Color.clear.
  `QuickAddWidgetBundle.swift` — `@main WidgetBundle`. `Info.plist` — полный
  (CFBundle* + NSExtension widgetkit), `GENERATE_INFOPLIST_FILE=NO`.
- **URL-схема приложения**: `Config/MillionersBot-Info.plist` (полный Info.plist с
  `CFBundleURLTypes` = `millionersbot`). Приложение: `GENERATE_INFOPLIST_FILE=NO`,
  `INFOPLIST_FILE=Config/MillionersBot-Info.plist`.
  ВАЖНО: этот файл ДОЛЖЕН лежать ВНЕ синхронизируемой папки `MillionersBot/`, иначе
  synchronized-group включит его как ресурс → «Multiple commands produce Info.plist».
- **Обработка deep-link**: `RootView.onOpenURL` → если `scheme==millionersbot && host==add`:
  переключить вкладку на `.expenses` и выставить `AppState.pendingAddExpense = true`.
- **AppState**: поле `pendingAddExpense: Bool`.
- **ExpensesView**: `.onChange(of: appState.pendingAddExpense)` → `isAddingNew = true`
  (показывает существующий лист `AddExpenseView`), сбросить флаг. Форма сама фокусит
  сумму (`@FocusState amountFocused`).

## Правка проекта (гем xcodeproj, НЕ руками)
Скрипт `scripts/add_widget_target.rb` (идемпотентный, «ensure final state»):
- регистрирует URL-схему (INFOPLIST_FILE + GENERATE_INFOPLIST_FILE=NO у app);
- создаёт таргет `QuickAddWidgetExtension` (app-extension, bundle
  `com.danila.MillionersBot.QuickAddWidget`), встраивает в приложение;
- источники виджета: только `QuickAddWidgetBundle.swift` + `QuickAddWidget.swift`;
- вычищает устаревшее (App Group entitlements, общий файл, AddPendingExpenseIntent),
  если осталось от прошлой версии.
Запуск: `GEM_HOME=$(ruby -e 'puts Gem.user_dir') ruby scripts/add_widget_target.rb`
(гем xcodeproj поставлен user-install: `gem install --user-install xcodeproj`).

## Критерии приёмки
1. `BUILD SUCCEEDED`, расширение встроено в `.app/PlugIns/`.
2. Приложение стартует без краша.
3. Собранный `Info.plist` приложения содержит `CFBundleIdentifier`, scene manifest и
   `CFBundleURLTypes`=millionersbot (проверено `plutil -extract`).
4. `simctl openurl millionersbot://add` резолвится в приложение (подтверждено).
5. Тап по виджету открывает форму добавления (ручная проверка — без диалога подтверждения,
   он есть только у simctl openurl).

## Проверено
Сборка ок; запуск без краша; ключи Info.plist на месте; deep-link резолвится в приложение.
НЕ проверено автоматом: фактический тап по виджету на домашнем экране (нужен ручной тап).
