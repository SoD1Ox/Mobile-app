# Task Tracker — FastAPI + PostgreSQL + Alembic + Flutter

Полноценное приложение для управления задачами: REST API на FastAPI, база данных PostgreSQL
с миграциями Alembic, слоистая архитектура (ORM → репозитории → DTO → сервисы → API) и
кастомный мобильный интерфейс на Flutter (Material 3, без HTML).

## Архитектура

```
backend/
├── alembic/            # версионированные миграции схемы БД (upgrade/downgrade)
├── app/
│   ├── api/
│   │   ├── dependencies/   # JWT-зависимости, проверка ролей (RBAC), DI провайдеров
│   │   └── endpoints/      # тонкие эндпоинты: только валидация DTO + вызов сервиса
│   ├── db/
│   │   ├── session.py      # фабрика сессий: контекстный менеджер Vis (открыл → сделал → закрыл)
│   │   └── models/         # SQLAlchemy-модели (7 таблиц)
│   ├── dto/                # Pydantic-схемы — защитный слой между ORM и интерфейсом
│   ├── repositories/       # репозиторий = класс со всеми запросами к БД для одной сущности
│   ├── services/           # бизнес-логика (отдельно от эндпоинтов)
│   ├── security/           # bcrypt-хеширование паролей, генерация/проверка JWT, refresh
│   └── config/             # настройки из .env
├── scripts/seed.py         # наполнение БД тестовыми данными (~1000 задач)
└── ui/                     # Flutter-приложение
```

### Сущности БД (7 таблиц, 5+ связей)

| Таблица    | Роль                                          | Связи |
|------------|-----------------------------------------------|-------|
| users      | пользователи системы (роли) — доп. сущность   | 1:N → projects, tasks, comments |
| clients    | основная сущность                             | 1:N → contacts, projects |
| contacts   | контактные лица клиентов                      | N:1 → clients |
| projects   | основная сущность                             | N:1 → clients, users; 1:N → tasks |
| tasks      | основная сущность                             | N:1 → projects, users; M:N → tags |
| tags       | теги                                          | M:N → tasks (task_tags) |
| comments   | комментарии к задачам                         | N:1 → tasks, users |

## Безопасность

- Пароли хранятся **только как bcrypt-хеш**.
- Все эндпоинты, кроме `/auth/login` и `/auth/register`, требуют JWT-токен (Bearer).
- RBAC: три роли — `admin` (полный доступ, управление пользователями), `manager`
  (CRUD клиентов/проектов/задач), `worker` (свои задачи, комментарии, смена статуса).
- Access-токен короткий (15 мин), refresh-токен продлевает сессию автоматически в UI.

## Механизм работы с большим количеством данных

Список задач отдаётся **пагинацией** (`?page=&limit=`) с **поиском/фильтрацией**
(`?search=&status=&priority=&project_id=&assignee_id=`). В UI — бесконечная прокрутка
(бесшовная подгрузка следующих страниц).

## Запуск на своём компьютере (Windows / PowerShell)

### 1. PostgreSQL + база данных

Установите PostgreSQL (например, 16/18 с официального сайта). Служба запускается так:

```powershell
Get-Service -Name "postgresql*" | Start-Service
# узнайте фактический порт сервера (по умолчанию 5432):
Get-NetTCPConnection -State Listen | Where-Object { $_.OwningProcess -in (Get-Process postgres -ErrorAction SilentlyContinue).Id } | Select-Object LocalAddress, LocalPort
```

Создайте базу и пользователя `app_user` (пароли — как в `backend/.env`):

```powershell
$env:PGCLIENTENCODING='UTF8'   # чтобы кириллица в консоли не ломалась
psql -U postgres -h localhost -p 5432 -c "CREATE DATABASE mobile_app;"
psql -U postgres -h localhost -p 5432 -d mobile_app -c "CREATE ROLE app_user LOGIN PASSWORD 'app_pass'; GRANT ALL ON DATABASE mobile_app TO app_user; GRANT ALL ON SCHEMA public TO app_user; ALTER SCHEMA public OWNER TO app_user;"
```

