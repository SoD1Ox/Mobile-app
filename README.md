# Кадровое агентство — FastAPI + PostgreSQL + Alembic + Flutter

Полноценное приложение кадрового агентства (рекрутинг): REST API на FastAPI, база данных
PostgreSQL с миграциями Alembic, слоистая архитектура (ORM → репозитории → DTO → сервисы → API)
и интерфейс на Flutter в стиле «жидкое стекло» (mint-green + coral, только кастомные векторные
иконки — без стикеров, эмодзи и стандартных Material Icons).

Подробный пошаговый гайд по запуску (Windows, PowerShell, порт PostgreSQL 1616): docs/GUIDE.md

## Возможности

* Авторизация и регистрация (bcrypt-хеш паролей, JWT access/refresh, роли admin / manager / worker)
* Главный экран: приветствие по времени суток, данные пользователя, живая статистика найма
* Вакансии: список с поиском и фильтрами, карточка вакансии, создание / редактирование / удаление
* Кандидаты: профиль, контакты, история откликов, заметки рекрутеров (CRUD)
* Компании: карточки работодателей и контактные лица (CRUD)
* Kanban-воронка найма: перетаскивание откликов между этапами (new → review → interview → offer → hired / rejected)
* Пользователи системы (для администратора)
* Пагинация limit/offset + бесконечная прокрутка (работа с большими данными)
* Сообщения об ошибках на каждом экране, навигация со кнопкой «назад»

## Структура проекта

```
backend/
├── alembic/            # версионированные миграции схемы БД (upgrade/downgrade)
├── app/
│   ├── api/
│   │   ├── dependencies/   # JWT-зависимости, проверка ролей (RBAC)
│   │   └── endpoints/      # тонкие эндпоинты: валидация DTO + вызов сервиса
│   ├── db/                 # фабрика сессий sessionmaker + SQLAlchemy-модели
│   ├── dto/                # Pydantic-схемы запросов/ответов (отдельно от ORM)
│   ├── repositories/       # все SQL-запросы по одной сущности на репозиторий
│   ├── services/           # бизнес-логика (не в эндпоинтах!)
│   ├── security/           # bcrypt, генерация/проверка JWT, refresh-токены
│   └── config/             # настройки из .env
├── scripts/seed.py         # наполнение БД тестовыми данными (~1000+ записей)
└── requirements.txt

ui/                     # Flutter-приложение (staffing_agency_ui)
├── lib/
│   ├── api/                # HTTP-клиент с JWT и авто-refresh
│   ├── models/             # DTO-модели клиента (зеркало Pydantic-схем)
│   ├── screens/            # auth, home, vacancies, candidates, companies,
│   │                       # applications (Kanban), users + формы и детали
│   ├── theme/              # glass.dart / glass_stack.dart — дизайн-система стекла
│   └── widgets/            # стеклянные виджеты + кастомные векторные иконки
docs/GUIDE.md           # пошаговый гайд запуска и типовые проблемы
```

## Быстрый запуск

### Бэкенд

```powershell
cd backend
# 1. .env должен существовать (скопируйте из .env.example, DATABASE_URL на порт 1616)
# 2. зависимости
pip install -r requirements.txt
# 3. схема БД
alembic upgrade head
# 4. тестовые данные
python -m scripts.seed --force
# 5. сервер
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Документация API: http://127.0.0.1:8000/docs

### Интерфейс (Flutter)

```powershell
cd ui
flutter run -d edge
```

Тестовые аккаунты после seed: `admin@example.com` / `manager@example.com` / `worker@example.com`,
пароли: `admin123` / `manager123` / `worker123`.

### Сборка APK

```powershell
cd ui
flutter build apk --release --dart-define=API_BASE_URL=http://<IP-вашего-ПК>:8000/api/v1
```

Gradle-обёртка уже настроена на 8.14.3 (совместима с текущим Flutter).

## Безопасность

* Пароли хранятся только в виде bcrypt-хеши
* Все эндпоинты, кроме /auth/*, требуют Bearer-токен
* RBAC (иерархия ролей):
  * **admin** — всё: CRUD пользователей, все сущности, вся воронка найма;
  * **manager** — полный CRUD вакансий/кандидатов/компаний, тасует всю воронку откликов, назначает ответственных исполнителей (worker'ов);
  * **worker** — видит **только назначенные лично ему отклики** (`assigned_worker_id`), двигает их по воронке (свои кейсы) и оставляет заметки-комментарии; чужие отклики недоступны даже на чтение (серверная фильтрация + 403 на PATCH).
  В UI это отражено навигацией: у worker только вкладки «Мои кейсы» и «Вакансии».
* JWT access (короткий) + refresh (длинный), refresh ротируется
