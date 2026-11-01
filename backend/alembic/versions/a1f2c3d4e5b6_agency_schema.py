"""agency schema: staffing-agency tables (companies, vacancies, candidates, applications)

Revision ID: a1f2c3d4e5b6
Revises:
Create Date: 2026-11-01

Full alembic history for the staffing-agency domain.  ``down_revision`` is
empty (this is the base revision); ``downgrade`` drops every agency table and
the legacy task-manager artifacts, so ``alembic downgrade base && upgrade head``
rebuilds the schema from scratch on any database state.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1f2c3d4e5b6"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Idempotent bootstrap for PostgreSQL: the user's local DB may contain a
    # partial or legacy (Task Manager) schema created before alembic was
    # used. Drop all known tables IF EXISTS so this migration can run on any
    # state. SQLite (used only for sandbox tests) has no DROP TYPE / CASCADE,
    # so guard by dialect name.
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        for legacy in ("projects", "tasks", "task_tags", "tags", "clients"):
            op.execute(f'DROP TABLE IF EXISTS "{legacy}" CASCADE')
        for table in ("comments", "applications", "candidates",
                      "vacancy_skills", "vacancies", "contacts", "companies",
                      "skills", "users"):
            op.execute(f'DROP TABLE IF EXISTS "{table}" CASCADE')
        op.execute('DROP TYPE IF EXISTS user_role')
        op.execute('DROP TYPE IF EXISTS application_status')

    # --- users -------------------------------------------------------------
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("username", sa.String(length=50), nullable=False),
        sa.Column("email", sa.String(length=120), nullable=False),
        sa.Column("full_name", sa.String(length=150), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "role",
            sa.Enum("admin", "manager", "worker", name="user_role"),
            nullable=False,
            server_default="worker",
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_users_username"), "users", ["username"], unique=True)
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)

    # --- companies ----------------------------------------------------------
    op.create_table(
        "companies",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=150), nullable=False),
        sa.Column("email", sa.String(length=120), nullable=True, unique=True),
        sa.Column("phone", sa.String(length=30), nullable=True),
        sa.Column("address", sa.String(length=255), nullable=True),
        sa.Column("industry", sa.String(length=100), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_companies_name"), "companies", ["name"], unique=False)

    # --- contacts (company contact persons) ---------------------------------
    op.create_table(
        "contacts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("full_name", sa.String(length=150), nullable=False),
        sa.Column("position", sa.String(length=100), nullable=True),
        sa.Column("phone", sa.String(length=30), nullable=True),
        sa.Column("email", sa.String(length=120), nullable=True),
        sa.Column(
            "company_id",
            sa.Integer(),
            sa.ForeignKey("companies.id", ondelete="CASCADE"),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_contacts_company_id"), "contacts", ["company_id"], unique=False)

    # --- skills ---------------------------------------------------------------
    op.create_table(
        "skills",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=50), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # --- vacancies -------------------------------------------------------------
    op.create_table(
        "vacancies",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("salary_from", sa.Numeric(12, 2), nullable=True),
        sa.Column("salary_to", sa.Numeric(12, 2), nullable=True),
        sa.Column("city", sa.String(length=80), nullable=True),
        sa.Column("remote", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "company_id",
            sa.Integer(),
            sa.ForeignKey("companies.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_vacancies_title"), "vacancies", ["title"], unique=False)
    op.create_index(op.f("ix_vacancies_city"), "vacancies", ["city"], unique=False)
    op.create_index(op.f("ix_vacancies_company_id"), "vacancies", ["company_id"], unique=False)

    # --- vacancy_skills (M2M association) ---------------------------------------
    op.create_table(
        "vacancy_skills",
        sa.Column(
            "vacancy_id",
            sa.Integer(),
            sa.ForeignKey("vacancies.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "skill_id",
            sa.Integer(),
            sa.ForeignKey("skills.id", ondelete="CASCADE"),
            primary_key=True,
        ),
    )

    # --- candidates --------------------------------------------------------------
    op.create_table(
        "candidates",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("full_name", sa.String(length=150), nullable=False),
        sa.Column("email", sa.String(length=120), nullable=True, unique=True),
        sa.Column("phone", sa.String(length=30), nullable=True),
        sa.Column("city", sa.String(length=80), nullable=True),
        sa.Column("specialization", sa.String(length=100), nullable=True),
        sa.Column("experience_years", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("resume_url", sa.String(length=255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_candidates_full_name"), "candidates", ["full_name"], unique=False)
    op.create_index(op.f("ix_candidates_city"), "candidates", ["city"], unique=False)
    op.create_index(
        op.f("ix_candidates_specialization"), "candidates", ["specialization"], unique=False
    )

    # --- applications (high-volume junction entity) --------------------------------
    op.create_table(
        "applications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "status",
            sa.Enum(
                "new", "review", "interview", "offer", "hired", "rejected",
                name="application_status",
            ),
            nullable=False,
            server_default="new",
        ),
        sa.Column(
            "candidate_id",
            sa.Integer(),
            sa.ForeignKey("candidates.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "vacancy_id",
            sa.Integer(),
            sa.ForeignKey("vacancies.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "manager_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint("candidate_id", "vacancy_id", name="uq_application_candidate_vacancy"),
    )
    op.create_index(op.f("ix_applications_status"), "applications", ["status"], unique=False)
    op.create_index(op.f("ix_applications_candidate_id"), "applications", ["candidate_id"], unique=False)
    op.create_index(op.f("ix_applications_vacancy_id"), "applications", ["vacancy_id"], unique=False)
    op.create_index(op.f("ix_applications_manager_id"), "applications", ["manager_id"], unique=False)

    # --- comments (recruiter notes about candidates) ----------------------------------
    op.create_table(
        "comments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("text", sa.String(length=2000), nullable=False),
        sa.Column(
            "candidate_id",
            sa.Integer(),
            sa.ForeignKey("candidates.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "author_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_comments_candidate_id"), "comments", ["candidate_id"], unique=False)


def downgrade() -> None:
    # reverse dependency order; also tolerate leftover legacy tables
    for table in (
        "comments",
        "applications",
        "candidates",
        "vacancy_skills",
        "vacancies",
        "skills",
        "contacts",
        "companies",
        "users",
        # legacy task-manager artifacts (may not exist — drop if present)
        "task_comments",
        "tasks",
        "project_members",
        "projects",
    ):
        try:
            op.drop_table(table)
        except Exception:
            pass
    if op.get_bind().dialect.name == "postgresql":
        for enum in ("application_status", "user_role"):
            try:
                op.execute(f"DROP TYPE IF EXISTS {enum}")
            except Exception:
                pass
