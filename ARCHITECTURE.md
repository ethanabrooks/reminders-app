# Architecture (Google Tasks MCP)

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GPT Assistant                               │
│ (OpenAI API, Custom GPT, or any MCP-capable client)                 │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            │ MCP tool calls (SSE)
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│                    FastMCP Server (Python)                          │
│  - Validates input with Pydantic                                    │
│  - Uses Google Tasks API via OAuth token                            │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            │ HTTPS (Google APIs)
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│                         Google Tasks                                │
│  - Task lists and tasks stored in user's Google account             │
└─────────────────────────────────────────────────────────────────────┘
```

## Tooling Surface
- `list_task_lists`
- `list_tasks` (optional status filter)
- `create_task`
- `update_task`
- `complete_task`
- `delete_task`

## Data Shapes
- Task: `id`, `title`, `notes`, `status` (`needsAction` | `completed`), `dueISO`, `completedISO`, `listId`, `url`
- TaskList: `id`, `title`

## Auth & Config
- OAuth installed-app credentials (`credentials.json`) + stored token (`token.json`)
- Scope: `https://www.googleapis.com/auth/tasks`
- Default task list: `@default` (override via `DEFAULT_TASKLIST_ID`)

## Lifecycle
1. Client calls an MCP tool.
2. FastMCP validates input (Pydantic).
3. Google Tasks API call executes the operation.
4. Response is normalized and returned to the client.

## Notes
- This replaces the previous Apple Reminders + iOS/APNs architecture. Legacy `server/` and `ios-app/` directories are no longer used.

**Payload:**

```json
{
  "id": "cmd_1699564234_abc123",
  "kind": "create_task",
  "payload": {
    "title": "Buy milk",
    "due_iso": "2025-11-10T09:00:00Z"
  },
  "iat": 1699564234,
  "exp": 1699564294
}
```

**Signature:**

```
RS256(
  base64(header) + "." + base64(payload),
  PRIVATE_KEY
)
```

### Verification Flow

```swift
// iOS app verification
func verify(token: String) throws -> [String: Any] {
    // 1. Split JWT
    let [header, payload, signature] = token.split(".")

    // 2. Verify signature with bundled public key
    let valid = SecKeyVerifySignature(
        publicKey,
        .rsaSignatureMessagePKCS1v15SHA256,
        data: "\(header).\(payload)",
        signature: signature
    )
    guard valid else { throw .signatureInvalid }

    // 3. Decode payload
    let claims = decodeJSON(base64Decode(payload))

    // 4. Check expiration
    if claims["exp"] < now() {
        throw .expired
    }

    return claims
}
```

### Trust Model

```
┌──────────────────┐     Private Key      ┌──────────────────┐
│  Server          │───────signs──────────→│  Command         │
│  (Trusted)       │                       │  (JWT)           │
└──────────────────┘                       └──────────────────┘
                                                     │
                                                     │ Delivered
                                                     │ (APNs/Poll)
                                                     ▼
┌──────────────────┐     Public Key       ┌──────────────────┐
│  iOS App         │──────verifies────────→│  Execute on      │
│  (Bundled Key)   │                       │  EventKit        │
└──────────────────┘                       └──────────────────┘
```

**Key Properties:**

- Server cannot be impersonated (only holder of private key can sign)
- Commands cannot be forged (signature verification fails)
- Commands cannot be replayed (60s expiration)
- Each command is unique (command ID)

## Component Breakdown

### Server Components

```typescript
// index.ts - Main HTTP server
├── Device Management
│   ├── POST /device/register     - Register APNs token
│   ├── GET  /device/commands/:id - Polling endpoint
│   └── POST /device/result       - Result webhook
│
├── Tool API
│   ├── POST /tool/tasks          - GPT calls this
│   └── GET  /tool/schema         - OpenAI function schema
│
└── Status
    ├── GET /health               - Health check
    └── GET /status               - Metrics

// apns.ts - Push notification handler
├── initializeAPNs()              - Setup APNs provider
├── sendSilentPush()              - Deliver command via push
└── shutdownAPNs()                - Cleanup

// crypto-helper.ts - Key generation
└── generateKeypair()             - Create RS256 keys

// types.ts - Shared TypeScript types
├── CommandEnvelope
├── NormalizedTask
└── Command payloads
```

### iOS Components

```swift
// AppDelegate.swift - App lifecycle
├── application:didFinishLaunchingWithOptions:
│   └── Initialize CommandHandler
├── didRegisterForRemoteNotifications:
│   └── POST token to /device/register
└── didReceiveRemoteNotification:
    └── Process command from APNs

// RemindersService.swift - EventKit wrapper
├── ensureAccess()                - Request permission
├── reminderCalendars()           - List all lists
├── createReminder()              - Create task
├── listTasks()                   - Read tasks
├── completeTask()                - Mark done
├── updateTask()                  - Modify task
├── deleteTask()                  - Remove task
└── toDTO()                       - Convert to JSON

// JWTVerifier.swift - Signature verification
├── init(pemString:)              - Load public key
└── verify(token:)                - Verify & decode JWT

// CommandHandler.swift - Command processing
├── processCommand()              - Main entry point
├── handleListLists()             - Execute list_lists
├── handleListTasks()             - Execute list_tasks
├── handleCreateTask()            - Execute create_task
├── handleUpdateTask()            - Execute update_task
├── handleCompleteTask()          - Execute complete_task
├── handleDeleteTask()            - Execute delete_task
└── sendResult()                  - POST to /device/result

// ViewController.swift - UI
├── statusLabel                   - Connection status
├── actionButton                  - Grant permission
└── testButton                    - Create test reminder
```

