# MillionersBot — карта кода для агентов

Общий контекст для фич, трогающих категории и синхронизацию.
Читать вместе с конкретным спеком фичи (`01-*.md`, `02-*.md`).

## Стек
- SwiftUI + SwiftData (локально), Firebase Firestore (синк семьи).
- Target: `MillionersBot`, проект `MillionersBot.xcodeproj`, схема `MillionersBot`.
- Запуск/сборка: см. `docs/agent-tasks/BUILD.md`.

## Модель Category
`MillionersBot/Models/Category.swift`
```swift
@Model
final class Category {
    @Attribute(.unique) var id: String
    var name: String
    var iconSystemName: String
    var colorHex: String
    var householdID: String?
    var isArchived: Bool
    var sortOrder: Int        // порядок в списке (уже есть)
    var updatedAt: Date       // last-write-wins для синка
}
```

## Модель Expense
`MillionersBot/Models/Expense.swift`
```swift
@Model final class Expense {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var currencyCode: String
    var categoryID: String?   // FK → Category.id
    var authorID: String?
    var note: String?
    var date: Date
    var householdID: String?
    var isDeleted: Bool
    var updatedAt: Date
}
```

## Экран категорий
`MillionersBot/Features/Categories/CategoriesView.swift`
- `@Query` уже сортирует по `sortOrder`, затем `name`:
  ```swift
  @Query(filter: #Predicate<Category> { !$0.isArchived },
         sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
  private var categories: [Category]
  ```
- `scopedCategories` фильтрует по `householdID` (текущая семья).
- `ForEach(scopedCategories)` + `.onDelete(perform: archive)` (свайп = архив, не удаление).
- `.onMove` — ПОКА НЕТ (фича 1).

`MillionersBot/Features/Categories/CategoryEditorView.swift`
- Редактирует name / icon (24 SF Symbols) / color (палитра из 12).
- `save()` → `CategoryRepository.update(...)`.

`MillionersBot/Persistence/Repositories/CategoryRepository.swift`
- `add(...)`: `sortOrder = active().count` (в конец списка).
- `update(_:name:icon:colorHex:)`: НЕ трогает `sortOrder`, ставит `updatedAt = .now`.

## Синхронизация (КЛЮЧЕВОЕ — не сломать)
`MillionersBot/Sync/SyncService.swift`
- Push (SwiftData → Firestore), `pushDirty()`:
  ```swift
  for c in fetchAll(Category.self) where c.householdID == hid && c.updatedAt > watermark {
      try? collection(hid, "categories").document(c.id).setData(from: CategoryDTO(c))
      newWatermark = max(newWatermark, c.updatedAt)
  }
  ```
- Pull (Firestore → SwiftData), `applyCategories(_:)`: last-write-wins по `updatedAt`,
  копирует поля DTO в существующую модель, включая `sortOrder`.
- **Watermark** отсекает эхо: любое изменение попадёт в push только если `updatedAt > watermark`.
  → Любое поле, которое меняем, ОБЯЗАНО обновлять `updatedAt = .now`, иначе не синкнется.

`MillionersBot/Sync/DTO/SyncDTOs.swift`
- `CategoryDTO: Codable` — зеркало полей Category (уже включает `sortOrder`).
- `ExpenseDTO`: `Decimal` сериализуется как `String` (`amount = "\(m.amount)"`) для точности.
  Тот же приём использовать для денежных полей.

## Структура Firestore
```
households/{householdID}
  ├─ categories/{categoryID}
  ├─ expenses/{expenseID}
  ├─ savings/{savingID}
  └─ (memberIDs: [uid] в самом документе household)
```
`firestore.rules`: доступ к вложенным коллекциям только членам (`uid in memberIDs`).
Новые поля внутри существующих документов правил НЕ требуют.

## Агрегация трат по категории (для лимитов)
`MillionersBot/Features/Stats/StatsView.swift`
- `expensesInPeriod`: фильтр по scope + `date >= interval.start && date < interval.end`.
- Суммирование в базовой валюте через `inBase($0)` (конвертация валют).
- Группировка: `Dictionary(grouping: expensesInPeriod, by: { $0.categoryID ?? "—" })`.

## Правила для агентов
1. Каждая фича = один коммит. Коммитить ТОЛЬКО файлы кода фичи (не эти docs).
2. Сообщения коммитов — на русском, в стиле репозитория (см. `git log`).
   Заканчивать строкой:
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
3. Любое изменённое поле модели → `updatedAt = .now`, иначе синк не подхватит.
4. Не коммитить `GoogleService-Info.plist` (в .gitignore, содержит ключи Firebase).
5. Собрать проект перед коммитом (см. BUILD.md), убедиться `BUILD SUCCEEDED`.
