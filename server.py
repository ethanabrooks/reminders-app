import logging

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


_MCP = FastMCP(
    name="Google Tasks MCP",
    instructions=(
        "This MCP server exposes Google Tasks as tools. "
        "Use list_task_lists to discover task lists, "
        "then create/update/complete/delete tasks as needed."
    ),
)


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
    tasks = tasks_client.list_tasks(
        ListTasksInput(
            tasklist_id=params.tasklist_id or default_tasklist, status=params.status
        )
    )
    logger.info("Listed %d tasks", len(tasks))
    return tasks


@_MCP.tool
async def create_task(
    params: CreateTaskInput,
    tasks_client: GoogleTasksClient = Depends(get_tasks_client),
    default_tasklist: str = Depends(get_default_tasklist),
) -> Task:
    """Create a new task."""
    task = tasks_client.create_task(
        CreateTaskInput(
            title=params.title,
            notes=params.notes,
            due_iso=params.due_iso,
            tasklist_id=params.tasklist_id or default_tasklist,
        )
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
    task = tasks_client.update_task(
        UpdateTaskInput(
            task_id=params.task_id,
            title=params.title,
            notes=params.notes,
            due_iso=params.due_iso,
            status=params.status,
            tasklist_id=params.tasklist_id or default_tasklist,
        )
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
    task = tasks_client.complete_task(
        CompleteTaskInput(
            task_id=params.task_id,
            tasklist_id=params.tasklist_id or default_tasklist,
        )
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
    tasks_client.delete_task(task_id=params.task_id, tasklist_id=tasklist_id)
    logger.info("Deleted task %s", params.task_id)
    return dict(ok=True)


def main() -> None:
    _MCP.run(transport="http", port=8000)


if __name__ == "__main__":
    main()
