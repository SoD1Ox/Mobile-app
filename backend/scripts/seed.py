"""Seed the PostgreSQL database with demo data for the staffing agency.

Creates:
    * 3 users (admin / manager / worker) — passwords stored ONLY as bcrypt hashes;
    * 10 companies (+ contact persons);
    * 25 skills;
    * ~120 vacancies (with required-skill links);
    * ~400 candidates;
    * ~1200 applications (high-volume entity to demonstrate pagination);
    * recruiter comments on random candidates.

Idempotent-ish: refuses to run on a non-empty ``users`` table unless ``--force``.

Usage::

    cd backend && python -m scripts.seed [--force]
"""

from __future__ import annotations

import random
import sys
from decimal import Decimal

sys.path.insert(0, ".")

from sqlalchemy import func, select, text  # noqa: E402

from app.db.vis import Vis, get_session_factory  # noqa: E402
from app.models import (  # noqa: E402
    Application,
    ApplicationStatus,
    Candidate,
    Comment,
    Company,
    Contact,
    Skill,
    User,
    UserRole,
    Vacancy,
)
from app.security.security import hash_password  # noqa: E402

random.seed(42)

USERS = [
    ("admin", "admin@example.com", "Анна Рекрутер", UserRole.ADMIN, "admin123"),
    ("manager", "manager@example.com", "Иван Менеджеров", UserRole.MANAGER, "manager123"),
    ("worker", "worker@example.com", "Пётр Рабочих", UserRole.WORKER, "worker123"),
]

COMPANIES = [
    ("ТехноСфера", "IT", "Москва", "hr@technosfera.ru"),
    ("СтройГрад", "Строительство", "Санкт-Петербург", "office@stroygrad.ru"),
    ("МедЛайф", "Медицина", "Казань", "care@medlife.ru"),
    ("ФинПром", "Финансы", "Екатеринбург", "people@finprom.ru"),
    ("АгроМир", "Сельское хозяйство", "Краснодар", "kadry@agromir.ru"),
    ("ЛогистикПлюс", "Логистика", "Новосибирск", "hr@logisticplus.ru"),
    ("ЭнергоТех", "Энергетика", "Самара", "personal@energotech.ru"),
    ("Ритейл24", "Розничная торговля", "Москва", "team@retail24.ru"),
    ("ДиджиталВейв", "IT", "Уфа", "join@digitalwave.ru"),
    ("АвтоДрайв", "Автопром", "Нижний Новгород", "hr@autodrive.ru"),
]

CONTACTS_PER_COMPANY = [
    ("Мария Иванова", "HR-менеджер"),
    ("Сергей Петров", "Руководитель отдела"),
    ("Ольга Смирнова", "Референт"),
]

SKILLS = [
    "Python", "Java", "JavaScript", "SQL", "Excel", "1С", "SAP", "AWS",
    "Docker", "Kubernetes", "React", "Vue", "Go", "C++", "C#", ".NET",
    "Android", "iOS", "Swift", "Kotlin", "DevOps", "Linux", "Git",
    "Тестирование QA", "Аналитика данных",
]

POSITIONS = [
    ("Python-разработчик", ["Python", "SQL", "Docker", "Git"]),
    ("Frontend-разработчик", ["JavaScript", "React", "Git"]),
    ("Backend-разработчик", ["Java", "SQL", "Kubernetes"]),
    ("QA-инженер", ["Тестирование QA", "Python", "Git"]),
    ("Data-аналитик", ["SQL", "Excel", "Аналитика данных"]),
    ("DevOps-инженер", ["DevOps", "Linux", "AWS", "Docker"]),
    ("Менеджер по продажам", ["Excel"]),
    ("Бухгалтер", ["1С", "Excel"]),
    ("Инженер-проектировщик", ["AutoCAD" if False else "C++"]),
    ("Водитель-экспедитор", []),
    ("Оператор станка ЧПУ", []),
    ("Медицинская сестра", []),
    ("Кладовщик", ["1С"]),
    ("HR-специалист", ["Excel", "1С"]),
    ("iOS-разработчик", ["Swift", "iOS", "Git"]),
    ("Android-разработчик", ["Kotlin", "Android", "Git"]),
]

CITIES = ["Москва", "Санкт-Петербург", "Казань", "Екатеринбург", "Новосибирск",
          "Краснодар", "Самара", "Уфа", "Нижний Новгород", "Челябинск"]

SPECIALIZATIONS = ["Разработка", "Тестирование", "Аналитика", "Бухгалтерия",
                   "Продажи", "Логистика", "Медицина", "Производство", "HR", "Поддержка"]

FIRST_NAMES = ["Алексей", "Мария", "Дмитрий", "Анна", "Сергей", "Ольга", "Иван",
               "Екатерина", "Павел", "Наталья", "Тимур", "Алина", "Роман", "Юлия"]
LAST_NAMES = ["Иванов", "Петрова", "Сидоров", "Кузнецова", "Смирнов", "Попова",
              "Лебедев", "Козлова", "Новиков", "Морозова", "Волков", "Алексеева"]

