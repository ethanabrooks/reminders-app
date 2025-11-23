# Scripts & Tests

Utility scripts for testing and end-to-end verification.

## Integration Test Flow

`test-integration.sh` validates the full loop without GPT.

```mermaid
sequenceDiagram
    participant Script
    participant Server
    participant iOS as iOS Simulator

    Note over Script: 1. Health Check
    Script->>Server: GET /health
    Server-->>Script: 200 OK

    Note over Script: 2. Device Discovery
    Script->>Server: GET /status
    Server-->>Script: Returns registered deviceId

    Note over Script: 3. Dispatch Command
    Script->>Server: POST /tool/tasks (op: list_tasks)
    Server->>Server: Queue Command (Polling Mode)

    Note over Script: 4. Polling Simulation
    loop Every 2s
        iOS->>Server: GET /device/commands
        Server-->>iOS: Returns Pending Command
        iOS->>iOS: Execute
        iOS->>Server: POST /device/result
    end

    Note over Script: 5. Verification
    loop Until Result
        Script->>Server: GET /tool/result/:id
        alt Result Found
            Server-->>Script: Success JSON
        else Pending
            Server-->>Script: 404 Not Found
        end
    end
```

## Usage

```bash
# Run full integration test (requires running server + simulator)
./test-integration.sh
```
