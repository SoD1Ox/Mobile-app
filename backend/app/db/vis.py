"""Session factory and the ``Vis`` context manager.

``get_session_factory()`` is a *session factory*: every call returns a brand-new
SQLAlchemy ``Session`` bound to the shared engine.

``Vis`` is the context manager required by the coursework: for **every database
operation** it opens a fresh session, yields it to the caller, then commits (or
rolls back on error) and closes the session.  Repositories receive the factory
and wrap each operation in ``with Vis(self._factory) as session:`` — so no ORM
instance ever leaks outside an open session (all data crosses the boundary as
plain DTOs).
"""

from __future__ import annotations

from typing import Callable

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from app.config.settings import settings

_engine: Engine | None = None
_factory: sessionmaker[Session] | None = None


def get_engine() -> Engine:
    """Lazily create the singleton SQLAlchemy engine for PostgreSQL."""
    global _engine
    if _engine is None:
        _engine = create_engine(
            settings.database_url,
            pool_pre_ping=True,
            echo=False,
        )
    return _engine


def get_session_factory() -> sessionmaker[Session]:
    """Return the session factory; **each call to the factory produces a new session**."""
    global _factory
    if _factory is None:
        _factory = sessionmaker(bind=get_engine(), expire_on_commit=False)
    return _factory


class Vis:
    """Context manager: open a new session -> use it -> commit/rollback -> close.

    Usage::

        with Vis(get_session_factory()) as session:
            repo.do_something(session, ...)
    """

    def __init__(self, factory: Callable[[], Session]) -> None:
        self._factory = factory
        self._session: Session | None = None

    def __enter__(self) -> Session:
        # Every entering opens a NEW session (session-per-operation pattern).
        self._session = self._factory()
        return self._session

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        assert self._session is not None
        try:
            if exc_type is None:
                self._session.commit()
            else:
                self._session.rollback()
        finally:
            self._session.close()
        return False  # never swallow exceptions