COMMENT_TEXTS = [
    "Отличное резюме, приглашён на интервью.",
    "Не хватает опыта по стеку, рассмотреть через полгода.",
    "Прошёл техническое интервью успешно.",
    "Ожидаем оффер от компании-заказчика.",
    "Перезвонить в понедельник.",
    "Кандидат взял паузу на размышление.",
    "Отказ: не устроила зарплатная вилка.",
]


def main(force: bool = False) -> None:
    factory = get_session_factory()

    # --- Self-healing bootstrap -------------------------------------------
    # If the schema is missing (user forgot `alembic upgrade head`), create
    # all tables from ORM metadata and stamp the base alembic revision, so
    # later `alembic upgrade head` remains a clean no-op.
    from sqlalchemy import inspect as sa_inspect

    from app.db.base import Base
    from app.db.vis import get_engine
    import app.models  # noqa: F401  (register mappers on Base.metadata)

    engine = get_engine()
    inspector = sa_inspect(engine)
    existing = set(inspector.get_table_names())
    if "users" not in existing:
        print("Schema missing -> creating tables from ORM metadata ...")
        Base.metadata.create_all(engine)
        try:
            with engine.begin() as conn:
                conn.exec_driver_sql(
                    "CREATE TABLE IF NOT EXISTS alembic_version ("
                    "version_num VARCHAR(32) NOT NULL, "
                    "CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num))")
                conn.exec_driver_sql(
                    "INSERT INTO alembic_version VALUES ('a1f2c3d4e5b6') "
                    "ON CONFLICT DO NOTHING")
        except Exception:
            pass  # non-fatal; alembic CLI still works afterwards
        existing = set(sa_inspect(engine).get_table_names())

    # --- Schema drift self-heal -------------------------------------------
    # If the DB was migrated by an *older* revision of the code (e.g. the
    # applications table exists but lacks columns added later, such as
    # assigned_worker_id), create any missing tables from ORM metadata and
    # add missing columns, so seed and API work regardless of whether
    # `alembic upgrade head` re-ran after a git pull.
    Base.metadata.create_all(engine, checkfirst=True)
    inspector = sa_inspect(engine)
    existing = set(inspector.get_table_names())
    # Self-heal missing columns on every table that gained fields after the
    # initial migration (e.g. applications.assigned_worker_id / status_history,
    # users.completion_score).  Safe: only ADDs nullable columns.
    _DEFAULTS = {"status_history": "''"}
    for tname, table in Base.metadata.tables.items():
        if tname not in existing or tname == "alembic_version":
            continue
        try:
            db_cols = {c["name"] for c in inspector.get_columns(tname)}
        except Exception:
            continue
        missing = set(table.columns.keys()) - db_cols - {"id", "created_at", "updated_at"}
        for col in sorted(missing):
            column = table.columns[col]
            try:
                col_type = column.type.compile(dialect=engine.dialect)
                sql = f'ALTER TABLE {tname} ADD COLUMN "{col}" {col_type}'
                if not column.nullable:
                    default = _DEFAULTS.get(col)
                    if default is None:
                        continue  # cannot safely add a required column w/o default
                    sql += f" NOT NULL DEFAULT {default}"
                with engine.begin() as conn:
                    conn.exec_driver_sql(sql)
                print(f"Schema drift fixed: added column {tname}.{col}")
            except Exception as exc:  # pragma: no cover - best effort
                print(f"Could not auto-add {tname}.{col}: {exc}")

    with Vis(factory) as session:
        users_total = session.scalar(select(func.count()).select_from(User)) or 0
    if users_total and not force:
        print("Database already contains users. Use --force to seed anyway.")
        return

    if force:
        with Vis(factory) as session:
            # Delete children -> parents (FK-safe on every dialect).
            for table in ("applications", "comments", "candidates",
                          "vacancy_skills", "vacancies", "contacts",
                          "companies", "skills", "users"):
                if table in existing:
                    session.execute(text(f"DELETE FROM {table}"))
            session.commit()
            # Reset PK sequences so fresh inserts don't collide with old
            # auto-increment counters (PostgreSQL only; SQLite uses
            # sqlite_sequence which DELETE already frees).
            bind = session.get_bind()
            if bind.dialect.name == "postgresql":
                for table in ("applications", "comments", "candidates",
                              "vacancies", "contacts", "companies",
                              "skills", "users"):
                    try:
                        session.execute(text(
                            f"ALTER SEQUENCE {table}_id_seq RESTART WITH 1"))
                    except Exception:
                        session.rollback()
                session.commit()

    # ------------------------------------------------------------- users
    user_ids: list[int] = []
    with Vis(factory) as session:
        for username, email, full_name, role, password in USERS:
            user = User(
                username=username, email=email, full_name=full_name,
                password_hash=hash_password(password), role=role,
            )
            session.add(user)
            session.flush()
            user_ids.append(user.id)
    manager_id, worker_id = user_ids[1], user_ids[2]
    print(f"users: {len(user_ids)}")

    # ------------------------------------------------------------ skills
    skill_ids: dict[str, int] = {}
    with Vis(factory) as session:
        for name in SKILLS:
            skill = Skill(name=name)
            session.add(skill)
            session.flush()
            skill_ids[name] = skill.id
    print(f"skills: {len(skill_ids)}")

    # --------------------------------------------------- companies + contacts
    company_ids: list[int] = []
    with Vis(factory) as session:
        for name, industry, city, email in COMPANIES:
            company = Company(
                name=name, industry=industry, address=f"г. {city}, ул. Примерная, 1",
                email=email, phone=f"+7 ({random.randint(100,999)}) {random.randint(100,999)}-{random.randint(10,99)}-{random.randint(10,99)}",
            )
            session.add(company)
            session.flush()
            company_ids.append(company.id)
            for i, (cname, cpos) in enumerate(CONTACTS_PER_COMPANY[: random.randint(1, 3)]):
                session.add(Contact(
                    full_name=f"{cname} ({name[:6]})" if i == 0 else cname,
                    position=cpos, company_id=company.id,
                    email=f"{cpos.split()[0].lower()}{i}@{email.split('@')[1]}",
                ))
    print(f"companies: {len(company_ids)}")

    # --------------------------------------------------------- vacancies
    vacancies: list[tuple[int, list[int]]] = []  # (vacancy_id, skill ids)
    with Vis(factory) as session:
        for n in range(120):
            title, req_skills = random.choice(POSITIONS)
            salary_from = Decimal(random.randrange(40, 350, 10) * 10000)
            vacancy = Vacancy(
                title=f"{title} #{n+1}",
                description=f"Требуется {title.lower()} в компанию. Проект №{n+1}, "
                            f"оформление по ТК РФ, ДМС, гибридный график.",
                salary_from=salary_from,
                salary_to=salary_from + Decimal(random.randrange(3, 20, 1) * 10000),
                city=random.choice(CITIES),
                remote=random.random() < 0.3,
                company_id=random.choice(company_ids),
            )
            session.add(vacancy)
            session.flush()
            sids = [skill_ids[s] for s in req_skills if s in skill_ids]
            if sids:
                vacancy.skills = list(session.scalars(select(Skill).where(Skill.id.in_(sids))))
            vacancies.append((vacancy.id, sids))
    print(f"vacancies: {len(vacancies)}")

    # -------------------------------------------------------- candidates
    candidate_ids: list[int] = []
    with Vis(factory) as session:
        for n in range(400):
            first, last = random.choice(FIRST_NAMES), random.choice(LAST_NAMES)
            if first.endswith("а") or first in {"Мария", "Анна", "Ольга", "Екатерина", "Наталья", "Алина", "Юлия"}:
                last = last[:-1] + "а" if last.endswith("ов") else last
            candidate = Candidate(
                full_name=f"{last} {first}",
                email=f"candidate{n+1}@example.com",
                phone=f"+7 9{random.randint(10,99)} {random.randint(100,999)}-{random.randint(10,99)}-{random.randint(10,99)}",
                city=random.choice(CITIES),
                specialization=random.choice(SPECIALIZATIONS),
                experience_years=random.randint(0, 20),
                resume_url=f"https://resumes.example.com/{n+1}.pdf" if random.random() < 0.8 else None,
            )
            session.add(candidate)
            session.flush()
            candidate_ids.append(candidate.id)
    print(f"candidates: {len(candidate_ids)}")

    # ------------------------------------------------------ applications
    statuses = list(ApplicationStatus)
    weights = [30, 25, 20, 10, 5, 10]  # new..rejected distribution
    pairs: set[tuple[int, int]] = set()
    created = 0
    with Vis(factory) as session:
        while created < 1200:
            cid = random.choice(candidate_ids)
            vid, _ = random.choice(vacancies)
            if (cid, vid) in pairs:
                continue
            pairs.add((cid, vid))
            st = random.choices(statuses, weights=weights)[0]
            # Иерархия: взятые в работу этапы (review/interview/offer)
            # закрепляются за ответственным исполнителем (worker).
            assigned = worker_id if st in (
                ApplicationStatus.REVIEW, ApplicationStatus.INTERVIEW,
                ApplicationStatus.OFFER,
            ) and random.random() < 0.7 else None
            session.add(Application(
                candidate_id=cid, vacancy_id=vid,
                status=st,
                manager_id=random.choice([None, manager_id]),
                assigned_worker_id=assigned,
            ))
            created += 1
        session.flush()
    with Vis(factory) as session:
        n_assigned = session.scalar(
            select(func.count()).select_from(Application)
            .where(Application.assigned_worker_id == worker_id)
        )
    print(f"applications: {created} (assigned to worker: {n_assigned})")

    # ---------------------------------------------------------- comments
    with Vis(factory) as session:
        for cid in random.sample(candidate_ids, 150):
            session.add(Comment(
                text=random.choice(COMMENT_TEXTS),
                candidate_id=cid,
                author_id=random.choice([manager_id, worker_id]),
            ))
    print("comments: 150")
    print("Seed completed.")


if __name__ == "__main__":
    main(force="--force" in sys.argv)