## State Management

### Server State (In-Memory)

```typescript
// Device registry
Map<userId, DeviceInfo> {
  "user-123": {
    userId: "user-123",
    apnsToken: "abc123...",
    registeredAt: 1699564234
  }
}

// Pending commands (for polling)
Map<commandId, { userId, command }> {
  "cmd_123": {
    userId: "user-123",
    command: "eyJhbG..." // JWT
  }
}

// Command results
Map<commandId, CommandResult> {
  "cmd_123": {
    commandId: "cmd_123",
    success: true,
    result: { ... },
    timestamp: 1699564240
  }
}
```

### iOS App State

```swift
// RemindersService
- EKEventStore (EventKit connection)
- Permission status

// CommandHandler
- JWTVerifier (public key loaded)
- Server URL

// AppDelegate
- Device token
- CommandHandler instance
```

## Scaling Considerations

### Current Limits

- **In-memory storage**: Lost on server restart
- **No database**: Can't query command history
- **Single server**: No horizontal scaling
- **No queueing**: Commands processed immediately

### Production Architecture

```
┌──────────┐
│   GPT    │
└────┬─────┘
     │
┌────▼─────────────────────────────────────┐
│  Load Balancer (nginx, cloudflare)       │
└────┬─────────────────────────────────────┘
     │
     ├──────────┬──────────┬──────────┐
     ▼          ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ Node 1 │ │ Node 2 │ │ Node 3 │ │ Node N │
└────┬───┘ └────┬───┘ └────┬───┘ └────┬───┘
     │          │          │          │
     └──────────┴──────────┴──────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
    ┌────────┐  ┌────────┐  ┌──────────┐
    │ Redis  │  │Postgres│  │  APNs    │
    │(queue) │  │  (DB)  │  │(delivery)│
    └────────┘  └────────┘  └──────────┘
```

**Changes needed:**

1. Redis for pending commands & results
2. PostgreSQL for device registry & audit log
3. Bull/BullMQ for command queue
4. Stateless server instances
5. Session affinity not required

## Performance Characteristics

### Latency Budget

```
User message → GPT → Server → iOS → Result
     ~1s        ~2s     50ms    1-5s    ~1s

Total: 5-10s for round-trip
```

**Breakdown:**

- GPT inference: 1-3s (depends on model)
- Server processing: <50ms
- APNs delivery: 1-5s (avg ~2s)
- EventKit operation: 100-500ms
- Result upload: 100-300ms

### Optimization Strategies

1. **Batch operations:**
   Combine multiple creates into one command

2. **Optimistic response:**
   Don't wait for result, return immediately

3. **Background sync:**
   Poll for updates async

4. **Local cache:**
   Cache lists on device

## Error Handling

### Error Categories

```typescript
// Network errors
- Server unreachable
- APNs delivery failed
- HTTP timeout

// Security errors
- JWT signature invalid
- JWT expired
- Unknown command

// Permission errors
- Reminders access denied
- Restricted access

// Business logic errors
- Task not found
- Invalid list ID
- Missing required field
```

### Retry Strategy

```typescript
// Exponential backoff
async function retryWithBackoff(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await sleep(Math.pow(2, i) * 1000); // 1s, 2s, 4s
    }
  }
}
```

## Deep Links

### URL Scheme Registration

**Info.plist:**

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>gptreminders</string>
    </array>
  </dict>
</array>
```

### URL Format

```
gptreminders://task/<reminder-id>
gptreminders://list/<list-id>
```

### Handler

```swift
func application(_ app: UIApplication, open url: URL) -> Bool {
  // gptreminders://task/ABC-123
  if url.host == "task" {
    let taskId = url.pathComponents[1]
    navigateToTask(taskId)
    return true
  }
  return false
}
```

## Testing Strategy

### Unit Tests

```typescript
// Server
- JWT signing/verification
- Command validation
- Result storage

// iOS
- RemindersService CRUD
- JWTVerifier signature checks
- CommandHandler routing
```

### Integration Tests

```typescript
// End-to-end
1. Register device
2. Send create_task command
3. Verify reminder created in EventKit
4. Verify result posted to server
```

### Manual Testing

```bash
# Server health
curl http://localhost:3000/health

# Create reminder (replace userId)
curl -X POST http://localhost:3000/tool/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user",
    "op": "create_task",
    "args": {"title": "Test task"}
  }'

# Check result
curl http://localhost:3000/tool/result/<commandId>
```

---

This architecture provides:

- ✅ Security via JWT signing
- ✅ Reliability via dual delivery (push + poll)
- ✅ Scalability via stateless design
- ✅ Observability via audit logs
- ✅ Extensibility via typed commands
