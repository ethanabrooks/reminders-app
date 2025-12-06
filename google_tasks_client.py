from typing import Iterable, Protocol, cast

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from models import (
    CompleteTaskInput,
    CreateTaskInput,
    ListTasksInput,
    Task,
    TaskList,
    UpdateTaskInput,
    normalize_task,
    now_iso,
)


class ExecutableRequest(Protocol):
    def execute(self) -> dict[str, object]: ...


class TasksMethods(Protocol):
    def list(
        self, *, tasklist: str, showCompleted: bool, showHidden: bool
    ) -> ExecutableRequest: ...

    def insert(
        self, *, tasklist: str, body: dict[str, object]
    ) -> ExecutableRequest: ...

    def patch(
        self,
        *,
        tasklist: str,
        task: str,
        body: dict[str, object],
    ) -> ExecutableRequest: ...

    def delete(self, *, tasklist: str, task: str) -> ExecutableRequest: ...


class TasklistsMethods(Protocol):
    def list(self, maxResults: int) -> ExecutableRequest: ...


class TasksService(Protocol):
    def tasks(self) -> TasksMethods: ...

    def tasklists(self) -> TasklistsMethods: ...


def _expect_dict(value: object, context: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise TypeError(f"Expected dict for {context}, got {type(value).__name__}")
    return value


def _expect_list(value: object | None, context: str) -> list[dict[str, object]]:
    if value is None:
        return []
    if not isinstance(value, Iterable) or isinstance(value, (str, bytes)):
        raise TypeError(f"Expected list for {context}, got {type(value).__name__}")
    items: list[dict[str, object]] = []
    for idx, item in enumerate(value):
        if not isinstance(item, dict):
            raise TypeError(f"Item {idx} in {context} is not a dict")
        items.append(item)
    return items


class GoogleTasksClient:
    """Strongly-typed wrapper around googleapiclient for Tasks."""

    def __init__(self, credentials: Credentials, default_tasklist_id: str) -> None:
        self._service: TasksService = cast(
            TasksService,
            build("tasks", "v1", credentials=credentials, cache_discovery=False),
        )
        self._default_tasklist_id = default_tasklist_id

    def _ensure_tasklist(self, tasklist_id: str | None) -> str:
        return tasklist_id or self._default_tasklist_id

    def _execute(self, request: ExecutableRequest, context: str) -> dict[str, object]:
        response = request.execute()
        return _expect_dict(response, context)

    def list_task_lists(self) -> list[TaskList]:
        request = self._service.tasklists().list(maxResults=100)
        response = self._execute(request, "list_task_lists")
        items = _expect_list(response.get("items"), "tasklists.items")
        return [
            TaskList(id=str(item["id"]), title=str(item.get("title", "")))
            for item in items
            if "id" in item
        ]

    def list_tasks(self, params: ListTasksInput) -> list[Task]:
        tasklist_id = self._ensure_tasklist(params.tasklist_id)
        request = self._service.tasks().list(
            tasklist=tasklist_id,
            showCompleted=True,
            showHidden=True,
        )
        response = self._execute(request, "list_tasks")
        items = _expect_list(response.get("items"), "tasks.items")
        tasks: list[Task] = []
        for item in items:
            if params.status and item.get("status") != params.status:
                continue
            tasks.append(normalize_task(item, tasklist_id))
        return tasks

    def create_task(self, params: CreateTaskInput) -> Task:
        tasklist_id = self._ensure_tasklist(params.tasklist_id)
        body: dict[str, object] = dict(title=params.title)
        if params.notes is not None:
            body["notes"] = params.notes
        if params.due_iso is not None:
            body["due"] = params.due_iso

        request = self._service.tasks().insert(tasklist=tasklist_id, body=body)
        response = self._execute(request, "create_task")
        return normalize_task(response, tasklist_id)

    def update_task(self, params: UpdateTaskInput) -> Task:
        tasklist_id = self._ensure_tasklist(params.tasklist_id)
        body: dict[str, object] = {}
        if params.title is not None:
            body["title"] = params.title
        if params.notes is not None:
            body["notes"] = params.notes
        if params.due_iso is not None:
            body["due"] = params.due_iso
        if params.status is not None:
            body["status"] = params.status

        request = self._service.tasks().patch(
            tasklist=tasklist_id,
            task=params.task_id,
            body=body,
        )
        response = self._execute(request, "update_task")
        return normalize_task(response, tasklist_id)

    def complete_task(self, params: CompleteTaskInput) -> Task:
        tasklist_id = self._ensure_tasklist(params.tasklist_id)
        body: dict[str, object] = dict(status="completed", completed=now_iso())
        request = self._service.tasks().patch(
            tasklist=tasklist_id,
            task=params.task_id,
            body=body,
        )
        response = self._execute(request, "complete_task")
        return normalize_task(response, tasklist_id)

    def delete_task(self, task_id: str, tasklist_id: str | None = None) -> None:
        tasklist = self._ensure_tasklist(tasklist_id)

        request = self._service.tasks().delete(tasklist=tasklist, task=task_id)
        request.execute()
