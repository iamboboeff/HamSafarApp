# HamSafar Telegram Collector

Первый безопасный тестовый контур для собственной Telegram-группы. Сервис:

- получает новые и отредактированные сообщения через Bot API long polling;
- при наличии `OPENROUTER_API_KEY` извлекает поездку через бесплатные модели
  OpenRouter в строгий JSON;
- при ошибке всех моделей OpenRouter автоматически возвращается к локальным
  правилам;
- сохраняет исходный текст и результат в SQLite;
- в тестовом режиме отвечает разбором прямо в группе;
- ничего не публикует в боевую базу HamSafar.

## Настройки BotFather

- `/setjoingroups` → `Enable`;
- `/setprivacy` → `Disable`;
- после изменения privacy удалить и повторно добавить бота, если он уже был в
  группе.

## Локальный запуск

Токен нельзя сохранять в `.env` внутри Git. Перед запуском задайте его только
для текущего терминала:

```bash
cd telegram_collector
read -rs "BOT_TOKEN?BotFather token: "
export BOT_TOKEN
export TEST_REPLY_MODE=true
python3 main.py
```

Для ИИ-разбора дополнительно задайте `OPENROUTER_API_KEY`. По умолчанию модели
пробуются в порядке `Nemotron 3 Super free` → `GLM 5.2 free` →
`openrouter/free`; цепочку можно сменить через `OPENROUTER_MODELS`. Телефонные
номера удаляются из текста до отправки в OpenRouter и добавляются в результат
локально.

В тестовой группе доступны команды:

- `/start` или `/help` — описание теста;
- `/chatid` — ID группы для allowlist;
- `/status` — статистика сохранённых сообщений.

## Bothost

1. Подключить Git-репозиторий.
2. Выбрать Python и главный файл `telegram_collector/main.py`.
3. Вставить BotFather token только в поле токена/переменную `BOT_TOKEN`.
4. Добавить переменные из `.env.example`.
   `OPENROUTER_API_KEY` хранить только в секретах Bothost, не в Git.
5. Оставить `TEST_REPLY_MODE=true` только для тестовой группы.
6. После команды `/chatid` записать полученное отрицательное число в
   `ALLOWED_CHAT_IDS` и перезапустить сервис.

База создаётся по пути `${DATA_DIR}/telegram_collector.sqlite3`. На Bothost
`DATA_DIR` должен быть `/app/data`, чтобы сообщения переживали редеплой.

## Автопересылка через реальный аккаунт

Опциональный userbot работает через MTProto и Telethon. Он пересылает только
новые входящие текстовые сообщения из явного allowlist чатов, не читает старую
историю, не обходит запрет Telegram на пересылку и хранит ключи дедупликации в
`${DATA_DIR}/telegram_user_forwarder.sqlite3`.

Установить зависимость и создать сессию нужно локально. Код входа и пароль 2FA
вводятся только в локальном терминале:

```bash
python3 -m venv telegram_collector/.venv
telegram_collector/.venv/bin/python -m pip install -r telegram_collector/requirements.txt
telegram_collector/.venv/bin/python telegram_collector/user_session_tool.py create
telegram_collector/.venv/bin/python telegram_collector/user_session_tool.py list
```

Сессия по умолчанию сохраняется с правами `600` в
`~/.config/hamsafar/telegram_user.session`. Этот файл предоставляет доступ к
аккаунту: его нельзя отправлять в чат, добавлять в Git или показывать в логах.

После команды `list`:

1. записать ID разрешённых исходных групп в `USERBOT_SOURCE_CHAT_IDS`;
2. записать ID группы «Такси HamSafar» в `USERBOT_TARGET_CHAT_ID`;
3. добавить `USERBOT_API_ID`, `USERBOT_API_HASH` и содержимое session-файла
   только в скрытые переменные Bothost;
4. установить `USERBOT_ENABLED=true` и перезапустить сервис.

Чтобы исключить петлю, целевая группа не может находиться в списке источников.
Пересылка идёт от имени реального аккаунта, поэтому источники должны быть
согласованы с администраторами, а скорость должна оставаться умеренной.

## Следующий этап

После проверки доставки сообщений SQLite заменяется/дополняется записью в
таблицу Supabase `external_ride_leads`. В production бот работает молча, а
публикация проходит через модерацию.
