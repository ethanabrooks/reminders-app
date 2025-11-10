# GPT Reminders - iOS App

Swift app that bridges GPT to Apple Reminders via EventKit.

## Features

- ✅ Full EventKit integration (create, read, update, delete reminders)
- 🔐 JWT signature verification for secure command execution
- 📱 APNs silent push notifications for instant command delivery
- 🔄 Polling fallback when push isn't available
- 🔗 Deep links (`gptreminders://task/<id>`)

## Setup

### 1. Open in Xcode

Since this is a manual Swift project structure, you'll need to create an Xcode project:

1. Open Xcode
2. Create new iOS App project
3. Name it `GPTReminders`
4. Bundle Identifier: `com.example.GPTReminders` (or your own)
5. Copy all files from `Sources/` to the project
6. Copy `Info.plist` to project

Or use the provided structure and import as needed.

### 2. Configure Server Connection

Edit [AppDelegate.swift](GPTReminders/Sources/AppDelegate.swift):

```swift
private let serverURL = URL(string: "https://your-server.com")!
private let publicKeyPEM = """
-----BEGIN PUBLIC KEY-----
<PASTE YOUR PUBLIC KEY FROM SERVER>
-----END PUBLIC KEY-----
"""
```

Get the public key by running on your server:
```bash
cat keys/public.pem
```

### 3. Enable Capabilities

In Xcode project settings → Signing & Capabilities:

- ✅ Push Notifications
- ✅ Background Modes → Remote notifications

### 4. Configure APNs (Optional)

If you want push notifications instead of polling:

1. Create APNs Auth Key in Apple Developer portal
2. Download `.p8` file
3. Note the Key ID and Team ID
4. Configure these in your server's `.env`

Without APNs, the app will poll `/device/commands` every time it comes to foreground.

### 5. Build & Run

1. Select a real device (push notifications don't work in Simulator)
2. Build and run
3. Grant Reminders permission when prompted
4. App will register with your server

## Architecture

### Command Flow

```
GPT → Server → APNs → iOS App → EventKit → Reminders
                                     ↓
GPT ← Server ← HTTP POST ← iOS App ←┘
```

### Security

All commands are JWT-signed (RS256) with:
- Short TTL (60s)
- Signature verification before execution
- Command ID for audit trail

### Files

- `RemindersService.swift` - EventKit CRUD operations
- `JWTVerifier.swift` - RS256 signature verification
- `CommandHandler.swift` - Command processing & result reporting
- `AppDelegate.swift` - APNs handling & device registration
- `ViewController.swift` - Simple UI with test button

## Deep Links

The app registers `gptreminders://` scheme. GPT can return tappable links:

```
gptreminders://task/<reminder-id>
```

Tap to open the specific reminder (currently just logs, extend as needed).

## Testing

1. Tap "Create Test Reminder" in the app
2. Check Apple Reminders app - should see new reminder
3. Use server's `/tool/tasks` endpoint to send commands
4. Check Activity Log in app for command execution

## Troubleshooting

**"No registered device" error from server:**
- Check app successfully called `/device/register`
- Check Activity Log for registration confirmation

**Commands not arriving:**
- APNs not configured → App uses polling mode
- Check server logs for push delivery status
- Foreground the app to trigger polling

**Permission denied:**
- Go to Settings → Privacy & Security → Reminders
- Enable access for GPT Reminders app

## Production Checklist

- [ ] Replace hardcoded `publicKeyPEM` with bundled asset
- [ ] Implement proper user authentication (not just device ID)
- [ ] Add UI confirmation for destructive operations
- [ ] Implement proper deep link navigation
- [ ] Add background fetch for polling mode
- [ ] Store command history locally
- [ ] Add retry logic for network failures
- [ ] Implement rate limiting on device side
