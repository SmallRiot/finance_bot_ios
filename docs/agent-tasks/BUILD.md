# Сборка и запуск (для агентов)

Симулятор: iPhone 17 Pro, id `A0CC009C-EEB8-45D9-9628-E795C11F46A4`
(если id не тот — `xcrun simctl list devices available | grep iPhone`).

DerivedData вынесен в scratchpad, чтобы не мусорить в репо.

## Сборка
```bash
cd /Users/user/Developer/finance_bot_ios
DD=/private/tmp/claude-501/-Users-user-Developer-finance-bot-ios/85b18c80-3007-4aa9-9f06-003d23a097a1/scratchpad/DD
xcodebuild -project MillionersBot.xcodeproj -scheme MillionersBot \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=A0CC009C-EEB8-45D9-9628-E795C11F46A4' \
  -derivedDataPath "$DD" build 2>&1 | tail -5
```
Ждём `** BUILD SUCCEEDED **`.

## Установка + запуск + скриншот
```bash
APP="$DD/Build/Products/Debug-iphonesimulator/MillionersBot.app"
xcrun simctl boot A0CC009C-EEB8-45D9-9628-E795C11F46A4 2>/dev/null; open -a Simulator
xcrun simctl install A0CC009C-EEB8-45D9-9628-E795C11F46A4 "$APP"
xcrun simctl launch A0CC009C-EEB8-45D9-9628-E795C11F46A4 com.danila.MillionersBot
sleep 4
xcrun simctl io A0CC009C-EEB8-45D9-9628-E795C11F46A4 screenshot /tmp/shot.png
```

## Установка на реальный телефон (devicectl)
Требует Apple ID в Xcode (Settings → Accounts) для авто-провижининга и «Доверять»
сертификату на самом устройстве (Настройки → Основные → VPN и управление устройством).
```bash
# UDID: xcrun xctrace list devices | grep -i <имя>   → значение в скобках
UDID=<device-udid>
DDx=<scratchpad>/DD-device
xcodebuild -project MillionersBot.xcodeproj -scheme MillionersBot -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DDx" -allowProvisioningUpdates build
APP="$DDx/Build/Products/Debug-iphoneos/MillionersBot.app"
xcrun devicectl device install app --device $UDID "$APP"
xcrun devicectl device process launch --device $UDID com.danila.MillionersBot
```
Ошибка запуска «profile has not been explicitly trusted» → доверить сертификат на телефоне.
«device … Locked» → разблокировать телефон. Подпись free-аккаунта живёт ~7 дней.

## Правка проекта (гем xcodeproj)
Гем поставлен user-install. Запуск скриптов из `scripts/`:
```bash
GEM_HOME=$(ruby -e 'puts Gem.user_dir') ruby scripts/add_widget_target.rb
```

## Требования
- Нужен `MillionersBot/GoogleService-Info.plist` (не в git). Без него краш на старте
  в `FirebaseApp.configure()`. Файл уже на месте локально.
- Крэш-логи: `~/Library/Logs/DiagnosticReports/MillionersBot-*.ips`.
