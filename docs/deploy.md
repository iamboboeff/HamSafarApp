# HamSafar — деплой для тестирования

> **iOS** → TestFlight
> **Android** → Firebase App Distribution

Разовая настройка занимает один вечер (TestFlight ~2 часа, FAD ~30 минут). Дальше каждая новая сборка — одна команда + 5 минут ожидания.

---

## Часть 1. iOS / TestFlight

### 1.1 Что нужно один раз сделать (твоя часть)

#### А) Запись приложения в App Store Connect
1. Открыть **https://appstoreconnect.apple.com** → войти под Apple ID разработчика
2. **My Apps** → **«+»** → **New App**
3. Заполнить:
   - **Platform:** iOS
   - **Name:** `HamSafar` (или `HamSafar — Попутки`)
   - **Primary Language:** Russian
   - **Bundle ID:** в дропдауне найди `com.hamsafar.hamsafar` (должен подгрузиться автоматически из developer.apple.com)
   - **SKU:** `hamsafar-ios-flutter` (любая уникальная строка, видна только тебе)
   - **User Access:** Full Access
4. **Create**

#### Б) Заполнить App Information (одно поле блокирует загрузку)
- **App Information → General Information:**
  - **Category:** Travel
  - **Content Rights:** Does NOT contain third-party content
- **App Information → Privacy:**
  - **Privacy Policy URL:** обязательно. Самый быстрый способ — сделать страничку на GitHub Pages или Notion с типовым текстом. Без него Apple не даст загрузить.

#### В) Приготовить ассеты
- **App Icon 1024×1024 PNG** без прозрачности и закруглений (Apple сам округлит). У нас уже есть в `assets/brand/icon.png` — нужна именно та же картинка в `1024×1024`.
- **Screenshots:** минимум по 3 штуки для двух размеров:
  - **6.7" (iPhone 15 Pro Max):** 1290 × 2796
  - **6.5" (iPhone 11 Pro Max / 14 Plus):** 1242 × 2688
  - Снять с симулятора через `xcrun simctl io booted screenshot --type=png screen.png`
- **Promo text** (170 символов) + **Description** (4000 символов) на русском

### 1.2 Что делаю я (когда скажешь «погнали»)

#### Подготовка проекта
```bash
cd /Users/iboboeff/HamSafar-flutter

# 1. Поднять version + build number (см. pubspec.yaml: version: 1.0.0+1)
# Меняем на 1.0.0+2 перед каждой загрузкой
# (Я делаю это автоматически через `flutter pub run cider`, но и руками ок)

# 2. Собрать
flutter build ipa --release

# 3. На выходе:
# build/ios/ipa/Hamsafar.ipa
```

#### Загрузка
Два способа на выбор:

**А) Через Xcode Organizer** (нужен GUI):
1. Открыть Xcode → Window → Organizer → Archives
2. Найти свежий архив → **Distribute App** → **App Store Connect** → **Upload**
3. Auto-подпись с team DZKNW5XT7G
4. Ждать ~10-30 мин пока App Store Connect обработает

**Б) Через Transporter app** (рекомендую):
1. Скачать **Transporter** из Mac App Store
2. Войти под Apple ID
3. Перетащить `Hamsafar.ipa` → **Deliver**
4. Та же обработка ~10-30 мин

**В) Через CLI** (без GUI):
```bash
xcrun altool --upload-app --type ios --file build/ios/ipa/Hamsafar.ipa \
  --username "your@apple.id" --password "@keychain:AC_PASSWORD"
```
(Нужен app-specific password — создаётся на appleid.apple.com)

### 1.3 Настройка TestFlight

В App Store Connect → твоё приложение → вкладка **TestFlight**:

1. **Build** появится через ~10-30 мин после загрузки
2. Кликнуть по сборке → **Test Information**:
   - **Beta App Description** (что тестировать)
   - **What to Test** (changelog для этой версии)
   - **Email** (контакт фидбэка)
3. **Internal Testing** (быстро, без ревью Apple):
   - Добавь тестеров: их Apple ID должны быть в App Store Connect → Users and Access
   - Максимум 100 человек
   - Сборка доступна сразу
