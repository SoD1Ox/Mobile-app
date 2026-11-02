# Запуск «Кадрового агентства» в Windows

Стек проекта: Flutter, FastAPI, SQLAlchemy, Alembic и PostgreSQL. SQLite не используется.

## 1. PostgreSQL

Убедитесь, что служба PostgreSQL запущена. Создайте пользователя и базу данных (при необходимости замените порт):

```sql
CREATE ROLE app_user LOGIN PASSWORD 'app_pass_2026';
CREATE DATABASE mobile_app OWNER app_user;
```

Если роль или база уже существуют, повторно создавать их не нужно. Порт сервера можно посмотреть так:

```powershell
Get-NetTCPConnection -State Listen |
  Where-Object { $_.OwningProcess -in (Get-Process postgres -ErrorAction SilentlyContinue).Id } |
  Select-Object LocalAddress, LocalPort
```

## 2. Настройки API

```powershell
cd C:\Users\SoD1Ox\Documents\Mobile-app\backend
Copy-Item .env.example .env
```

В `backend/.env` укажите порт, базу, пользователя и пароль PostgreSQL. Замените `SECRET_KEY` на случайное значение длиной не менее 32 байт. Сгенерировать его можно так:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

## 3. Миграции и демо-данные

```powershell
cd C:\Users\SoD1Ox\Documents\Mobile-app\backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\alembic.exe upgrade head
.\.venv\Scripts\python.exe -m scripts.seed
```

Тестовые аккаунты: `admin / admin123`, `manager / manager123`, `worker / worker123`.

Если база уже содержит данные, сид-скрипт их не удаляет и не добавляет второй набор. Чтобы обновить только зарплаты созданных сидом вакансий, используйте:

```powershell
.\.venv\Scripts\python.exe -m scripts.seed --refresh-demo-salaries
```

Команда меняет записи с названием вида `Роль #номер`; вручную добавленные вакансии остаются прежними. `--force` полностью заменяет данные демо-набором, поэтому его используйте только для сброса учебной базы.

## 4. Запуск API

```powershell
cd C:\Users\SoD1Ox\Documents\Mobile-app\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Проверка API: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health). Swagger: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

## 5. Запуск Flutter

```powershell
cd C:\Users\SoD1Ox\Documents\Mobile-app\ui
flutter pub get
flutter run -d edge
```

Адрес API по умолчанию: веб/компьютер — `127.0.0.1:8000`, Android-эмулятор — `10.0.2.2:8000`.

## 6. APK для телефона

Компьютер и телефон должны быть в одной Wi-Fi-сети. Узнайте локальный IPv4 компьютера командой `ipconfig`, затем подставьте его в адрес API:

```powershell
cd C:\Users\SoD1Ox\Documents\Mobile-app\ui
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.0.91:8000/api/v1
```

Файл сборки: `ui/build/app/outputs/flutter-apk/app-release.apk`. Оставьте запущенным API-сервер. Если Windows Firewall блокирует подключение из локальной сети, разрешите входящий TCP-порт 8000 для профиля Private.

GitHub Actions автоматически собирает APK для Android-эмулятора после изменений в `ui/`. APK можно скачать как артефакт из [запусков сборки](https://github.com/SoD1Ox/Mobile-app/actions/workflows/android-apk.yml).

## Частые проблемы

| Ошибка | Что проверить |
| --- | --- |
| `password authentication failed` | Значения `DB_USER`, `DB_PASSWORD`, `DB_PORT` в `backend/.env` |
| `relation "users" does not exist` | Запустите `alembic upgrade head` для той же базы, указанной в `.env` |
| `Failed to fetch` в интерфейсе | API запущен ли на порту 8000; на телефоне используйте IP компьютера, а не `127.0.0.1` |
| Таймаут на телефоне | Телефон и компьютер в одной сети; API слушает `0.0.0.0`; доступ к TCP 8000 разрешён в Firewall |
| `SECRET_KEY must be a unique random value` | Замените шаблонный ключ в `.env` случайной строкой длиной от 32 байт |
| `This application requires PostgreSQL` | Проверьте `DATABASE_URL` или настройки `DB_*`; проект работает только с PostgreSQL |
