import logging
from datetime import datetime

from fastmcp import FastMCP
from fastmcp.dependencies import Depends

from dependencies import get_default_tasklist, get_tasks_client
from google_tasks_client import GoogleTasksClient
from models import (
    CompleteTaskInput,
    CreateTaskInput,
    DeleteTaskInput,
    ListTasksInput,
    Task,
    TaskList,
    UpdateTaskInput,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger(__name__)


_MCP = FastMCP[None](
    name="Google Tasks MCP",
    instructions=(
        "This MCP server exposes Google Tasks as tools. "
        "Use list_task_lists to discover task lists, "
        "then create/update/complete/delete tasks as needed."
    ),
)


def _now_iso() -> str:
    return datetime.now().astimezone().isoformat()


@_MCP.tool
async def list_task_lists(
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
) -> list[TaskList]:
    """List available Google task lists."""
    task_lists = tasks_client.list_task_lists()
    logger.info("Listed %d task lists", len(task_lists))
    return task_lists


@_MCP.tool
async def list_tasks(
    params: ListTasksInput,
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
    default_tasklist: str = Depends(get_default_tasklist),
) -> list[Task]:
    """List tasks in a task list, optionally filtered by status."""
    tasklist_id = params.tasklist_id or default_tasklist
    all_tasks = tasks_client.list_tasks(tasklist_id)

    if params.status is None:
        filtered = all_tasks
    else:
        filtered = [t for t in all_tasks if t.status == params.status]

    logger.info("Listed %d tasks (filtered from %d)", len(filtered), len(all_tasks))
    return filtered


@_MCP.tool
async def create_task(
    params: CreateTaskInput,
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
    default_tasklist: str = Depends(get_default_tasklist),
) -> Task:
    """Create a new task."""
    tasklist_id = params.tasklist_id or default_tasklist
    task = tasks_client.insert_task(
        tasklist_id=tasklist_id,
        title=params.title,
        notes=params.notes,
        due=params.due_iso,
    )
    logger.info("Created task %s", task.id)
    return task


@_MCP.tool
async def update_task(
    params: UpdateTaskInput,
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
    default_tasklist: str = Depends(get_default_tasklist),
) -> Task:
    """Update an existing task."""
    tasklist_id = params.tasklist_id or default_tasklist
    task = tasks_client.patch_task(
        tasklist_id=tasklist_id,
        task_id=params.task_id,
        title=params.title,
        notes=params.notes,
        due=params.due_iso,
        status=params.status,
    )
    logger.info("Updated task %s", task.id)
    return task


@_MCP.tool
async def complete_task(
    params: CompleteTaskInput,
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
    default_tasklist: str = Depends(get_default_tasklist),
) -> Task:
    """Mark a task as completed."""
    tasklist_id = params.tasklist_id or default_tasklist
    task = tasks_client.patch_task(
        tasklist_id=tasklist_id,
        task_id=params.task_id,
        status="completed",
        completed=_now_iso(),
    )
    logger.info("Completed task %s", task.id)
    return task


@_MCP.tool
async def delete_task(
    params: DeleteTaskInput,
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
    default_tasklist: str = Depends(get_default_tasklist),
) -> dict[str, bool]:
    """Delete a task."""
    tasklist_id = params.tasklist_id or default_tasklist
    tasks_client.delete_task(tasklist_id=tasklist_id, task_id=params.task_id)
    logger.info("Deleted task %s", params.task_id)
    return dict(ok=True)


def main() -> None:
    _MCP.run(transport="http", port=8000)


if __name__ == "__main__":
    main()
