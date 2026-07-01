# Фича 1 — Перетаскивание категорий (drag reorder), с синком семьи

Прочитать сперва `00-codebase-map.md` и `BUILD.md`.

## Цель
Дать пользователю менять порядок категорий перетаскиванием на экране категорий.
Новый порядок должен синхронизироваться на все устройства семьи.

## Хорошая новость
Модель `Category` уже имеет `sortOrder: Int`, `@Query` уже по нему сортирует,
`CategoryDTO` уже возит `sortOrder`, а `SyncService` его пушит и пуллит.
→ Правки только на UI + запись `sortOrder`/`updatedAt`. Синк-слой НЕ трогать.

## Изменения

### 1. `CategoryRepository.swift` — метод переупорядочивания
Добавить:
```swift
/// Переписывает sortOrder по новому порядку. updatedAt обязателен для синка.
func reorder(_ ordered: [Category]) {
    for (index, category) in ordered.enumerated() where category.sortOrder != index {
        category.sortOrder = index
        category.updatedAt = .now
    }
    // save как в остальных методах репозитория (посмотреть, как они сохраняют context)
}
```
Сверить со стилем существующих методов (сохраняют ли они context сами или это делает вызывающий).

### 2. `CategoriesView.swift` — `.onMove`
- Добавить `.onMove(perform:)` к `ForEach(scopedCategories)`.
- Обработчик применяет перемещение к массиву и зовёт `reorder`:
```swift
private func move(from source: IndexSet, to destination: Int) {
    var ordered = scopedCategories
    ordered.move(fromOffsets: source, toOffset: destination)
    CategoryRepository(context: context).reorder(ordered)
}
```
- Для удобного драга без EditButton — можно оставить стандартный `.onMove`
  (в List он активируется long-press). Если в тулбаре уже нет EditButton и хочется
  явного «Изменить» — добавить `EditButton()` в toolbar. Выбрать вариант, который
  вписывается в текущий UI экрана (посмотреть toolbar/navigation экрана).

## Важно
- `reorder` пишет `updatedAt = .now` только реально сдвинутым — иначе лишний трафик синка
  и ложные last-write-wins конфликты.
- Порядок берём из `scopedCategories` (уже отфильтрован по семье и отсортирован),
  а не из сырого `categories`.
- Не менять `CategoryDTO`, `SyncService`, `firestore.rules`.

## Критерии приёмки
1. `BUILD SUCCEEDED`.
2. На экране категорий можно перетащить категорию — порядок меняется и сохраняется
   после перезапуска приложения.
3. `sortOrder` и `updatedAt` обновляются → изменение уходит в Firestore
   (проверяемо логикой: `updatedAt > watermark` в `pushDirty`).
4. Только сдвинутые категории получают новый `updatedAt`.

## Коммит
Только файлы кода этой фичи (`CategoriesView.swift`, `CategoryRepository.swift`).
НЕ включать docs и plist.
Сообщение (стиль репозитория, русский), например:
```
Перетаскивание категорий с синхронизацией порядка в семье

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
