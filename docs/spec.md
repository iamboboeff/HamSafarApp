# HamSafar — продуктовая спецификация

> Mobile-приложение для совместных междугородних поездок (carpooling) в Таджикистане и Узбекистане. Пассажиры находят попутных водителей по маршруту, бронируют места, общаются в чате до и во время поездки.

---

## 1. Аудитория и роли

| Роль | Что делает |
|------|-----------|
| **Пассажир** | Ищет поездку на нужную дату/маршрут, бронирует места, оплачивает на месте водителю, оставляет отзыв после поездки |
| **Водитель** | Создаёт поездку (маршрут, дата, цена, машина, места), получает запросы на бронь, подтверждает/отклоняет, везёт пассажиров |
| **Гость** | Может смотреть каталог, но не бронировать, не публиковать, не писать в чат |

Один и тот же пользователь может быть и водителем, и пассажиром — роль определяется тем, что он публикует.

---

## 2. Поддерживаемые платформы

- **iOS** 13.0+ (iPhone X и новее; floor определяется `firebase_messaging`. Проверено на iPhone 14 / iOS 26.4)
- **Android** 10+ (API 29, август 2019 и новее. Проверено на Pixel 10 Pro AVD / Android 17)
- Язык интерфейса — **только русский** (приготовка под локализацию есть в коде, но пока строки захардкожены)
- Регионы тарификации — **Таджикистан** (TJS) и **Узбекистан** (UZS); выбирается в профиле, влияет на формат цен

---

## 3. Технический стек

- **Frontend:** Flutter 3.40+ / Dart 3.11+ / Riverpod 3 (state)
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Push:** APNs (нативный через MethodChannel) на iOS, FCM на Android
- **Хранение картинок:** Supabase Storage bucket `chat-attachments` (вложения чата), аватары — base64 в `profiles.avatar_url`
- **Auth:** email+password, email OTP при регистрации

---

## 4. Карта экранов

### Корневая вкладочная навигация (5 табов)

| Таб | Экран | Назначение |
|-----|-------|-----------|
| 🏠 Главная | `HomeScreen` | Приветствие, форма поиска, история поиска |
| 🚗 Мои поездки | `MyTripsScreen` | Будущие и прошлые поездки пользователя (как водителя или пассажира) |
| ➕ Создать | `CreateRideScreen` | Публикация новой поездки (водитель) или запроса (пассажир) |
| 💬 Чат | `ChatListScreen` | Все диалоги, открытие переписки |
| 👤 Профиль | `ProfileScreen` | Свой профиль, настройки, выход |

### Auth-флоу (вне вкладок)

`AuthScreen` — экран входа / регистрации:
- Вход: email + пароль → `signIn`
- Регистрация: email + пароль + ФИО → `signUp` → email OTP → `verifyEmailSignupOtp`
- Восстановление пароля: email → ссылка по почте

### Подэкраны (push-навигация)

| Откуда | Куда | Что показывает |
|--------|-----|----------------|
| Главная → «Поиск» | `SearchResultsScreen` | Карточки поездок и запросов на маршрут, отфильтрованные по дате |
| Search / Trips | `RideDetailScreen` | Полная информация о поездке: маршрут, водитель, машина, отзывы, кнопка «Забронировать» |
| Trips (passenger requests) | `PassengerRequestDetailScreen` | Запрос пассажира на попутку — водитель может откликнуться |
| RideDetail (драйвер) | `MatchingPassengersScreen` | Список подходящих passenger_requests для своей поездки |
| PassengerRequest (пассажир) | `MatchingDriversScreen` | Список подходящих rides для своего запроса |
| RideDetail | `RideBookingCheckoutScreen` | Выбор мест → подтверждение брони |
| Главная (колокольчик) | `ActivityNotificationsScreen` | Лента уведомлений |
| Chat thread | `ChatDetailScreen` | Сообщения, ввод, вложения, system-сообщения о статусе поездки |
| Chat list (свайп) | `ArchiveChatsScreen` | Архив скрытых чатов |
| Профиль → редактировать | `EditProfileScreen` | ФИО, телефон, аватар, страна проживания, пол, дата рождения |
| Профиль → авто | `CarSettingsScreen` | Модель, цвет, номер, количество мест |
| Профиль → настройки | `AppearanceSettingsScreen` / `NotificationSettingsScreen` / `PrivacySettingsScreen` | Тема, push-toggles, смена пароля |
| Профиль → удалить аккаунт | `DeleteAccountScreen` | Двухэтапное подтверждение, soft-delete на бэкенде |
| Драйвер/пассажир в карточке | `UserPublicProfileScreen` | Чужой профиль: аватар, рейтинг, поездки, отзывы, активные маршруты, кнопка «Пожаловаться» |
| Публичный профиль | `ReportUserScreen` | Форма жалобы |
| Профиль → инфо | `InfoScreens` (about / privacy / terms) | Статичные тексты |

