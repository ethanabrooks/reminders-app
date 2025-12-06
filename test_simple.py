"""Simple test to verify FastMCP dependency injection works."""

import asyncio

from fastmcp import Client  # pyright: ignore[reportMissingImports]


async def call_tool(name: str) -> None:
    client = Client("http://localhost:8000/mcp/")
    async with client:
        result = await client.call_tool("greet", {"name": name})
        print(result)


if __name__ == "__main__":
    asyncio.run(call_tool("Ford"))