4. **External Testing** (нужен beta-ревью Apple — ~1 день первый раз, потом мгновенно):
   - До 10 000 тестеров
   - Можно открыть **Public Link** — любой по ссылке зальёт сборку

### 1.4 Что видят тестеры
1. Получают email от Apple «You're invited to test HamSafar»
2. Ставят бесплатный TestFlight из App Store
3. Открывают invite → ставят сборку
4. Push-уведомления через TestFlight: «Available builds»

### 1.5 Цикл итераций
После первой настройки каждое обновление:
```bash
# 1. Поднять build number в pubspec.yaml
# 2. flutter build ipa --release
# 3. Залить через Transporter
# 4. В TestFlight убедиться что новая сборка появилась
# 5. Тестеры автоматически получат пуш «New build»
```
Время от commit'а до получения тестером: **15-40 минут**.

---

## Часть 2. Android / Firebase App Distribution

### 2.1 Что нужно один раз сделать (твоя часть)

#### А) Включить App Distribution в Firebase Console
1. Открыть https://console.firebase.google.com → проект **hamsafar-2a318**
2. В левом меню → **Release & Monitor** → **App Distribution**
3. Кнопка **Get Started**
4. Выбрать наш Android-app (`com.hamsafar.hamsafar`) → **Done**

#### Б) Добавить тестеров
В App Distribution → **Testers and Groups** → **Add testers**:
- Просто вписываешь email'ы (один на строку)
- Можно сразу создать группу `qa` или `beta` — потом удобнее
- Тестерам приходит email с инвайтом

### 2.2 Что делаю я (когда скажешь «погнали»)

#### Установка CLI один раз
```bash
# Firebase CLI
curl -sL https://firebase.tools | bash
firebase login
```

#### Сборка
```bash
cd /Users/iboboeff/HamSafar-flutter

# Подписанный APK (debug keystore — для теста ок, для прода нужен свой)
flutter build apk --release

# Выход: build/app/outputs/flutter-apk/app-release.apk
```

⚠️ **Важно про подпись:** сейчас в `android/app/build.gradle.kts` стоит `signingConfig = signingConfigs.getByName("debug")` — это OK для FAD-теста, но не подходит для Google Play. Когда будем готовы к Play Store — настроим свой keystore.

#### Загрузка
```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:645854339221:android:074df992563f8a07bcfb9c \
  --groups "qa" \
  --release-notes "Что нового в этой версии:
- Активные поездки на публичном профиле
- Push-уведомления на Android
- Исправлено: фон стал менее ярким"
```
(`--app` — это `mobilesdk_app_id` из `google-services.json`)

### 2.3 Что видят тестеры

1. **Первый раз:** email от Firebase с инвайтом → принять → установить **Firebase App Tester** APK
2. **Каждая новая сборка:** push в App Tester + email
3. Открыть App Tester → найти HamSafar → **Install**
4. Android спросит «Разрешить установку из App Tester?» → разрешить → готово

### 2.4 Цикл итераций
```bash
# Одной строкой:
flutter build apk --release && \
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:645854339221:android:074df992563f8a07bcfb9c \
  --groups "qa" \
  --release-notes "Описание изменений"
```
Время от commit'а до пуша на тестера: **3-5 минут**.

---

## Часть 3. Чек-лист «перед каждой раздачей»

Прежде чем выкатить новую сборку — обязательно:

- [ ] `flutter analyze` — без ошибок
- [ ] `flutter test` — все тесты зелёные (если есть)
- [ ] Поднять `version` в `pubspec.yaml` (например, `1.0.0+1` → `1.0.0+2`)
- [ ] Обновить `qa-checklist.md` если появились новые сценарии
- [ ] Пройти **smoke-test** из `qa-checklist.md` §10 на одном устройстве
- [ ] Подготовить **release notes** на русском — описать что нового и что чинили
- [ ] Push токены: проверить что Supabase Edge Functions деплоились с актуальными секретами (`supabase secrets list`)

---

