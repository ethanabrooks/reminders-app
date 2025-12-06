"""Simple test server matching the FastMCP tutorial example."""

from pydantic import BaseModel

from fastmcp import FastMCP  # pyright: ignore[reportMissingImports]
from fastmcp.dependencies import Depends  # pyright: ignore[reportMissingImports]

mcp = FastMCP(name="Custom Deps Demo")


# Pydantic model for input (like ListTasksInput)
class GreetInput(BaseModel):
    name: str
    greeting: str | None = None


# Settings-like dependency
class Settings:
    def __init__(self) -> None:
        self.api_url = "https://api.example.com"
        self.timeout = 30


def get_settings() -> Settings:
    return Settings()


# Simple function dependency
def get_config() -> dict:
    return {"api_url": "https://api.example.com", "timeout": 30}


# Async function dependency
async def get_user_id() -> int:
    return 42


# Dependency that depends on another dependency (like get_tasks_client)
def get_client(config: dict = Depends(get_config)) -> dict:
    return {"client_config": config, "client_id": "test-client"}


# Complex dependency that depends on Settings (like get_tasks_client)
class ComplexClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.client_id = "complex-client"

    def do_something(self) -> str:
        return f"Client {self.client_id} using {self.settings.api_url}"


def get_complex_client(settings: Settings = Depends(get_settings)) -> ComplexClient:
    return ComplexClient(settings)


@mcp.tool
async def greet(
    params: GreetInput,
    config: dict = Depends(get_config),
    user_id: int = Depends(get_user_id),
    client: dict = Depends(get_client),
    complex_client: ComplexClient = Depends(get_complex_client),
) -> str:
    greeting = params.greeting or "Hello"
    result = complex_client.do_something()
    return f"{greeting}, {params.name}! User {user_id} fetching from {config['api_url']} via {client['client_id']}. {result}"


def main() -> None:
    mcp.run(transport="http", port=8000)


if __name__ == "__main__":
    main()
