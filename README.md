# GPT → Apple Reminders Bridge

A secure, production-ready system that lets GPT read and write Apple Reminders through a TypeScript proxy server and native iOS app.

## Architecture

```
┌─────────┐      ┌──────────────┐      ┌─────────────┐      ┌──────────────┐
│   GPT   │─────→│ Node Server  │─────→│  APNs/Poll  │─────→│  iOS App     │
│         │      │ (JWT signing)│      │             │      │ (EventKit)   │
└─────────┘      └──────────────┘      └─────────────┘      └──────────────┘
                         │                                           │
                         └───────────── Result POST ─────────────────┘
```

**Security:**

- All commands signed with RS256 JWT (60s TTL)
- Device signature verification before EventKit access
- Audit trail for all operations

**Delivery:**

- APNs silent push (instant)
- Polling fallback (when push unavailable)

## Quick Start

### 1. Server Setup

```bash
cd server
npm install
npm run gen-keys    # Generate RS256 keypair
cp .env.example .env
# Edit .env with your config
npm run dev
```

Server runs on `http://localhost:3000`

### 2. iOS App Setup

1. Open Xcode and create new iOS app project named `GPTReminders`
2. Copy files from `ios-app/GPTReminders/Sources/` to your project
3. Copy `ios-app/GPTReminders/Supporting/Info.plist`
4. Edit [AppDelegate.swift](ios-app/GPTReminders/Sources/AppDelegate.swift):
   - Set `serverURL` to your server
   - Paste `keys/public.pem` content into `publicKeyPEM`
5. Enable capabilities:
   - Push Notifications
   - Background Modes → Remote notifications
6. Build & run on real device
7. Grant Reminders permission

### 3. Connect GPT

Use this OpenAI function schema (or get from `GET /tool/schema`):

```json
{
  "name": "apple_reminders",
  "description": "Read and write Apple Reminders through a trusted bridge app",
  "parameters": {
    "type": "object",
    "properties": {
      "op": {
        "type": "string",
        "enum": [
          "list_lists",
          "list_tasks",
          "create_task",
          "update_task",
          "complete_task",
          "delete_task"
        ]
      },
      "args": { "type": "object" }
    },
    "required": ["op"]
  }
}
```

**Function implementation** (in your GPT integration):

```typescript
async function apple_reminders(op: string, args: any) {
  const response = await fetch('https://your-server.com/tool/tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: getCurrentUserId(), // Your auth system
      op,
      args,
    }),
  });
  return response.json();
}
```

## Operations

### List reminders lists

```typescript
{ op: "list_lists", args: {} }
```

Returns: `[{ id, title }, ...]`

### List tasks

```typescript
{
  op: "list_tasks",
  args: {
    list_id?: string,        // Optional: filter by list
    status?: "needsAction" | "completed"
  }
}
```

Returns: `[{ id, listId, title, notes, status, dueISO, url }, ...]`

### Create task

```typescript
{
  op: "create_task",
  args: {
    title: string,           // Required
    notes?: string,
    list_id?: string,        // Default list if omitted
    due_iso?: string         // ISO8601 date
  }
}
```

Returns: `{ id, title, url, ... }`

### Update task

```typescript
{
  op: "update_task",
  args: {
    task_id: string,         // Required
    title?: string,
    notes?: string,
    due_iso?: string
  }
}
```

### Complete task

```typescript
{
  op: "complete_task",
  args: { task_id: string }
}
```

### Delete task

```typescript
{
  op: "delete_task",
  args: { task_id: string }
}
```

## APNs Setup (Optional)

For instant push delivery instead of polling:

