from typing import Iterable, Protocol, cast

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from models import Task, TaskList, normalize_task


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
    """Thin, strongly-typed wrapper around googleapiclient for Tasks.
    
    All methods take primitive parameters. Business logic belongs in server.py.
    """

    def __init__(self, credentials: Credentials) -> None:
        self._service: TasksService = cast(
            TasksService,
            build("tasks", "v1", credentials=credentials, cache_discovery=False),
        )

    def list_task_lists(self) -> list[TaskList]:
        """List all task lists."""
        request = self._service.tasklists().list(maxResults=100)
        response = _expect_dict(request.execute(), "list_task_lists")
        items = _expect_list(response.get("items"), "tasklists.items")
        return [
            TaskList(id=str(item["id"]), title=str(item.get("title", "")))
            for item in items
            if "id" in item
        ]

    def list_tasks(self, tasklist_id: str) -> list[Task]:
        """List all tasks in a tasklist (includes completed and hidden)."""
        request = self._service.tasks().list(
            tasklist=tasklist_id,
            showCompleted=True,
            showHidden=True,
        )
        response = _expect_dict(request.execute(), "list_tasks")
        items = _expect_list(response.get("items"), "tasks.items")
        return [normalize_task(item, tasklist_id) for item in items]

    def insert_task(
        self,
        tasklist_id: str,
        title: str,
        notes: str | None = None,
        due: str | None = None,
    ) -> Task:
        """Insert a new task."""
        body: dict[str, object] = dict(title=title)
        if notes is not None:
            body["notes"] = notes
        if due is not None:
            body["due"] = due

        request = self._service.tasks().insert(tasklist=tasklist_id, body=body)
        response = _expect_dict(request.execute(), "insert_task")
        return normalize_task(response, tasklist_id)

    def patch_task(
        self,
        tasklist_id: str,
        task_id: str,
        title: str | None = None,
        notes: str | None = None,
        due: str | None = None,
        status: str | None = None,
        completed: str | None = None,
    ) -> Task:
        """Patch an existing task. Only non-None fields are sent."""
        body: dict[str, object] = {}
        if title is not None:
            body["title"] = title
        if notes is not None:
            body["notes"] = notes
        if due is not None:
            body["due"] = due
        if status is not None:
            body["status"] = status
        if completed is not None:
            body["completed"] = completed

        request = self._service.tasks().patch(
            tasklist=tasklist_id,
            task=task_id,
            body=body,
        )
        response = _expect_dict(request.execute(), "patch_task")
        return normalize_task(response, tasklist_id)

    def delete_task(self, tasklist_id: str, task_id: str) -> None:
        """Delete a task."""
        request = self._service.tasks().delete(tasklist=tasklist_id, task=task_id)
        request.execute()
