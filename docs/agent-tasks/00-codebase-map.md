# MillionersBot — карта кода для агентов

Общий контекст для фич. Читать вместе с конкретным спеком (`01-*.md` … `08-*.md`).
Актуально на коммит с экраном «Покупки» (`92cb4a8`+).

## Стек
- SwiftUI + SwiftData (локально), Firebase Firestore (синк семьи).
- App target `MillionersBot` + расширение `QuickAddWidgetExtension` (виджет).
- Проект `MillionersBot.xcodeproj`, схема `MillionersBot`, iOS deployment 26.2.
- Сборка/запуск/установка на устройство: см. `docs/agent-tasks/BUILD.md`.
- Правка pbxproj — только через гем `xcodeproj` (скрипт в `scripts/`), не руками.

## Модели (`MillionersBot/Models/`), все в `PersistenceController.schema`
```swift
@Model final class Category {
    @Attribute(.unique) var id: String
    var name, iconSystemName, colorHex: String
    var householdID: String?
    var isArchived: Bool
    var sortOrder: Int              // порядок (drag reorder, фича 1)
    var monthlyLimit: Decimal?      // месячный лимит (фича 2)
    var updatedAt: Date
}
@Model final class Expense {
    @Attribute(.unique) var id: String
    var amount: Decimal; var currencyCode: String
    var categoryID: String?         // FK → Category.id
    var authorID: String?; var note: String?
    var date: Date; var householdID: String?
    var isDeleted: Bool; var updatedAt: Date
}
@Model final class Saving {
    @Attribute(.unique) var id: String
    var title: String; var targetAmount: Decimal?; var currentAmount: Decimal
    var currencyCode, colorHex: String
    var householdID: String?; var isDeleted: Bool; var updatedAt: Date
    var progress: Double            // computed 0…1
}
@Model final class SavingTransaction {  // история сбережений (фича 5)
    @Attribute(.unique) var id: String
    var savingID: String            // FK → Saving.id
    var amount: Decimal             // + пополнение, − снятие
    var note, authorID, householdID: String?
    var date: Date; var isDeleted: Bool; var updatedAt: Date
}
@Model final class RecurringExpense {   // регулярные траты (фича 4)
    @Attribute(.unique) var id: String
    var amount: Decimal; var currencyCode: String
    var categoryID, note, authorID, householdID: String?
    var anchorDate: Date            // число месяца + время суток
    var lastPostedPeriod: String    // "yyyy-MM" последнего созданного месяца
    var isActive, isDeleted: Bool; var updatedAt: Date
}
@Model final class ShoppingItem {     // совместный список покупок (экран «Покупки»)
    @Attribute(.unique) var id: String
    var title: String; var note: String?
    var isPurchased: Bool           // отмечено купленным
    var authorID, householdID: String?
    var sortOrder: Int              // новые сверху (минимальный sortOrder − 1)
    var isDeleted: Bool; var updatedAt: Date
}
// плюс UserProfile, Household, CurrencyCode (enum).
```

## Область видимости (scope)
`MillionersBot/Support/HouseholdScope.swift` — `inScope(entityHouseholdID, current:)`:
в семье показываем записи семьи, вне семьи — локальные (`householdID == nil`).
Экраны фильтруют через `@AppStorage("householdID")` + `inScope(...)`.

## Репозитории (`MillionersBot/Persistence/Repositories/`)
- `ExpenseRepository`: `add(...)` (есть необязательный `id:` для детерминированных
  occurrence-id регулярных), `update`, `softDelete`.
- `CategoryRepository`: `add/update` (с `monthlyLimit`), `reorder(_:)` (drag, обновляет
  updatedAt только у сдвинутых), `archive`, `activeCount(in:)` и `seedDefaultsIfNeeded(householdID:)`
  — сидинг дефолтов ПО ОБЛАСТИ (вызывается из `RootView.onChange(of: householdID)` при
  входе в личную область; фикс бага «после выхода из семьи нет категорий»).
