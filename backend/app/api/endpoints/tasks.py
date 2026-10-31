"""Task endpoints (main entity #2) — the high-volume entity.

Large-data mechanism: list endpoint is paginated (page/page_size) and supports
filtering by status/project plus ILIKE search over title/description.

RBAC:
    read           — any authenticated user;
    create/update  — any authenticated user (author = current user);
    delete         — manager/admin, or the task author;
    comments       — authenticated for read/create, author/manager/admin to delete.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_task_service
from app.dto.comment import CommentCreate, CommentRead
from app.dto.common import Page, PageParams
from app.dto.task import TaskCreate, TaskRead, TaskUpdate
from app.models.task import TaskPriority, TaskStatus
from app.services.errors import DomainError, NotFoundError, PermissionDeniedError, ValidationError
from app.services.task import TaskService

router = APIRouter(prefix="/tasks", tags=["tasks"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    if isinstance(exc, PermissionDeniedError):
        return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=exc.message)
    if isinstance(exc, ValidationError):
        return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[TaskRead], summary="Paginated task list (large data)")
def list_tasks(
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    search: str | None = Query(default=None, max_length=200),
    status_filter: TaskStatus | None = Query(default=None, alias="status"),
    project_id: int | None = Query(default=None, ge=1),
    priority: TaskPriority | None = Query(default=None),
) -> Page[TaskRead]:
    params = PageParams(page=page, page_size=page_size, search=search)
    page_result = service.list_tasks(params, status=status_filter, project_id=project_id)
    if priority is not None:
        filtered = [t for t in page_result.items if t.priority == priority]
        return Page(
            items=filtered,
            total=page_result.total,
            page=page_result.page,
            page_size=page_result.page_size,
            pages=page_result.pages,
        )
    return page_result


@router.get("/{task_id}", response_model=TaskRead, summary="Get a single task")
def get_task(
    task_id: int,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> TaskRead:
    try:
        return service.get_task(task_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED,
             summary="Create a task (author = current user)")
def create_task(
    data: TaskCreate,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> TaskRead:
    try:
        return service.create_task(data, author_id=current_user.id)
    except (NotFoundError, ValidationError) as exc:
        raise _http_error(exc) from exc


@router.put("/{task_id}", response_model=TaskRead, summary="Update a task")
def update_task(
    task_id: int,
    data: TaskUpdate,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> TaskRead:
    try:
        existing = service.get_task(task_id)
        if (
            existing.author_id != current_user.id
            and current_user.role.value == "worker"
        ):
            raise PermissionDeniedError("Only the author or a manager can edit this task")
        return service.update_task(task_id, data)
    except DomainError as exc:
        raise _http_error(exc) from exc


@router.delete("/{task_id}", summary="Delete a task (author or manager/admin)")
def delete_task(
    task_id: int,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> dict[str, str]:
    try:
        existing = service.get_task(task_id)
        if existing.author_id != current_user.id and current_user.role.value == "worker":
            raise PermissionDeniedError("Only the author or a manager can delete this task")
        service.delete_task(task_id)
        return {"status": "deleted"}
    except DomainError as exc:
        raise _http_error(exc) from exc


# ------------------------------------------------------------------ comments
@router.get("/{task_id}/comments", response_model=list[CommentRead],
            summary="List comments of a task")
def list_comments(
    task_id: int,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> list[CommentRead]:
    try:
        return service.list_comments(task_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post("/{task_id}/comments", response_model=CommentRead,
             status_code=status.HTTP_201_CREATED, summary="Add a comment to a task")
def add_comment(
    task_id: int,
    data: CommentCreate,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> CommentRead:
    try:
        return service.add_comment(task_id, data, author_id=current_user.id)
    except DomainError as exc:
        raise _http_error(exc) from exc


@router.delete("/comments/{comment_id}", summary="Delete a comment (author, manager or admin)")
def delete_comment(
    comment_id: int,
    current_user: CurrentUser,
    service: TaskService = Depends(get_task_service),
) -> dict[str, str]:
    # RBAC: workers may only delete their own comments; managers/admins any.
    if current_user.role.value == "worker":
        comment = service.get_comment(comment_id)
        if comment.author_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="A worker can only delete their own comment",
            )
    try:
        service.delete_comment(comment_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc
