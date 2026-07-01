# Фича 8 — Тесты (ОТЛОЖЕНО, план на будущее)

Статус: **отложено**. Попытка добавить тест-таргет упёрлась в блокер SwiftData
(ниже). Инфраструктура и черновики тестов откачены; код фич 1–7 — рабочий и запушен.
Возобновлять — с учётом раздела «Блокер и решение».

## Блокер, который нужно обойти (главное)
Юнит-тесты, **хостящиеся приложением** (TEST_HOST=MillionersBot.app, нужно для
`@testable import`), падают жёстким `SIGTRAP (brk 1)` на `ModelContext.insert`.
Причина: в одном процессе оказываются **ДВА `ModelContainer` на одну SwiftData-схему** —
контейнер приложения-хоста (создаётся в `MillionersBotApp.init`) и контейнер, который
создаёт тест. Для этой версии SwiftData это фатально (роняет процесс на первом insert).

Что НЕ помогло:
- `@Suite(.serialized)` + `-parallel-testing-enabled NO` — краш остаётся (это не гонка).
- Non-hosted (логический) бандл без TEST_HOST — ломает `@testable import`
  (символы приложения лежат в его executable, нужен `BUNDLE_LOADER`).
- Пропуск `FirebaseApp.configure()` под тестами — ломает `AuthService()` в `@State`
  приложения (`Auth.auth()` требует сконфигурированный Firebase).
- Просто in-memory контейнер и в host, и в тестах — всё равно два контейнера → краш.

## Решение, которое надо реализовать (не доведено, но проверено по частям)
Сделать так, чтобы в процессе был **ровно один** `ModelContainer` — общий для host и тестов:
1. `PersistenceController`: добавить `@MainActor static var testContainer: ModelContainer?`.
2. `MillionersBotApp.init`: оставить `FirebaseApp.configure()`; определить тестовый режим
   `let isTesting = NSClassFromString("XCTestCase") != nil
      || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil`;
   создать `makeContainer(inMemory: isTesting)` и при `isTesting` положить его в
   `PersistenceController.testContainer` (host под тестами — просто оболочка).
3. В тестах НЕ создавать свой контейнер, а брать `PersistenceController.testContainer!`
   и на каждый тест делать свежий `ModelContext(container)` + очистку всех типов
   (`try? ctx.delete(model: Expense.self)` … для Category/Saving/SavingTransaction/
   RecurringExpense/UserProfile/Household), затем `ctx.save()` — для изоляции тестов.
   Хелпер вынести в `MillionersBotTests/TestSupport.swift`.
Это гарантирует один контейнер (нет brk), изоляцию (очистка) и рабочий `@testable`+Firebase.

## Тест-таргет (pbxproj — гем xcodeproj, скрипт `scripts/add_test_target.rb`)
Проверено, что работает: `project.new_target(:unit_test_bundle, 'MillionersBotTests', :ios, '26.2')`,
хост `TEST_HOST=$(BUILT_PRODUCTS_DIR)/MillionersBot.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MillionersBot`,
`BUNDLE_LOADER=$(TEST_HOST)`, bundle id `com.danila.MillionersBotTests`, team KP54874C49,
`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, явные файловые ссылки на тест-файлы,
`test.add_dependency(app)`, и общая схема через `Xcodeproj::XCScheme`
(`add_build_target(app)`, `add_test_target(test)`, `set_launch_target(app)`,
`save_as(project.path, 'MillionersBot', true)`). Всё это собиралось; падение было только
в рантайме на insert (см. блокер).

## Что покрывать (Swift Testing, `import Testing`, все сьюты `@MainActor`)
Черновики были написаны для: Money (parse/string), CurrencyService.convert
(та же валюта / отсутствие курса — на вымышленных кодах, чтобы не зависеть от кэша),
ExpenseRepository (add с явным id, softDelete), CategoryRepository (sortOrder/reorder/
seedDefaults идемпотентность), RecurringService.postDue (пропущенные месяцы, дедуп по
occ-id, неактивные не постятся, детерминизм id, конец месяца), SavingRepository
(addContribution пишет транзакцию, клампинг при снятии, ensureOpeningBalance,
softDeleteTransaction корректирует баланс), DTO round-trip (Category/Expense/Recurring/
SavingTransaction, деньги через строку).
Money/CurrencyService/DTO-тесты проходили (не трогают контейнер); падали только те,
что делают `context.insert` — из-за блокера.

## Прогон — ворота перед пушем (согласовано с пользователем)
Когда тесты заведутся: настроить `pre-push` git-hook (committed `scripts/hooks/pre-push`
+ `git config core.hooksPath scripts/hooks`), запускающий
`xcodebuild test -scheme MillionersBot -destination 'platform=iOS Simulator,id=<sim>'`
и блокирующий пуш при красных тестах.

## Коммит
Когда доделаем: отдельный коммит + `git push`.