Данные можно залить одним из способов:
- **Готовый дамп** (все таблицы + ~1000 задач): `pg_restore -U postgres -h localhost -p 5432 -d mobile_app --no-owner db_export\mobile_app.dump`
- **или миграции + seed** (шаги 2–3 ниже).

Если порт у вас не 5432 — замените его везде (в `.env`, `alembic.ini`, командах выше).

### 2. Бэкенд (FastAPI)

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1        # если ругается политика: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
pip install -r requirements.txt
alembic upgrade head               # применить миграции (порт должен совпадать с alembic.ini)
python -m scripts.seed             # наполнить БД данными (если не восстанавливали дамп)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Проверка: откройте http://localhost:8000/health → должно быть `{"status":"ok"}`.
Swagger для ручного тестирования API: http://localhost:8000/docs

Тестовые аккаунты после seed: `admin/admin123`, `manager/manager123`, `worker/worker123`.

### 3. UI (Flutter) — запуск на ПК / эмуляторе

Установите Flutter SDK (`https://docs.flutter.dev/get-started/install/windows`) и добавьте
`C:\flutter\bin` в PATH, затем перезапустите терминал. Проверка: `flutter --version`.

```powershell
cd backend\ui
flutter pub get
flutter run -d edge                # или chrome / windows / emulator (список: flutter devices)
```

Адрес бэкенда задаётся в `lib/api/api_client.dart`; по умолчанию:
- Web / десктоп: `http://127.0.0.1:8000/api/v1`
- Android-эмулятор: `http://10.0.2.2:8000/api/v1` (через этот алиас эмулятор видит хост-машину)
- Физический телефон: пересоберите с адресом вашего ПК в LAN:
  `flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.XX:8000/api/v1`
  (IP смотрите командой `ipconfig`, Wi-Fi сети телефона и ПК должны совпадать,
  порт 8000 открыть в брандмауэре: `New-NetFirewallRule -DisplayName "API 8000" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000`)

## Сборка APK (Android)

Нужен Android Studio (SDK + платформы) либо установленный Android SDK. Затем:

```powershell
cd backend\ui
flutter doctor            # убедитесь, что Android toolchain — зелёный
flutter build apk --release
```

Готовый файл: `backend\ui\build\app\outputs\flutter-apk\app-release.apk`.

### Как пользоваться APK на телефоне

1. Перекиньте `app-release.apk` на телефон (USB, Telegram «Saved Messages», облако).
2. На телефоне разрешите установку из неизвестных источников
   (Настройки → Приложения → Специальный доступ → Установка неизвестных приложений).
3. Установите APK, запустите Task Tracker.
4. **Обязательно:** бэкенд должен работать на вашем ПК в той же Wi-Fi сети:
   `uvicorn app.main:app --host 0.0.0.0 --port 8000` (из папки `backend`).
   Если APK собран без `--dart-define=API_BASE_URL=...` по LAN-адресу ПК — приложение
   будет обращаться к 10.0.2.2 (только эмулятор). Пересоберите с верным IP при необходимости.
5. Войдите `admin/admin123` (или зарегистрируйте нового пользователя).

## Основные экраны UI

- **Авторизация / регистрация** — вход, создание аккаунта, ошибки в диалогах.
- **Главный экран** — приветствие, данные пользователя, навигация на все разделы.
- **Задачи** — список с поиском, фильтрами (статус/приоритет), бесконечной прокруткой.
- **Карточка задачи** — детали, комментарии, смена статуса, редактирование, удаление.
- **Проекты / Клиенты (+контакты)** — просмотр, создание, изменение, удаление.
- **Пользователи** — только для admin.

Все экраны связаны навигацией (кнопка «Назад»), единый стиль, любая ошибка показывается
пользователю сообщением.
