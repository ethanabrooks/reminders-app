"""Simple test server matching the FastMCP tutorial example."""

from contextlib import asynccontextmanager

from fastmcp import FastMCP  # pyright: ignore[reportMissingImports]
from fastmcp.dependencies import Depends  # pyright: ignore[reportMissingImports]

mcp = FastMCP(name="Custom Deps Demo")


# Simple function dependency
def get_config() -> dict:
    return {"api_url": "https://api.example.com", "timeout": 30}


# Async function dependency
async def get_user_id() -> int:
    return 42


@mcp.tool
async def greet(
    name: str,
    config: dict = Depends(get_config),
    user_id: int = Depends(get_user_id),
) -> str:
    return f"User {user_id} fetching '{name}' from {config['api_url']}"


def main() -> None:
    mcp.run(transport="http", port=8000)


if __name__ == "__main__":
    main()

