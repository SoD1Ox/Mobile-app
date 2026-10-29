# Готовая база данных mobile_app (PostgreSQL 15)

Полный дамп БД со схемой, данными и тестовыми записями:
users=4, clients=8, projects=12, tasks=1000, comments=250, contacts=15, tags=20, task_tags=1502.

## Файлы
- `mobile_app.dump` — бинарный дамп (pg_restore), сжатый, предпочтительный вариант
- `mobile_app.sql` — текстовый дамп (обычный SQL), если удобнее копировать/вставлять руками

## Вариант A: восстановление через pgAdmin 4 (без терминала)
1. Register → Server:
   - Host: `localhost`, Port: `5432`, Username: `postgres`, Password — ваш пароль от локального PostgreSQL
2. Databases → Create → Database:
   - Name: `mobile_app`, Template: `template1`, Encoding: `UTF8`
   - (опционально) Ownership → Owner: выберите нужную роль
3. ПКМ по базе `mobile_app` → **Restore**:
   - Filename: выберите `mobile_app.dump`
   - Format: **Custom**
   - Role/Owner: оставьте пустым или укажите владельца
   - Вкладка "Restore options" → включите Prioritize owner objects если ругается на права
   - Press Restore

## Вариант B: через терминал (psql/pg_restore)
```bash
createdb mobile_app
pg_restore -d mobile_app --no-owner mobile_app.dump
# или текстовый вариант:
psql -d mobile_app -f mobile_app.sql
```

## Пароли пользователей в дампе (bcrypt hash)
Тестовые аккаунты приложения: admin/admin123, manager/manager123, worker/worker123, testuser/testpass123

## Важно
В дампе есть строка alembic_version — backend приложения использует ту же схему, миграции уже применены.
