"""Seed the PostgreSQL database with demo data.

Creates:
    * 3 users (admin / manager / worker) — passwords stored ONLY as bcrypt hashes;
    * 8 clients (+ contact persons);
    * 12 projects;
    * 20 tags;
    * ~1000 tasks (high-volume entity to demonstrate pagination) + comments.

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
from app.models import Client, Comment, Contact, Project, Tag, Task, UserRole  # noqa: E402
from app.models.task import TaskPriority, TaskStatus  # noqa: E402
from app.security.security import hash_password  # noqa: E402

random.seed(42)

USERS = [
    ("admin", "admin@example.com", "Администратор Системы", UserRole.ADMIN, "admin123"),
    ("manager", "manager@example.com", "Иван Менеджеров", UserRole.MANAGER, "manager123"),
    ("worker", "worker@example.com", "Пётр Рабочих", UserRole.WORKER, "worker123"),
]

CLIENTS = [
    ("ООО Ромашка", "office@romashka.ru", "+7-495-111-2233", "Москва, ул. Складочная, 1"),
    ("АО ТехноСофт", "info@technosoft.ru", "+7-812-222-3344", "СПб, Невский пр., 100"),
    ("ИП Иванов А.А.", None, "+7-903-333-4455", "Казань, ул. Баумана, 5"),
    ("Банк «ФинГрад»", "hr@fingrad.ru", "+7-495-444-5566", "Москва, Пресненская наб., 12"),
    ("АО ЭнергоМир", "contact@energomir.ru", "+7-383-555-6677", "Новосибирск, Красный пр., 45"),
    ("МедиаХолдинг", "pr@mediaholding.ru", "+7-495-666-7788", "Москва, Дубининская, 53"),
    ("СтройИнвест Групп", None, "+7-861-777-8899", "Краснодар, ул. Красная, 70"),
    ("ЛогистикПро", "ops@logisticpro.ru", "+7-916-888-9900", "Екатеринбург, Малышева, 15"),
]

PROJECT_NAMES = [
    "Мобильное приложение «Кошелёк»", "Портал самообслуживания", "CRM-модуль интеграции",
    "Внутренний дашборд аналитики", "Личный кабинет подрядчика", "Сайт компании v2",
    "Система документооборота", "Биллинг и тарификация", "IoT-панель мониторинга",
    "Чат-бот поддержки", "Маркетинговая платформа", "API шлюз третьих сторон",
]

TAGS = [
    "backend", "frontend", "mobile", "devops", "qa", "design", "api", "db",
    "security", "docs", "hotfix", "feature", "ux", "performance", "bug",
    "refactor", "analytics", "integration", "infra", "urgent",
]

TASK_TITLES = [
    "Реализовать", "Переписать", "Проверить", "Оптимизировать", "Спроектировать",
    "Задокументировать", "Протестировать", "Настроить", "Обновить", "Исправить",
]
TASK_OBJECTS = [
    "экран авторизации", "список задач", "пагинацию", "кэш ответов API",
    "модель пользователя", "валидацию форм", "логирование ошибок", "индекс в БД",
    "CI-конвейер", "макеты главной страницы", "фильтр по статусам", "поиск по названию",
    "DTO комментариев", "миграцию схемы", "эндпоинт обновления", "кнопку «назад»",
    "загрузку аватара", "обработку 401", "токен-обновление", "памятку пользователя",
]


def _empty(session) -> bool:
    return (session.scalar(select(func.count()).select_from(Task)) or 0) == 0


def main(force: bool = False) -> None:
    factory = get_session_factory()
    with Vis(factory) as session:
        if not force and not _empty(session):
            print("Database already contains tasks. Use --force to reseed.")
            return
        if force:
            for table in ("comments", "task_tags", "tasks", "tags", "projects",
                          "contacts", "clients", "users"):
                session.execute(text(f"TRUNCATE {table} CASCADE"))
            session.flush()

        # ---- users -------------------------------------------------------
        from app.models.user import User

        users = []
        for username, email, full_name, role, pwd in USERS:
            u = User(
                username=username, email=email, full_name=full_name,
                password_hash=hash_password(pwd), role=role, is_active=True,
            )
            session.add(u)
            users.append(u)
        session.flush()

        # ---- clients + contacts ------------------------------------------
        clients = []
        for name, email, phone, address in CLIENTS:
            c = Client(name=name, email=email, phone=phone, address=address)
            session.add(c)
            clients.append(c)
        session.flush()
        for c in clients:
            for i in range(random.randint(1, 3)):
                session.add(Contact(
                    full_name=f"Контакт {c.name.split()[0][:8]}-{i+1}",
                    position=random.choice(["Директор", "IT-менеджер", "Бухгалтер", "Юрист"]),
                    phone=f"+7-900-{random.randint(1000000, 9999999)}",
                    email=f"contact{i+1}@{c.name[:6].lower().replace(' ', '')}.ru",
                    client_id=c.id,
                ))

        # ---- projects ------------------------------------------------------
        projects = []
        for i, pname in enumerate(PROJECT_NAMES):
            projects.append(Project(
                name=pname,
                description=f"Проект №{i+1}: {pname.lower()} для клиента «{clients[i % len(clients)].name}».",
                budget=Decimal(random.randint(100_000, 9_000_000)),
                client_id=clients[i % len(clients)].id,
            ))
        session.add_all(projects)

        # ---- tags ----------------------------------------------------------
        tags = [Tag(name=t) for t in TAGS]
        session.add_all(tags)
        session.flush()

        # ---- tasks (~1000, high volume) + comments -------------------------
        statuses = list(TaskStatus)
        priorities = list(TaskPriority)
        batch = []
        for n in range(1, 1001):
            task = Task(
                title=f"{random.choice(TASK_TITLES)} {random.choice(TASK_OBJECTS)} #{n}",
                description=(
                    f"Задача {n}: необходимо выполнить работы и сдать результат "
                    f"заказчику. Критерии приёмки описаны в документации проекта."
                ),
                status=random.choices(statuses, weights=[20, 35, 15, 25, 5])[0],
                priority=random.choices(priorities, weights=[30, 40, 20, 10])[0],
                estimate_hours=random.randint(1, 80),
                project_id=random.choice(projects).id,
                author_id=random.choice(users).id,
            )
            task.tags = random.sample(tags, k=random.randint(0, 3))
            batch.append(task)
        session.add_all(batch)
        session.flush()

        for task in random.sample(batch, k=250):
            session.add(Comment(
                text=f"Комментарий к задаче #{task.id}: статус уточнён, работаю дальше.",
                task_id=task.id,
                author_id=random.choice(users).id,
            ))

    print("Seed complete:")
    print("  users: admin/admin123, manager/manager123, worker/worker123")
    print(f"  clients: {len(CLIENTS)}, projects: {len(PROJECT_NAMES)}, tasks: 1000")


if __name__ == "__main__":
    main(force="--force" in sys.argv)
