# Фича 8 (улучшение №8) — Тесты + прогон при каждом изменении

Прочитать сперва `00-codebase-map.md` и `BUILD.md`.
Делать ПОСЛЕ фич 5/6/7 (чтобы тесты покрывали финальный код: регулярные, сбережения и т.д.).

## Часть 1. Тест-таргет (pbxproj — через гем xcodeproj, НЕ руками)
Проекта тест-таргета сейчас нет. Добавить `MillionersBotTests` (unit-test bundle),
хостится приложением (`TEST_HOST`/`BUNDLE_LOADER` на MillionersBot.app), зависимость на app,
`@testable import MillionersBot`. Firebase слинкуется через хост; `GoogleService-Info.plist`
уже локально есть, поэтому запуск ок (для CI понадобится плист — отметить).

Скрипт `scripts/add_test_target.rb` (идемпотентный, по образцу `add_widget_target.rb`):
- `project.new_target(:unit_test_bundle, 'MillionersBotTests', :ios, '26.2')`;
- build settings: `PRODUCT_BUNDLE_IDENTIFIER=com.danila.MillionersBotTests`,
  `TEST_HOST = $(BUILT_PRODUCTS_DIR)/MillionersBot.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MillionersBot`,
  `BUNDLE_LOADER = $(TEST_HOST)`, `SWIFT_VERSION=5.0`, `DEVELOPMENT_TEAM=KP54874C49`,
  `GENERATE_INFOPLIST_FILE=YES`, `IPHONEOS_DEPLOYMENT_TARGET=26.2`;
- синхронизируемая группа/папка `MillionersBotTests/` (или явные файловые ссылки);
- зависимость `test_target.add_dependency(app)`;
- добавить таргет в Test-action схемы `MillionersBot` (общая схема в `xcshareddata/xcschemes/`;
  если её нет — создать shared-схему через `Xcodeproj::XCScheme`, добавить app как buildable и
  тест-таргет в `test_action`). Проверить, что `xcodebuild test -scheme MillionersBot` видит тесты.

## Часть 2. Тесты (Swift Testing, `import Testing` + `@testable import MillionersBot`)
Все — на in-memory контейнере: `PersistenceController.makeContainer(inMemory: true)`.
Firebase/SyncService напрямую НЕ трогаем (нужен Firestore) — тестируем чистую логику и DTO.

Покрыть:
- **Money**: `parse`/`string` (запятая/точка, пусто, отрицательные, точность Decimal).
- **ExpenseRepository**: add (в т.ч. с явным `id`), update ставит `updatedAt`, softDelete.
- **CategoryRepository**: `reorder` меняет только сдвинутые и ставит updatedAt; sortOrder при add; seedDefaults.
- **RecurringService.postDue**: (а) правило из прошлого месяца создаёт occurrence за текущий;
  (б) день 31 привязки → клампится на короткий месяц (фев); (в) дедуп: повторный postDue не
  задваивает (одинаковый `id "\(ruleID)#\(yyyy-MM)"`); (г) `isActive=false`/`isDeleted=true` — не постит.
- **SavingRepository**: addContribution меняет currentAmount и создаёт `SavingTransaction`;
  `ensureOpeningBalance` для легаси (currentAmount>0, нет операций).
- **DTO round-trip**: Model → DTO → JSON → decode сохраняет поля и точность денег
  (Category/Expense/Recurring/SavingTransaction/Saving) — деньги через String.
- **Occurrence-id детерминизм**: одна пара (ruleID, period) → один id.
- **CurrencyService.convert**: базовые кейсы (та же валюта → та же сумма; nil при отсутствии курса).

Именование файлов: `MillionersBotTests/<Area>Tests.swift`.

## Часть 3. Прогон при каждом изменении (хук)
Настраивается отдельно через настройку харнесса (skill update-config), не агентом.
Из-за времени iOS-тестов (сборка+симулятор ~1–2 мин) прогон на КАЖДОЕ нажатие нецелесообразен.
План: хук на завершение хода (Stop) или ручная быстрая команда, запускающая
`xcodebuild test -scheme MillionersBot -destination 'platform=iOS Simulator,id=A0CC009C-...'`
только если менялись `*.swift`. Кэдэнс согласовать с пользователем.

## Критерии приёмки
1. `xcodebuild test -scheme MillionersBot -destination 'platform=iOS Simulator,id=A0CC009C-EEB8-45D9-9628-E795C11F46A4'` → все тесты зелёные.
2. Тест-таргет собирается и хостится приложением; `@testable import` работает.
3. Покрыты пункты из Части 2.

## Коммит и пуш
Отдельный коммит (скрипт, тест-таргет, тесты, правка pbxproj/схемы), затем
`git push origin feature/finance-tracker`.
```
Юнит-тесты: логика трат, категорий, регулярных, сбережений, DTO + тест-таргет

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
