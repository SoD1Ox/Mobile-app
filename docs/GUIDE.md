# Полный гайд по запуску Task Tracker (Windows)

Стек: FastAPI + SQLAlchemy + Alembic + PostgreSQL, Flutter UI в стиле «жидкое стекло»
(только кастомные векторные иконки, без стикеров и эмодзи).

Все команды — для PowerShell. Если `psql`/`pg_restore` не найдены, используйте
полный путь: `& "C:\Program Files\PostgreSQL\18\bin\psql.exe" ...`.

---

## Шаг 0. Служба PostgreSQL

```powershell
Get-Service postgresql* | Start-Service
Get-Service postgresql*          # статус должен быть Running
```

Узнайте фактический порт сервера (при установке мог быть выбран нестандартный,
например 1616):

```powershell
Get-NetTCPConnection -State Listen |
  Where-Object { $_.OwningProcess -in (Get-Process postgres -ErrorAction SilentlyContinue).Id } |
  Select-Object LocalAddress, LocalPort
```

Дальше везде `<PORT>` = этот порт (5432 или 1616).

Если пароль от пользователя `postgres` забыт: выполните временный сброс через
`trust` в `pg_hba.conf` (папка data: `(Get-CimInstance Win32_Service -Filter
"Name='postgresql-x64-18'").PathName` покажет путь `-D ...`), затем
`ALTER USER postgres PASSWORD '...'`, после чего верните `pg_hba.conf.bak`
и перезапустите службу.

## Шаг 1. Кодирование консоли (важно!)

Русские сообщения об ошибках PostgreSQL в PowerShell отображаются «кракозябрами»
(DzD"D~D`DsD?...). Это НЕ ошибка БД, просто кодировка консоли. Чтобы видеть
нормальный текст, каждый раз перед psql/pg_restore выполняйте:

```powershell
$env:PGCLIENTENCODING="UTF8"
```

## Шаг 2. Роль app_user

Кавычки вокруг пароля обязательны — иначе синтаксическая ошибка:

```powershell
psql -U postgres -h localhost -p <PORT> -c "CREATE ROLE app_user LOGIN PASSWORD 'app_pass';"
```

Если роль уже существует — пропустите шаг (ошибка «role already exists» безопасна).

## Шаг 3. База данных mobile_app

```powershell
psql -U postgres -h localhost -p <PORT> -c "CREATE DATABASE mobile_app OWNER app_user;"
```

Если база уже создавалась ранее с ошибочным восстановлением — пересоздайте чисто:

```powershell
psql -U postgres -h localhost -p <PORT> -c "DROP DATABASE IF EXISTS mobile_app;"
psql -U postgres -h localhost -p <PORT> -c "CREATE DATABASE mobile_app OWNER app_user;"
```

## Шаг 4. Восстановление дампа

```powershell
pg_restore -U postgres -h localhost -p <PORT> -d mobile_app --no-owner db_export/mobile_app.dump
```

Ориентируйтесь на ПОСЛЕДНИЕ строки вывода:
- успеха: `... completed successfully` (или молчаливый выход, код возврата 0);
- если видите `errors ignored on restore: N` — восстановление НЕ завершено
  (обычно из-за того, что в базе уже есть объекты). Решение: шаг 3 (пересоздать
  базу) и повторить шаг 4.

Проверка результата:

```powershell
psql -U postgres -h localhost -p <PORT> -d mobile_app -c "SELECT count(*) FROM tasks;"
# должно вернуть 1000
```

## Шаг 5. Настройка бэкенда (порт БД)

Единственный источник правды для приложения и миграций — файл `backend/.env`:

```
DB_HOST=127.0.0.1
DB_PORT=<PORT>
DB_NAME=mobile_app
DB_USER=app_user
DB_PASSWORD=app_pass
```

В свежем репозитории `.env` не публикуется (секреты). Создайте его из шаблона
`backend/.env.example` и укажите свой порт. Файл `alembic.ini` менять НЕ нужно —
`alembic/env.py` читает URL из `.env`.

## Шаг 6. Виртуальное окружение Python

Активация скрипта venv блокируется политикой выполнения PowerShell
(«running scripts is disabled»). Разрешите её один раз:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Затем:

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1        # в промпте появится (venv)
pip install -r requirements.txt
```

## Шаг 7. Миграции и данные

```powershell
alembic upgrade head
python -m scripts.seed --force     # демо-данные (если дамп не восстанавливали)
```

Тестовые аккаунты: admin/admin123, manager/manager123, worker/worker123.

## Шаг 8. Запуск API

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Проверка в браузере: http://localhost:8000/health -> {"status":"ok","version":"1.0.0"}
Документация Swagger: http://localhost:8000/docs

## Шаг 9. Flutter-интерфейс

```powershell
cd backend\ui
flutter pub get
flutter run -d edge                # или chrome / windows / emulator (список: flutter devices)
```

Адрес бэкенда подставляется автоматически: веб/десктоп — 127.0.0.1:8000,
Android-эмулятор — 10.0.2.2:8000, физический телефон — при сборке через
`--dart-define=API_BASE_URL=http://IP-вашего-ПК:8000/api/v1`.

## Шаг 10. Сборка APK (телефон)

```powershell
cd backend\ui
flutter build apk --release --dart-define=API_BASE_URL=http://<IP-ПК>:8000/api/v1
```

Готовый файл: `build\app\outputs\flutter-apk\app-release.apk`. Перекиньте на
телефон, разрешите установку из неизвестных источников. Телефон и ПК должны
быть в одной Wi-Fi сети; uvicorn должен работать; порт 8000 разрешён в
брандмауэре Windows:

```powershell
New-NetFirewallRule -DisplayName "Allow uvicorn 8000" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000
```

---

## Частые проблемы

| Симптом | Причина и решение |
|---|---|
| `Connection refused ... port 5432` | Сервер слушает другой порт. Узнайте порт (шаг 0) и пропишите `DB_PORT` в `backend/.env`. |
| `password authentication failed` | Не тот пароль. Для postgres — сброс через trust (шаг 0); для app_user проверьте `DB_PASSWORD` в `.env`. |
| `PASSWORD app_pass` — syntax error | Пропущены одинарные кавычки вокруг пароля в SQL. |
| Кракозябры `DzD"D~D`DsD?...` в ошибках psql/pg_restore | Кодировка консоли, см. шаг 1 (`$env:PGCLIENTENCODING="UTF8"`). Сами ошибки при этом настоящие — читайте их суть по ключевым словам (already exists и т.п.). |
| pg_restore: `errors ignored on restore: 60` | В базе уже есть объекты/дубликаты. Пересоздайте базу (шаг 3) и восстановите заново (шаг 4). |
| `нет доступа к таблице alembic_version` / insufficient privilege | Объекты созданы postgres. Выполните: `GRANT ALL ON ALL TABLES IN SCHEMA public TO app_user; GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO app_user; ALTER SCHEMA public OWNER TO app_user;` |
| Activate.ps1: running scripts is disabled | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (шаг 6). |
| Failed to fetch при входе | uvicorn не запущен; браузер резолвит localhost в IPv6 (в UI используется 127.0.0.1); блокировщик/tracking protection в браузере; Cloudflare WARP перехватывает трафик. |
| flutter: команда не найдена | Установите Flutter SDK, распакуйте (например C:\src\flutter), добавьте `bin` в PATH, перезапустите PowerShell. |
