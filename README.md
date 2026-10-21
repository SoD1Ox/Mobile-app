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

## Запуск

### 1. База данных (PostgreSQL)

```bash
createdb task_tracker   # или через psql
```

### 2. Бэкенд

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# скопируйте и заполните .env (DATABASE_URL, SECRET_KEY)
alembic upgrade head            # применить миграции
python -m scripts.seed          # наполнить БД данными
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger: http://localhost:8000/docs

Тестовые аккаунты после seed: `admin/admin123`, `manager/manager123`, `worker/worker123`.

### 3. UI (Flutter)

```bash
cd backend/ui
flutter pub get
flutter run                    # устройство/эмулятор
# адрес бэкенда настраивается в lib/services/api_client.dart (defaultBaseUrl)
```

Сборка: `flutter build apk --release` или `flutter build web --release`.

## Основные экраны UI

- **Авторизация / регистрация** — вход, создание аккаунта, ошибки в диалогах.
- **Главный экран** — приветствие, данные пользователя, навигация на все разделы.
- **Задачи** — список с поиском, фильтрами (статус/приоритет), бесконечной прокруткой.
- **Карточка задачи** — детали, комментарии, смена статуса, редактирование, удаление.
- **Проекты / Клиенты (+контакты)** — просмотр, создание, изменение, удаление.
- **Пользователи** — только для admin.

Все экраны связаны навигацией (кнопка «Назад»), единый стиль, любая ошибка показывается
пользователю сообщением.