---

## 5. Бизнес-логика по областям

### 5.1 Аутентификация
- Сессия восстанавливается автоматически из Secure Storage при старте
- При выходе токен пуша помечается `is_active=false` в БД
- Гостевой режим (без логина) ограничен: можно листать, нельзя действовать

### 5.2 Маркетплейс поездок (Главная + Поиск)
- Загружаются **только будущие** активные поездки и запросы (Postgres filter по `departure_date >= now`)
- **Важно:** если в базе нет данных с будущими датами — каталог легитимно пустой, это не баг
- История поиска (последние 3 уникальных маршрута) сохраняется в Supabase `search_history` + локально

### 5.3 Создание поездки / запроса
- Двухрежимный экран: переключатель «Водитель» / «Пассажир»
- Водитель: from, to, дата, время, цена, число мест, авто, заметки, флаги «instant booking» / «макс 2 на заднем»
- Пассажир: from, to, дата, число пассажиров, комментарий
- Перед публикацией — двойная проверка даты (локальная + HEAD-запрос к серверу для часов)

### 5.4 Бронирование
- Кнопка «Забронировать» открывает `RideBookingCheckoutScreen` с выбором конкретных мест (1, 2, 3, 4 — водитель видит схему салона)
- После подтверждения создаётся `ride_passenger_booking` в статусе `pending` (или `confirmed`, если у поездки включён instant booking)
- Водитель получает push «Новая заявка», в чате открывается thread, выше composer-а появляется баннер с кнопками «Принять / Отклонить»

### 5.5 Лайфцикл поездки (TripLifecycleDomain)
Автоматические system-сообщения в чате на этих событиях:
- **Поездка началась** — когда `departure_date` наступила (in_progress)
- **Поездка завершена** — в течение 12 часов после расчётного `arrival_date`
- **Напоминание об отзыве** — пассажиру, через 10 мин — 7 дней после завершения, если отзыв ещё не оставлен

### 5.6 Чат
- Список диалогов сортируется по последнему сообщению (свежие сверху)
- Свайп влево скрывает чат в архив
- Внутри чата: текст, вложения (фото из галереи), system-сообщения, баннер review prompt у пассажира
- Pending-booking баннер у водителя (Accept / Decline)
- Тап по аватару/имени партнёра в шапке → его публичный профиль

### 5.7 Отзывы
- После завершённой поездки пассажир может оставить 1-5 звёзд + комментарий
- Баннер «Оставьте отзыв» в чате с водителем (можно дважды свернуть, на третий раз пропадает совсем)
- Отзывы видны на публичном профиле водителя (имя автора + рейтинг + комментарий + дата)
- Свой отзыв перезаписывает старый (1 пассажир — 1 отзыв на 1 поездку)

### 5.8 Активные поездки на публичном профиле
- На публичном профиле водителя показываются **его будущие поездки** из текущего маркетплейса (`departureDate > now`), отсортированные по дате
- Тап по строке → `RideDetailScreen`
- Пустое состояние: «Сейчас активных поездок нет.»

### 5.9 Настройки
- **Внешний вид:** светлая / тёмная / системная тема, выбор языка (косметика — всё на русском)
- **Уведомления:** глобальный toggle, по типам (бронирования / сообщения / напоминания) — хранится в Supabase + локально
- **Приватность:** возможность скрыть свой профиль от чужих (`allow_public_profile`), смена пароля (re-auth + update)

### 5.10 Push-уведомления
Триггерятся серверными Postgres-триггерами:
- Новое сообщение в чате → пуш получателю (`enqueue_chat_message_push`)
- Изменение статуса брони → пуш пассажиру (`enqueue_booking_status_push`)

Доставка через edge-функцию `smart-function`:
- iOS — APNs HTTP/2 с JWT (один team key, оба бандла)
- Android — FCM HTTP v1 API (service account JSON)
- Мёртвые токены автоматически деактивируются

### 5.11 Активность (бэйджи)
- Колокольчик на главной показывает счётчик непрочитанных
- Открытие списка → массовая отметка «прочитано» (`mark_all_read`)