- `SavingRepository`: `addContribution(_:amount:note:authorID:householdID:)` пишет и
  `SavingTransaction`; `softDeleteTransaction` корректирует `currentAmount`;
  `ensureOpeningBalance` для легаси-сбережений без истории.
- `ShoppingItemRepository`: `active(in:)` (некупленные над купленными),
  `add` (новые сверху), `togglePurchased`, `rename`, `softDelete`,
  `clearPurchased(in:)` (soft delete всего купленного в области).

## Постинг регулярных трат
`MillionersBot/App/RecurringService.swift` — `postDue(context:)`: по активным правилам
создаёт недостающие ежемесячные Expense с детерминированным id `"\(ruleID)#\(yyyy-MM)"`
(дедуп в семье), клампит день на длину месяца. Вызывается из `MillionersBotApp` (`.task`
и `scenePhase == .active`).

## Синхронизация (КЛЮЧЕВОЕ — не сломать) `MillionersBot/Sync/SyncService.swift`
Паттерн одинаков для каждой сущности — listener + `apply<Entity>` (upsert, last-write-wins
по `updatedAt`, деньги через `Money.parse`, двигает watermark) + цикл в `pushDirty`
(`fetchAll(...) where householdID == hid && updatedAt > watermark` → `setData(from: DTO)`) +
привязка в `adoptLocalData` + `fetch<Entity>` helper.
- Коллекции: `categories`, `expenses`, `savings`, `savingTransactions`, `recurring`,
  `shoppingItems`, `members`.
- **Watermark** отсекает эхо и persist'ится в UserDefaults по семье (`syncWatermark.<hid>`,
  фича 7). Любое изменённое поле модели ОБЯЗАНО ставить `updatedAt = .now`.
- Добавляя новую синкаемую сущность: модель → DTO → listener+apply → push-цикл →
  adoptLocalData → fetch-helper. `firestore.rules` НЕ трогать (wildcard
  `match /{collection}/{docId}` уже покрывает любую вложенную коллекцию семьи).

`MillionersBot/Sync/DTO/SyncDTOs.swift` — Codable-зеркала: Member/Category/Expense/Saving/
SavingTransaction/RecurringExpense/ShoppingItem DTO. Деньги — строкой (`"\(m.amount)"`) для точности Decimal.

## Firestore
```
households/{hid}
  ├─ categories/{id}   ├─ expenses/{id}         ├─ savings/{id}
  ├─ savingTransactions/{id}   ├─ recurring/{id}   ├─ shoppingItems/{id}
  └─ members/{uid}
  (memberIDs: [uid] в самом документе household)
```

## Валюта
`MillionersBot/Services/CurrencyService.swift` — `convert(_:from:to:)` (nil если курса нет).
Итоги в базовой валюте через `@AppStorage("baseCurrency")` + `inBase(_:)`
(см. `StatsView`, `ExpensesView` — единый паттерн, фича 6).

## Виджет
Target `QuickAddWidgetExtension` (папка `QuickAddWidget/`): одна кнопка «+ Трата»
(домашний + локскрин) с deep-link `millionersbot://add`. Схема зарегистрирована в
`Config/MillionersBot-Info.plist` (ВНЕ синхронизируемой папки `MillionersBot/`!),
обработка — `RootView.onOpenURL` → `AppState.pendingAddExpense` → `ExpensesView` открывает
`AddExpenseView`. Скрипт таргета: `scripts/add_widget_target.rb`.

## Правила для агентов
1. Каждая фича = один коммит + СРАЗУ `git push origin feature/finance-tracker`.
2. Коммитить только файлы кода фичи (docs можно отдельным коммитом — они версионируются).
   Сообщения — на русском, стиль репо (`git log`), заканчивать:
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
3. Любое изменённое поле модели → `updatedAt = .now`.
4. Не коммитить `GoogleService-Info.plist` (в .gitignore).
5. Перед коммитом собрать (`BUILD SUCCEEDED`) и запустить на симуляторе (без краша миграции).
6. Тесты пока отложены — см. `08-test-suite.md` (блокер двух ModelContainer'ов).
