# Фича 4 — Регулярные (ежемесячные) траты

Прочитать сперва `00-codebase-map.md` и `BUILD.md`.

## Цель (упрощённо, по требованию пользователя)
При добавлении траты — тумблер «Повторять каждый месяц». Если включён, трата
становится ежемесячным правилом, привязанным к своему числу и времени. Дальше
приложение САМО добавляет такую трату в это число каждый месяц (авто, без спроса).
Только ежемесячно (других периодов не нужно). Плюс минимальный экран в Настройках,
чтобы правило можно было остановить.

## Модель `RecurringExpense` (новый @Model, файл `Models/RecurringExpense.swift`)
```swift
@Model final class RecurringExpense {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var currencyCode: String
    var categoryID: String?
    var note: String?
    var authorID: String?
    var householdID: String?
    var anchorDate: Date        // исходная дата: даёт число месяца и время суток
    var lastPostedPeriod: String // "yyyy-MM" последнего созданного месяца ("" — ни разу)
    var isActive: Bool
    var isDeleted: Bool          // мягкое удаление для синка
    var updatedAt: Date
    // init со значениями по умолчанию: id=UUID().uuidString, isActive=true, isDeleted=false, updatedAt=.now
}
```
Зарегистрировать в `PersistenceController.schema` (добавить `RecurringExpense.self`).
Опциональные поля/новая модель — лёгкая миграция SwiftData, ручной план не нужен.

## DTO (в `Sync/DTO/SyncDTOs.swift`)
`RecurringExpenseDTO: Codable` — зеркало модели, деньги строкой (`amount = "\(m.amount)"`),
как `ExpenseDTO`. Поля: id, amount(String), currencyCode, categoryID?, note?, authorID?,
anchorDate, lastPostedPeriod, isActive, isDeleted, updatedAt. `init(_ m: RecurringExpense)`.

## Синхронизация (`Sync/SyncService.swift`) — мирроринг существующего паттерна
- В `attachListeners`: добавить listener на `collection(hid, "recurring")` →
  decode `RecurringExpenseDTO` → `applyRecurring(dtos)` (по образцу `applyExpenses`).
- `applyRecurring(_:)`: last-write-wins по `updatedAt`, upsert по id, копировать все поля
  (amount через `Money.parse`), `householdID = hid`, двигать `watermark`.
- В `pushDirty`: добавить цикл
  `for r in fetchAll(RecurringExpense.self) where r.householdID == hid && r.updatedAt > watermark { setData(from: RecurringExpenseDTO(r)) }`.
- В `adoptLocalData`: привязать `RecurringExpense` с `householdID == nil` к hid (как Expense).
- Добавить `fetchRecurring(_ id:)` helper по образцу `fetchExpense`.
- `firestore.rules` НЕ трогать: правило `match /{collection}/{docId}` уже покрывает любую
  вложенную коллекцию семьи, включая `recurring`.

## Движок постинга (`App/RecurringService.swift`)
```swift
enum RecurringService {
    @MainActor static func postDue(context: ModelContext) { ... }
}
```
Логика:
- `now = Date()`, `cal = Calendar.current`.
- Для каждого правила из `fetch(RecurringExpense)` где `isActive && !isDeleted`:
  - идти по месяцам, начиная со следующего после `lastPostedPeriod` (если пусто — с месяца `anchorDate`),
    пока запланированная дата occurrence `<= now`:
    - `period` = "yyyy-MM" этого месяца;
    - `occID = "\(rule.id)#\(period)"`;
    - если `fetchExpense(occID) == nil` (дедуп в семье!) — создать `Expense` с `id: occID`,
      `date` = дата этого месяца: day = min(day(anchorDate), кол-во дней месяца), время суток из `anchorDate`;
      amount/currencyCode/categoryID/note/authorID/householdID — из правила;
    - `rule.lastPostedPeriod = period`; отметить, что правило изменилось.
  - если правило изменилось — `rule.updatedAt = now` (чтобы синкнулось).
- Ограничить цикл (напр. ≤ 60 итераций на правило) от зацикливания.
- В конце `try? context.save()`.
Запуск: в `MillionersBotApp` — `.task { RecurringService.postDue(context: modelContainer.mainContext) }`
и `.onChange(of: scenePhase)` при `.active` (вернуть `@Environment(\.scenePhase)`).

## ExpenseRepository
Добавить в `add(...)` необязательный `id: String = UUID().uuidString`, чтобы можно было
создать трату с детерминированным occurrence id. Существующие вызовы не менять.

## Форма добавления (`Features/Expenses/AddExpenseView.swift`)
- Только для НОВОЙ траты (`expense == nil`): секция с `Toggle("Повторять каждый месяц", isOn: $isRecurring)`
  + пояснение «Будет добавляться каждый месяц <день> числа».
- В `save()` при `isRecurring` (новая трата):
  - `let ruleID = UUID().uuidString`, `period = "yyyy-MM"` от `date`, `occID = "\(ruleID)#\(period)"`;
  - создать текущую трату через `repo.add(..., id: occID)` (это occurrence этого месяца);
  - создать `RecurringExpense(id: ruleID, amount:…, currencyCode:…, categoryID:…, note:…,
    authorID: auth.uid, householdID: householdID.isEmpty ? nil : householdID,
    anchorDate: date, lastPostedPeriod: period, isActive: true)`; `context.insert`; `context.save()`.

## Экран управления (`Features/Settings/RecurringView.swift` + пункт в SettingsView)
- Секция «Данные» в `SettingsView`: `NavigationLink` → `RecurringView`, `Label("Регулярные платежи", systemImage: "arrow.clockwise")`.
- `RecurringView`: `@Query` активных правил (`isActive && !isDeleted`), scope по семье (как в других вью).
  Строка: иконка/название категории или заметка, сумма, «каждое N число». Свайп-удаление →
  мягко: `isActive = false; isDeleted = true; updatedAt = .now` (останавливает и синкает удаление).
  Пустое состояние — `ContentUnavailableView`.

## Критерии приёмки
1. `BUILD SUCCEEDED`; приложение стартует без краша (миграция новой модели ок).
2. Новая трата с включённым тумблером создаёт правило; трата этого месяца в ленте одна (occ id).
3. Правило прошлого месяца при открытии приложения авто-создаёт трату за текущий месяц
   (проверяемо: выставить anchorDate в прошлый месяц → postDue создаёт occurrence).
4. Occurrence не задваивается: повторный `postDue` и постинг с двух устройств семьи дают одну трату (уникальный occ id).
5. Правило синкается в семью (есть в `recurring` коллекции, копируется в applyRecurring).
6. Экран «Регулярные платежи» показывает и останавливает правило (мягкое удаление → перестаёт постить).

## Коммит и пуш
Отдельный коммит, затем `git push origin feature/finance-tracker` (пушим каждую фичу).
Не коммитить `GoogleService-Info.plist`. Сообщение (русский, стиль репо), например:
```
Регулярные ежемесячные траты: тумблер в форме, авто-постинг, синк и управление

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
```
