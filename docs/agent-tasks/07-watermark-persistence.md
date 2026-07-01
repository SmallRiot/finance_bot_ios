# Фича 7 (улучшение №7) — Сохранение watermark синка между запусками

Прочитать сперва `00-codebase-map.md` и `BUILD.md`.
⚠️ Правит `SyncService.swift` — не запускать параллельно с другими правками этого файла.

## Проблема
В `SyncService` `watermark` — только в памяти, на `stop()`/старте = `.distantPast`.
Значит при каждом старте `pushDirty()` заливает в Firestore ВСЕ локальные записи заново
(`setData` по каждой трате/категории/…). Работает (идемпотентно), но это лишние тысячи
операций записи и трафик на каждый запуск = деньги за Firestore и износ квоты.

## Решение
Персистить watermark по семье в `UserDefaults` и грузить его на `start()`.

### Изменения (`Sync/SyncService.swift`)
- Ключ: `private func watermarkKey(_ hid: String) -> String { "syncWatermark.\(hid)" }`.
- В `start(householdID:)`: перед `pushDirty()` загрузить сохранённый watermark:
  ```swift
  let saved = UserDefaults.standard.object(forKey: watermarkKey(householdID)) as? Date
  watermark = saved ?? .distantPast
  ```
  (грузить ПОСЛЕ `self.householdID = householdID`).
- Добавить `private func persistWatermark()`:
  ```swift
  if let hid = householdID {
      UserDefaults.standard.set(watermark, forKey: watermarkKey(hid))
  }
  ```
- Вызывать `persistWatermark()` в конце `pushDirty()` (после `watermark = newWatermark`)
  и в конце `applyCategories/applyExpenses/applySavings/applyMembers/applyRecurring/...`
  (везде, где двигается watermark) — проще всего вызвать один раз в `withRemoteApply`
  после `work()`, и отдельно в конце `pushDirty()`.
- В `stop()` НЕ сбрасывать persisted-значение; in-memory `watermark` можно оставить
  сброс в `.distantPast` (при следующем `start` подтянется из UserDefaults).

## Важно
- Не сломать защиту от эха: watermark по-прежнему двигается вперёд при apply/push.
- Первый запуск новой семьи: ключа нет → `.distantPast` → полный первичный push (ожидаемо).
- Даты в UserDefaults сериализуются как есть (Date поддерживается).

## Критерии приёмки
1. `BUILD SUCCEEDED`, старт без краша, синк работает.
2. После первого запуска ключ `syncWatermark.<hid>` появляется в UserDefaults.
3. На втором запуске без новых локальных изменений `pushDirty` НЕ перезаливает старые записи
   (проверяемо: watermark стартует не с distantPast, а с сохранённого значения).

## Коммит и пуш
Отдельный коммит, затем `git push origin feature/finance-tracker`.
```
Сохранение watermark синка между запусками (меньше лишних записей в Firestore)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
