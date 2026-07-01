# Фича 5 — История сбережений (операции + комментарий + график)

Прочитать сперва `00-codebase-map.md` и `BUILD.md`.
⚠️ Делать ПОСЛЕ фичи 4: обе правят `SyncService.swift` (параллельно — конфликт).

## Цель
Тап по карточке сбережения → экран деталей: как менялось (пополнения/снятия),
у каждой операции — сумма, дата, автор и комментарий. Сверху — график, на котором
видно, как баланс растёт/падает во времени (к цели).

## Проблема сейчас
`Saving` хранит только `currentAmount` (текущий итог). Отдельных операций НЕТ —
`SavingRepository.addContribution` просто меняет `currentAmount`. Нужна новая модель истории.

## Модель `SavingTransaction` (`Models/SavingTransaction.swift`, новый @Model)
```swift
@Model final class SavingTransaction {
    @Attribute(.unique) var id: String
    var savingID: String        // FK → Saving.id
    var amount: Decimal         // + пополнение, − снятие
    var note: String?           // комментарий
    var authorID: String?
    var householdID: String?
    var date: Date
    var isDeleted: Bool
    var updatedAt: Date
    // init: id=UUID().uuidString, isDeleted=false, updatedAt=.now, date=.now
}
```
Зарегистрировать в `PersistenceController.schema`.

## DTO (`Sync/DTO/SyncDTOs.swift`)
`SavingTransactionDTO: Codable` — зеркало, `amount` строкой (`"\(m.amount)"`), как ExpenseDTO.
Поля: id, savingID, amount(String), note?, authorID?, date, isDeleted, updatedAt. `init(_:)`.

## Синхронизация (`Sync/SyncService.swift`) — мирроринг паттерна Expense
- listener на `collection(hid, "savingTransactions")` → `applySavingTransactions(dtos)`
  (upsert по id, last-write-wins по updatedAt, amount через `Money.parse`, householdID=hid, watermark).
- push-цикл в `pushDirty` для `SavingTransaction` где householdID==hid && updatedAt>watermark.
- `adoptLocalData`: привязать SavingTransaction с householdID==nil к hid.
- `fetchSavingTransaction(_ id:)` helper.
- `firestore.rules` НЕ трогать (wildcard-правило покрывает новую коллекцию).

## SavingRepository
Расширить `addContribution(_ saving, amount, note: String? = nil, authorID: String? = nil, householdID: String? = nil)`:
1. как сейчас — `saving.currentAmount = max(0, saving.currentAmount + amount)`, `saving.updatedAt = .now`;
2. дополнительно — `context.insert(SavingTransaction(savingID: saving.id, amount: amount, note: note,
   authorID: authorID, householdID: householdID ?? saving.householdID, date: .now))`.
Добавить helper `ensureOpeningBalance(_ saving:, transactions:)`: если у сбережения нет операций,
а `currentAmount != 0` (легаси-данные), создать открывающую операцию
`note="Начальный баланс", amount=currentAmount, date=saving.updatedAt`, чтобы сумма операций
сходилась с `currentAmount`. Вызывать при открытии экрана деталей.

## ContributeView (`Features/Savings/ContributeView.swift`)
- Добавить поле `TextField("Комментарий (необязательно)")`.
- В `apply()` передавать `note`, `authorID: auth.uid` (добавить `@Environment(AuthService.self)`),
  `householdID` (из `@AppStorage("householdID")` или `saving.householdID`).

## Экран деталей (`Features/Savings/SavingDetailView.swift` + переход из SavingsView)
- В `SavingsView` карточку сделать `NavigationLink`/переход на `SavingDetailView(saving:)`
  (сейчас тап, вероятно, открывает пополнение — сохранить кнопку «Пополнить», а тап по карточке
  вести на детали; посмотреть текущую разметку SavingsView и вписаться аккуратно).
- `SavingDetailView`:
  - Заголовок: `currentAmount` / `targetAmount`, прогресс-бар (есть `Saving.progress`).
  - **График** (Swift Charts, `import Charts`): линия накопленного баланса по времени.
    Точки: отсортировать операции по дате, вести бегущую сумму; последняя точка = текущий баланс.
    Если задан `targetAmount` — горизонтальная `RuleMark` на уровне цели.
  - Кнопки «Пополнить»/«Снять» (открывают `ContributeView`).
  - Список операций (по убыванию даты): сумма цветом (зелёная +/красная −), заметка,
    дата, автор (в семье — по образцу авторства в `ExpensesView`). Свайп-удаление операции →
    мягко `isDeleted=true; updatedAt=.now` и скорректировать `currentAmount` (вычесть amount).
- `@Query` операций фильтровать по `savingID == saving.id && !isDeleted`, scope по семье.

## Критерии приёмки
1. `BUILD SUCCEEDED`; старт без краша (миграция новых моделей ок).
2. Пополнение/снятие создаёт операцию с комментарием; сумма сходится с `currentAmount`.
3. Тап по карточке открывает детали с графиком и списком операций.
4. График отражает рост/падение; при заданной цели видна линия цели.
5. Операции синкаются в семью (коллекция `savingTransactions`, applySavingTransactions).
6. Легаси-сбережение с ненулевым балансом и без операций показывает «Начальный баланс».

## Коммит и пуш
Отдельный коммит, затем `git push origin feature/finance-tracker`.
Не коммитить `GoogleService-Info.plist`. Сообщение (русский, стиль репо):
```
История сбережений: операции с комментарием, график баланса и экран деталей

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
```
