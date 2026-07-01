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

## Требования
- Нужен `MillionersBot/GoogleService-Info.plist` (не в git). Без него краш на старте
  в `FirebaseApp.configure()`. Файл уже на месте локально.
- Крэш-логи: `~/Library/Logs/DiagnosticReports/MillionersBot-*.ips`.