### 5.12 Жалобы и удаление аккаунта
- На любого юзера можно подать жалобу: причина (dropdown) + комментарий → отправляется в поддержку через edge-функцию `contact--intake` (email)
- Удаление аккаунта — двухэтапное (подтверждение текстом + чек-бокс), soft-delete в БД

---

## 6. Бэкенд: ключевые сущности

### Таблицы (PostgreSQL)

| Таблица | Назначение |
|---------|-----------|
| `auth.users` | Supabase Auth (email, password hash, session) |
| `profiles` | ФИО, телефон, аватар (base64), пол, ДР, страна, флаги |
| `cars` | Автомобиль водителя (модель, цвет, номер, мест) |
| `rides` | Опубликованные поездки (driver_id, from, to, date, price, seats, notes) |
| `passenger_requests` | Запросы пассажиров на попутку |
| `ride_passenger_bookings` | Брони (ride_id, passenger_id, seats[], status) |
| `chat_threads` | Диалоги (двое участников + booking_id) |
| `chat_messages` | Сообщения (sender, body, kind: text/attachment/system, attachment_url) |
| `chat_participants` | Кто видит какие треды |
| `ride_reviews` | Отзывы (ride_id, author_id, rating, comment) |
| `activity_notifications` | Лента активности (recipient, kind, payload, is_read) |
| `search_history` | Последние маршруты поиска по юзеру |
| `push_device_tokens` | Токены устройств (user_id, device_token, platform, push_environment, app_bundle_id, is_active) |
| `push_jobs` | Очередь пушей (user_id, title, body, data, status: pending/sent/failed) |
| `user_reports` | Жалобы пользователей |
| `app_preferences` | Серверные настройки (notif + appearance) — дублируются в локальном `SharedPreferences` |

### Edge-функции (Deno на Supabase)

| Slug | Назначение |
|------|-----------|
| `smart-function` | Push-диспетчер: читает `push_jobs`, шлёт APNs + FCM, помечает результат |
| `contact--intake` | Прокси формы поддержки/жалоб → email через Resend |
| `cleanup-chat-photos` | Cron: чистит осиротевшие вложения в Storage |

### RPC и триггеры

- `enqueue_push(target_user_id, push_title, push_body, push_data)` — кладёт job + дёргает диспетчер
- `dispatch_push_jobs_now()` — синхронный вызов `smart-function` через `pg_net`
- `enqueue_chat_message_push` (trigger AFTER INSERT on `chat_messages`)
- `enqueue_booking_status_push` (trigger AFTER UPDATE on `ride_passenger_bookings`)
- `public_profile_stats(user_id)` (RPC) — счётчики поездок водитель/пассажир

---

## 7. Идентификаторы и секреты

- **Supabase project:** `yixggnwrnlclcrhttzyo` (URL: `https://yixggnwrnlclcrhttzyo.supabase.co`)
- **Bundle IDs:**
  - iOS (Flutter): `com.hamsafar.hamsafar` (team `DZKNW5XT7G`)
  - iOS (Swift legacy): `com.iboboeff13.hamsafar` (тот же team, общие APNs ключи)
  - Android: `com.hamsafar.hamsafar`
- **Firebase project:** `hamsafar-2a318` (Android только)
- **APNs Auth Key:** `248GTU2852` (активный), `6354UB74N8` (резервный)

---

## 8. Известные ограничения и решения

| Что | Почему |
|-----|--------|
| Все строки на русском, переключатель языка ничего не меняет | В iOS-Swift версии так же; локализация — задача будущая |
| На карте поездки нет визуальной карты, только текст «From → To» | В iOS тоже нет; `MapKit` импортируется, но не используется |
| Пустой каталог поездок | Базы данных могут не содержать будущих дат — это легитимно |
---

## 9. Где исходники

| | Путь |
|---|------|
| Flutter-приложение | `/Users/iboboeff/HamSafar-flutter` |
| iOS-приложение (Swift, эталон порта) | `/Users/iboboeff/Desktop/HamSafar13/HamSafar/HamSafar` |
| Supabase (migrations + edge functions) | `/Users/iboboeff/Documents/Hamsafar/supabase` |
| `google-services.json` (Android Firebase) | `/Users/iboboeff/HamSafar-flutter/android/app/google-services.json` |
| APNs ключи (.p8) | `/Users/iboboeff/Downloads/AuthKey_*.p8` (тестовые / на руках, в репо НЕТ) |
| Firebase Service Account JSON | `/Users/iboboeff/Downloads/hamsafar-2a318.json` (тестовый / на руках, в репо НЕТ) |
