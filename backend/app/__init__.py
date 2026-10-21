"""Mobile-app backend package.

Layered architecture:
    api (FastAPI endpoints) -> services (business logic) -> repositories (DB queries)
    -> db/models (SQLAlchemy ORM) -> PostgreSQL database.

DTOs (pydantic schemas) isolate the API layer from the ORM layer.
"""

__version__ = "1.0.0"