1. **Create APNs Auth Key:**
   - Go to [Apple Developer](https://developer.apple.com/account/resources/authkeys)
   - Create new key with APNs enabled
   - Download `.p8` file (one-time download!)

2. **Configure server** `.env`:

   ```bash
   APNS_KEY_PATH=./keys/AuthKey_XXXXXXXXXX.p8
   APNS_KEY_ID=XXXXXXXXXX
   APNS_TEAM_ID=XXXXXXXXXX
   APNS_BUNDLE_ID=com.example.GPTReminders
   APNS_PRODUCTION=false  # true for production
   ```

3. **Restart server**

Without APNs, app polls `/device/commands/:userId` when foregrounded.

## Project Structure

```
gpt-apple-reminders/
├── server/               # Node.js + Express
│   ├── src/
│   │   ├── index.ts      # Main server & endpoints
│   │   ├── types.ts      # Shared types
│   │   ├── apns.ts       # Push notification helper
│   │   └── crypto-helper.ts  # Key generation
│   ├── package.json
│   └── .env.example
│
└── ios-app/             # Swift iOS app
    └── GPTReminders/
        ├── Sources/
        │   ├── AppDelegate.swift        # APNs & registration
        │   ├── ViewController.swift     # Simple UI
        │   ├── RemindersService.swift   # EventKit wrapper
        │   ├── JWTVerifier.swift        # RS256 verification
        │   └── CommandHandler.swift     # Command processing
        └── Supporting/
            └── Info.plist
```

## API Endpoints

| Method | Path                       | Description                          |
| ------ | -------------------------- | ------------------------------------ |
| POST   | `/device/register`         | Register iOS device with APNs token  |
| POST   | `/device/result`           | Device posts command results         |
| GET    | `/device/commands/:userId` | Poll for pending commands            |
| POST   | `/tool/tasks`              | GPT calls this to execute operations |
| GET    | `/tool/schema`             | Returns OpenAI function schema       |
| GET    | `/health`                  | Health check                         |
| GET    | `/status`                  | Server status & metrics              |

## Security Considerations

### Command Signing

- Server signs every command with RS256 private key
- iOS app verifies with bundled public key
- 60-second TTL prevents replay attacks
- Each command has unique ID for audit trail

### Rate Limiting

Add to your GPT integration:

- Max 10 operations/minute per user
- Debounce rapid-fire tool calls
- Block bulk deletes without confirmation

### User Auth

Current implementation uses device UUID. For production:

- Implement OAuth or magic link
- Map authenticated user → device registration
- Verify user token in `/tool/tasks` endpoint

### Red Team Defense

- Don't expose "delete all" operation
- Require explicit confirmation for bulk changes
- Log all operations with timestamps
- Implement command revocation

## Testing

### Test the server

```bash
# Generate keys
npm run gen-keys

# Start server
npm run dev

# Test health
curl http://localhost:3000/health
```

### Test iOS app

1. Run app on device
2. Tap "Create Test Reminder"
3. Check Apple Reminders app
4. Verify Activity Log shows creation

### Test end-to-end

```bash
# Register fake device (replace with real token from app logs)
curl -X POST http://localhost:3000/device/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-user","apnsToken":"fake-token-for-testing"}'

# Send command (will fail APNs but app can poll)
curl -X POST http://localhost:3000/tool/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user",
    "op": "list_lists",
    "args": {}
  }'
```

## Production Deployment

### Server (Node)

Deploy to any Node.js host (Railway, Render, Fly.io, AWS):

```bash
# Build
npm run build

# Set environment variables
export COMMAND_SIGNING_PRIVATE="<private key>"
export APNS_KEY_PATH=/app/keys/AuthKey_XXX.p8
export APNS_KEY_ID=XXXXXXXXXX
export APNS_TEAM_ID=XXXXXXXXXX
export APNS_PRODUCTION=true
export PORT=3000

# Start
npm start
```

### iOS App

1. Update `serverURL` to production endpoint
2. Use Production APNs certificate
3. Enable proper entitlements
4. Submit to App Store or distribute via TestFlight

### Database

Replace in-memory `Map` storage with:

- Redis for pending commands
- PostgreSQL/MongoDB for audit logs
- Cache results for webhook fanout

## Troubleshooting

**"No registered device"**

- Check iOS app called `/device/register` successfully
- Verify `userId` matches between app and server

**Commands not arriving**

- APNs not configured → app uses polling
- Check server logs for push delivery status
- Foreground app to trigger polling

**JWT signature verification fails**

- Public key in iOS app doesn't match server's private key
- Re-run `npm run gen-keys` and update app

**Permission denied**

- Settings → Privacy & Security → Reminders
- Enable for GPT Reminders app

## Roadmap

- [ ] Background fetch for polling mode
- [ ] Retry logic with exponential backoff
- [ ] Local command queue
- [ ] Conflict resolution for offline changes
- [ ] Push notification preferences (silent/alert)
- [ ] Multi-device support per user
- [ ] Command history UI
- [ ] Bulk operations with confirmation dialog

## License

MIT

---

Built with ❤️ for seamless GPT ↔ Apple Reminders integration.
