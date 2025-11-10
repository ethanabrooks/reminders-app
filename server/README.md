# Tasks Proxy Server

TypeScript/Node.js server that acts as a bridge between GPT and the iOS Reminders app.

## Features

- 🔐 RS256 JWT command signing
- 📱 APNs silent push notifications
- 🔄 Polling fallback
- 📊 Command audit trail
- 🛡️ Short-lived tokens (60s TTL)

## Setup

```bash
npm install
npm run gen-keys    # Generate RS256 keypair
cp .env.example .env
```

Edit `.env`:

```bash
PORT=3000
COMMAND_SIGNING_PRIVATE_PATH=./keys/private.pem

# Optional APNs (for push instead of polling)
APNS_KEY_PATH=./keys/AuthKey_XXXXXXXXXX.p8
APNS_KEY_ID=XXXXXXXXXX
APNS_TEAM_ID=XXXXXXXXXX
APNS_BUNDLE_ID=com.example.GPTReminders
APNS_PRODUCTION=false
```

## Run

```bash
# Development
npm run dev

# Production
npm run build
npm start
```

## Generated Keys

After running `npm run gen-keys`:

- `keys/private.pem` - Server uses this to sign commands (keep secret!)
- `keys/public.pem` - iOS app uses this to verify signatures (bundle in app)

## Endpoints

### Device Management

**POST /device/register**
```json
{
  "userId": "user-123",
  "apnsToken": "device-apns-token-hex"
}
```

**GET /device/commands/:userId**

Returns pending commands (polling mode).

**POST /device/result**
```json
{
  "commandId": "cmd_xxx",
  "success": true,
  "result": { ... }
}
```

### GPT Tool

**POST /tool/tasks**
```json
{
  "userId": "user-123",
  "op": "create_task",
  "args": {
    "title": "Call dentist",
    "due_iso": "2025-11-10T14:00:00Z"
  }
}
```

Response:
```json
{
  "ok": true,
  "commandId": "cmd_1699564234_abc123",
  "deliveryMethod": "push"
}
```

**GET /tool/schema**

Returns OpenAI function schema.

### Status

**GET /health**
```json
{ "ok": true, "devices": 3, "pendingCommands": 1 }
```

**GET /status**
```json
{
  "devices": [
    { "userId": "user-123", "registeredAt": "2025-11-09T..." }
  ],
  "pendingCommands": 1,
  "completedResults": 42
}
```

## APNs Setup

1. Create Auth Key at [Apple Developer](https://developer.apple.com/account/resources/authkeys)
2. Download `.p8` file to `keys/`
3. Set env vars with Key ID and Team ID
4. Restart server

Without APNs, iOS app will poll `/device/commands` instead.

## Security

- Private key should be kept secret (use env vars in production)
- JWTs expire after 60 seconds
- Each command has unique ID for audit
- Consider adding user auth middleware to `/tool/tasks`

## Production

Replace in-memory storage:

```typescript
// Instead of Map:
const devices = new Map<string, DeviceInfo>();

// Use:
- Redis for pending commands
- PostgreSQL for device registry
- Database for command audit log
```

Add rate limiting:
```bash
npm install express-rate-limit
```

## Deployment

Works on any Node.js platform:
- Railway
- Render
- Fly.io
- AWS Lambda (with adapter)
- Google Cloud Run
- Heroku

Set `COMMAND_SIGNING_PRIVATE` env var to the PEM content (use `\\n` for newlines).
