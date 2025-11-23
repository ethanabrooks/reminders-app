# Tasks Proxy Server

Node.js server acting as the secure gateway between GPT and the iOS device.

## Command Flow

```mermaid
sequenceDiagram
    participant GPT
    participant Server
    participant DB as In-Memory DB
    participant APNs
    participant iOS

    GPT->>Server: POST /tool/tasks (op: create_task)
    Server->>Server: Sign Payload (RS256)
    Server->>DB: Store Pending Command
    Server->>APNs: Send Silent Push

    alt Push Success
        APNs-->>iOS: Wake App
    else Push Fail (Polling Fallback)
        iOS->>Server: GET /device/commands
        Server->>DB: Fetch Pending
        DB-->>Server: Return Commands
        Server-->>iOS: Return Commands
    end

    par Async Result
        iOS->>iOS: Execute Task
        iOS->>Server: POST /device/result
        Server->>DB: Store Result
    and GPT Response
        Server-->>GPT: 200 OK (Command Dispatched)
    end

    opt Check Result
        GPT->>Server: GET /tool/result/:id
        Server->>DB: Fetch Result
        DB-->>Server: Return Result
        Server-->>GPT: Return Result
    end
```

## Component Architecture

```mermaid
classDiagram
    class ExpressApp {
        +POST /device/register
        +POST /device/result
        +POST /tool/tasks
    }
    class APNsService {
        +initialize()
        +sendSilentPush()
    }
    class CryptoHelper {
        -privateKey
        +signCommand(payload)
    }
    class Store {
        +devices: Map
        +pendingCommands: Map
        +results: Map
    }

    ExpressApp --> APNsService : Uses
    ExpressApp --> CryptoHelper : Signs JWTs
    ExpressApp --> Store : Persists State
```

## State Machine (Command Lifecycle)

```mermaid
stateDiagram-v2
    [*] --> Created
    Created --> Signed : Add JWT Signature
    Signed --> Dispatched : Sent to APNs

    Dispatched --> Pending : APNs Delivery Unknown
    Dispatched --> Failed : APNs Error

    Pending --> Executing : Device Received
    Executing --> Completed : Device POSTs Success
    Executing --> Error : Device POSTs Failure
```

## Setup

1.  **Install**: `npm install`
2.  **Keys**: `npm run gen-keys`
3.  **Env**: Copy `env.example` to `.env` and configure APNs keys.
4.  **Run**: `npm run dev`
