#!/usr/bin/env python3
"""
Импорт всей БД из mobile_app_data.json в ваш PostgreSQL.

Использование:
    pip install psycopg2-binary sqlalchemy
    python import_json.py --host localhost --port 5432 --db mobile_app --user postgres --password ВАШ_ПАРОЛЬ

Схема создаётся автоматически (из моделей проекта, если рядом лежит backend/,
либо через alembic). Данные вставляются как есть, с сохранением id.
"""
import argparse, json, os, sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", type=int, default=5432)
    p.add_argument("--db", default="mobile_app")
    p.add_argument("--user", default="postgres")
    p.add_argument("--password", default="")
    p.add_argument("--json", default=os.path.join(os.path.dirname(__file__), "mobile_app_data.json"))
    args = p.parse_args()

    # 1. Создаём схему через модели SQLAlchemy проекта
    here = os.path.dirname(os.path.abspath(__file__))
    for cand in (os.path.join(here, "..", "backend"), "/workspace/backend"):
        if os.path.isdir(os.path.join(cand, "app", "models")):
            sys.path.insert(0, os.path.abspath(cand))
            break
    else:
        sys.exit("Не найден backend/app/models — скопируйте папку backend рядом или используйте pgAdmin Restore (mobile_app.dump)")

    from sqlalchemy import create_engine, text
    from app.db.base import Base  # noqa
    import app.models  # регистрирует все модели на Base.metadata
    url = f"postgresql+psycopg2://{args.user}:{args.password}@{args.host}:{args.port}/{args.db}"
    engine = create_engine(url)
    Base.metadata.create_all(engine)
    print("[1/2] Схема создана.")

    # 2. Вставляем данные из JSON (в отдельной транзакции после commit схемы)
    with open(args.json, encoding="utf-8") as f:
        data = json.load(f)["tables"]

    order = ["users", "clients", "projects", "tasks", "comments", "contacts", "tags", "task_tags"]
    total = 0
    with engine.begin() as conn:
        tables_all = [r[0] for r in conn.execute(text(
            "SELECT tablename FROM pg_tables WHERE schemaname='public'")).fetchall()]
        # удаляем внешние ключи на время импорта (работает без superuser; порядок вставки корректный)
        fk_defs = conn.execute(text("""
            SELECT conrelid::regclass::text, conname,
                   pg_get_constraintdef(oid)
            FROM pg_constraint
            WHERE contype='f' AND connamespace='public'::regnamespace""")).fetchall()
        for tbl, cname, cdef in fk_defs:
            conn.execute(text(f'ALTER TABLE {tbl} DROP CONSTRAINT "{cname}"'))

    with engine.begin() as conn:
        for t in order:
            rows = data.get(t, [])
            if not rows: continue
            cols = list(rows[0].keys())
            placeholders = ", ".join(f":{c}" for c in cols)
            col_list = ", ".join('"' + c + '"' for c in cols)
            stmt = text(f'INSERT INTO "{t}" ({col_list}) VALUES ({placeholders}) ON CONFLICT DO NOTHING')
            conn.execute(stmt, rows)
            total += len(rows)
            print(f"   {t}: {len(rows)} строк")
        # восстанавливаем внешние ключи
        for tbl, cname, cdef in fk_defs:
            conn.execute(text(f'ALTER TABLE {tbl} ADD CONSTRAINT "{cname}" {cdef}'))
        # поднимаем sequence'ы после явной вставки id
        for tb in tables_all:
            try:
                conn.execute(text(
                    f"SELECT setval(pg_get_serial_sequence('{tb}', 'id'), "
                    f"COALESCE((SELECT MAX(id) FROM \"{tb}\") + 1, 1), false)"))
            except Exception:
                pass
    print(f"[2/2] Готово! Загружено записей: {total}")

if __name__ == "__main__":
    main()