## Часть 4. Production-релиз (когда дойдём)

Это уже не «для теста», но чтобы знал общую картину:

### iOS (App Store)
- Тот же flow что TestFlight, но **Submit for Review** в App Store Connect
- Apple ревьюер проверяет ~1-3 дня (иногда быстрее)
- Скриншоты + описание + ключевые слова + категория
- После approve — релиз вручную или auto-release

### Android (Google Play)
- Нужен **$25 одноразово** + бизнес-аккаунт (если ИП/ООО)
- Создать свой keystore (`keytool -genkey ...`) и подписывать им release-сборку
- Build AAB: `flutter build appbundle --release`
- Загрузить в Play Console → Internal/Closed/Open testing → Production
- Ревью ~1-3 часа на первую загрузку, потом мгновенно
- Скриншоты + Feature Graphic 1024×500 + описание

---

## Часть 5. Что делаю я vs что делаешь ты

| Шаг | Я (Claude) | Ты |
|-----|------------|-----|
| App Store Connect: создание записи app | ❌ нет доступа | ✅ |
| Privacy Policy URL (страница) | могу написать markdown | ✅ хостинг + ссылка |
| App Icon 1024×1024 | могу сгенерить из существующей | ✅ финальная утв. |
| Скриншоты | могу снять с симулятора через `xcrun simctl` | ✅ выбрать лучшие |
| `flutter build ipa` | ✅ | — |
| Загрузка в TestFlight через Transporter | ❌ нужен GUI | ✅ или через `xcrun altool` если дашь app-specific password |
| TestFlight: добавление тестеров | ❌ | ✅ |
| Firebase App Distribution: включение | ❌ | ✅ (2 клика) |
| FAD: добавление тестеров | через CLI — ✅ если дашь email'ы | можно и ты |
| `flutter build apk` + `firebase appdistribution:distribute` | ✅ | — |
| Release notes | предложу формулировки | ✅ финальная утв. |

---

## Часть 6. Текущее состояние раздачи (по фактам)

Эта секция отражает то, что реально настроено в проекте — обновляй по мере изменений.

### Android — Firebase App Distribution ✅ работает
- Project: `hamsafar-2a318`
- App ID: `1:645854339221:android:074df992563f8a07bcfb9c`
- Группа `qa` создана; добавлены email'ы тестеров
- Последняя сборка: см. https://console.firebase.google.com/project/hamsafar-2a318/appdistribution
- **Команда обновления:**
  ```bash
  flutter build apk --release && \
  firebase appdistribution:distribute \
    build/app/outputs/flutter-apk/app-release.apk \
    --app 1:645854339221:android:074df992563f8a07bcfb9c \
    --groups "qa" \
    --release-notes "Описание изменений"
  ```

### iOS — TestFlight ✅ работает
- App Store Connect запись: **«HamSafar Beta»**, bundle `com.hamsafar.hamsafar`, team `DZKNW5XT7G`
- Внутренняя группа `qa` создана
- **Export Compliance:** автоматизирован — `ITSAppUsesNonExemptEncryption=NO` стоит в `ios/Runner/Info.plist`, Apple больше не задаёт вопрос про шифрование на каждую загрузку
- **Команда обновления:**
  ```bash
  flutter build ipa --release
  # → build/ios/ipa/hamsafar.ipa
  # → загрузить через Transporter app (drag-and-drop)
  ```

### Public-ссылка для любого тестера
- **Android:** Firebase Console → App Distribution → вкладка **Invite links** → New invite link → сгенерируется `https://appdistribution.firebase.dev/i/<code>`
- **iOS:** App Store Connect → TestFlight → Внешнее тестирование → группа → после Beta App Review (~1 день первый раз) появится Public Link `https://testflight.apple.com/join/<code>`. Для review нужно заполнить «Информация о тестировании» + «Что тестировать» + дать тестовый логин/пароль ревьюеру Apple.

### Не забывать перед каждой раздачей
- [ ] Поднять `version` в `pubspec.yaml`
- [ ] `flutter analyze` — без ошибок
- [ ] Описать что нового в release-notes
