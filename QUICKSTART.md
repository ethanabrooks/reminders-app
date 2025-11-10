# Quick Start (5 minutes)

Get GPT talking to Apple Reminders in 5 minutes.

## 1. Server (2 min)

```bash
cd server
npm install
npm run gen-keys
cp .env.example .env
npm run dev
```

✅ Server running on http://localhost:3000

Copy `keys/public.pem` content for next step.

## 2. iOS App (2 min)

1. Open Xcode → Create new iOS App → Name: `GPTReminders`
2. Copy all `.swift` files from `ios-app/GPTReminders/Sources/` to project
3. Copy `Info.plist` from `ios-app/GPTReminders/Supporting/`
4. Edit `AppDelegate.swift`:
   ```swift
   private let serverURL = URL(string: "http://YOUR-IP:3000")!
   private let publicKeyPEM = """
   -----BEGIN PUBLIC KEY-----
   <PASTE FROM STEP 1>
   -----END PUBLIC KEY-----
   """
   ```
   > Replace `YOUR-IP` with your Mac's local IP (run `ifconfig en0 | grep inet`)

5. Enable capabilities: Push Notifications + Background Modes
6. Build → Run on **real device** (not simulator)
7. Tap "Grant Reminders Access"

✅ App registered with server

## 3. Test (1 min)

### From iOS app:
Tap "Create Test Reminder" → Check Apple Reminders app

### From server:
```bash
# Get device token from app logs, then:
curl -X POST http://localhost:3000/tool/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "<DEVICE-UUID>",
    "op": "list_tasks",
    "args": {"status": "needsAction"}
  }'
```

✅ Should see list of your reminders!

## 4. Connect GPT

Add this function to your OpenAI API call:

```typescript
const tools = [{
  type: "function",
  function: {
    name: "apple_reminders",
    description: "Read/write Apple Reminders",
    parameters: {
      type: "object",
      properties: {
        op: {
          type: "string",
          enum: ["list_lists", "list_tasks", "create_task", "update_task", "complete_task", "delete_task"]
        },
        args: { type: "object" }
      },
      required: ["op"]
    }
  }
}];
```

Implement handler:
```typescript
async function apple_reminders(op, args) {
  const res = await fetch('http://localhost:3000/tool/tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: getCurrentUser(), op, args })
  });
  return res.json();
}
```

## Done! 🎉

Try: "Add a reminder to buy milk tomorrow at 9am"

---

## Troubleshooting

**"No registered device"**
- Check iOS app logs for successful registration
- Verify userId matches between app and API call

**iOS app not receiving commands**
- APNs not configured → App uses polling
- Foreground the app to trigger poll
- Check server logs for push delivery

**Can't connect from iOS to server**
- Use your Mac's IP, not `localhost`
- Both devices on same WiFi
- Check firewall isn't blocking port 3000

## Next Steps

- Deploy server to production (Railway, Render)
- Set up APNs for instant delivery
- Read [INTEGRATION.md](INTEGRATION.md) for production setup
