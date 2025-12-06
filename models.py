from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


TaskStatus = Literal["needsAction", "completed"]


class TaskList(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str


class Task(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str | None = None
    notes: str | None = None
    status: TaskStatus
    dueISO: str | None = Field(default=None, alias="due_iso")
    completedISO: str | None = Field(default=None, alias="completed_iso")
    listId: str | None = Field(default=None, alias="list_id")
    url: str | None = None


class ListTasksInput(BaseModel):
    tasklist_id: str | None = None
    status: TaskStatus | None = None


class CreateTaskInput(BaseModel):
    title: str
    notes: str | None = None
    tasklist_id: str | None = None
    due_iso: str | None = None


class UpdateTaskInput(BaseModel):
    task_id: str
    title: str | None = None
    notes: str | None = None
    due_iso: str | None = None
    status: TaskStatus | None = None
    tasklist_id: str | None = None


class CompleteTaskInput(BaseModel):
    task_id: str
    tasklist_id: str | None = None


class DeleteTaskInput(BaseModel):
    task_id: str
    tasklist_id: str | None = None


def normalize_task(payload: dict[str, object], tasklist_id: str | None) -> Task:
    task_id = str(payload.get("id", "unknown"))
    title = payload.get("title")
    notes = payload.get("notes")
    status_raw = payload.get("status", "needsAction")
    assert status_raw in ("needsAction", "completed")
    status: TaskStatus = "completed" if status_raw == "completed" else "needsAction"

    due_raw = payload.get("due")
    completed_raw = payload.get("completed")

    return Task(
        id=task_id,
        title=str(title) if title is not None else None,
        notes=str(notes) if notes is not None else None,
        status=status,
        due_iso=str(due_raw) if due_raw is not None else None,
        completed_iso=str(completed_raw) if completed_raw is not None else None,
        list_id=tasklist_id,
        url=str(payload["selfLink"]) if "selfLink" in payload else None,
    )


def now_iso() -> str:
    return datetime.now().astimezone().isoformat()

