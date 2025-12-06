"""Simple test client for the Google Tasks MCP server."""

import asyncio

from fastmcp import Client  # pyright: ignore[reportMissingImports]


async def test_list_task_lists() -> None:
    client = Client("http://localhost:8000/mcp/")
    async with client:
        result = await client.call_tool("list_task_lists", {})
        print("Task Lists:")
        print(result)


async def test_list_tasks(tasklist_id: str | None = None) -> None:
    client = Client("http://localhost:8000/mcp/")
    async with client:
        params: dict[str, str] = {}
        if tasklist_id:
            params["tasklist_id"] = tasklist_id
        result = await client.call_tool("list_tasks", dict(params=params))
        print("Tasks:")
        print(result)


async def test_create_task(title: str, tasklist_id: str | None = None) -> None:
    client = Client("http://localhost:8000/mcp/")
    async with client:
        params = dict(title=title)
        if tasklist_id:
            params["tasklist_id"] = tasklist_id
        result = await client.call_tool("create_task", dict(params=params))
        print("Created Task:")
        print(result)


async def test_complete_task(task_id: str, tasklist_id: str | None = None) -> None:
    client = Client("http://localhost:8000/mcp/")
    async with client:
        params = dict(task_id=task_id)
        if tasklist_id:
            params["tasklist_id"] = tasklist_id
        result = await client.call_tool("complete_task", dict(params=params))
        print("Completed Task:")
        print(result)


async def test_delete_task(task_id: str, tasklist_id: str | None = None) -> None:
    client = Client("http://localhost:8000/mcp/")
    async with client:
        params = dict(task_id=task_id)
        if tasklist_id:
            params["tasklist_id"] = tasklist_id
        result = await client.call_tool("delete_task", dict(params=params))
        print("Deleted Task:")
        print(result)


async def main() -> None:
    print("=== Testing Google Tasks MCP Server ===\n")

    print("1. Listing task lists...")
    await test_list_task_lists()
    print()

    print("2. Listing tasks from default list...")
    await test_list_tasks()
    print()

    print("3. Creating a test task...")
    await test_create_task("MCP Test Task")
    print()

    print("4. Listing tasks again to see the new task...")
    await test_list_tasks()
    print()


if __name__ == "__main__":
    asyncio.run(main())
