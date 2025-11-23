# 🤖 GPT-5/GPT-4 Integration for Apple Reminders

You now have a fully functional bridge between GPT models and Apple Reminders! Here's everything you need to know.

## ✅ What's Already Set Up

1. **Server** - Running on `http://localhost:3000` with all the integration endpoints
2. **iOS App** - Built and running in the simulator, ready to execute commands
3. **Security** - JWT signing with RSA keys for secure command verification
4. **Integration Code** - Complete TypeScript example ready to use

## 🚀 Quick Start (3 Steps)

### 1. Get Your Device ID

Once your iOS app registers with the server, get the device ID:

```bash
curl http://localhost:3000/status
```

Copy the `userId` from the response.

### 2. Test Without GPT First

Run the test script to verify everything works:

```bash
./test-integration.sh
```

This will:

- Check server connectivity
- Find your registered device
- Send a test command to list reminders
- Wait for the response

### 3. Connect to GPT

Install OpenAI SDK and run the example:

```bash
npm install openai
export OPENAI_API_KEY="sk-your-key-here"
export USER_ID="your-device-id-from-step-1"

npx tsx gpt-integration-example.ts "What's on my todo list?"
```

## 📚 Files Created for You

| File                            | Purpose                                     |
| ------------------------------- | ------------------------------------------- |
| `gpt-integration-example.ts`    | Complete working example with GPT-4o        |
| `GPT_INTEGRATION_QUICKSTART.md` | Step-by-step setup guide                    |
| `test-integration.sh`           | Test script (no GPT needed)                 |
| `INTEGRATION.md`                | Detailed integration docs (already existed) |

## 🎯 What You Can Do

### Available Operations

```typescript
// List all reminder lists
{ op: "list_lists", args: {} }

// Get incomplete tasks
{ op: "list_tasks", args: { status: "needsAction" } }

// Create a reminder
{
  op: "create_task",
  args: {
    title: "Buy milk",
    notes: "Get 2% milk",
    due_iso: "2025-11-10T10:00:00Z"
  }
}

// Mark task complete
{ op: "complete_task", args: { task_id: "task-uuid" } }

// Update task
{
  op: "update_task",
  args: {
    task_id: "task-uuid",
    title: "Buy almond milk"
  }
}

// Delete task
{ op: "delete_task", args: { task_id: "task-uuid" } }
```

### Example Conversations with GPT

**User:** "Add a reminder to call the dentist tomorrow at 2pm"

**GPT:** _[calls apple_reminders function with create_task]_

**Response:** "I've added a reminder to call the dentist tomorrow at 2 PM."

---

**User:** "What do I need to do today?"

**GPT:** _[calls apple_reminders function with list_tasks]_

**Response:** "You have 3 tasks for today:

1. Call dentist (2 PM)
2. Buy groceries
3. Finish project proposal"

---

**User:** "I finished the groceries, mark it done"

**GPT:** _[calls apple_reminders function with complete_task]_

**Response:** "Great! I've marked 'Buy groceries' as complete."

## 🔧 API Endpoints

Your server exposes these endpoints:

### For GPT/Your App:

- `POST /tool/tasks` - Send commands to iOS device
- `GET /tool/result/:commandId` - Poll for command results
- `GET /tool/schema` - Get OpenAI function schema

### For iOS App:

- `POST /device/register` - Register device with APNs token
- `POST /device/result` - Submit command execution results
- `GET /device/commands/:userId` - Poll for pending commands

### Status/Health:

- `GET /health` - Server health check
- `GET /status` - See registered devices and stats

## 🎨 Integration Patterns

### Pattern 1: Simple Function Call (Async)

```typescript
// Send command, don't wait for result
const response = await fetch('http://localhost:3000/tool/tasks', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: 'device-uuid',
    op: 'create_task',
    args: { title: 'Buy milk' },
  }),
});

// Returns immediately with commandId
const { commandId } = await response.json();
```

### Pattern 2: Synchronous Result (Poll)

```typescript
// Send command
const { commandId } = await sendCommand('create_task', {...});

// Wait for result
const result = await pollForResult(commandId);

// Return to GPT
return result;
```

### Pattern 3: Streaming (Advanced)

```typescript
// For real-time updates with Server-Sent Events
// See INTEGRATION.md for details
```

## 🌐 Production Deployment

When you're ready to go live:

### 1. Deploy Server

```bash
# Example: Deploy to Railway
railway init
railway up

# Or Render, Fly.io, etc.
```

### 2. Update iOS App

Change the server URL in [AppDelegate.swift:10](ios-app/GPTReminders/Sources/AppDelegate.swift#L10):

```swift
private let serverURL = URL(string: "https://your-production-server.com")!
```

### 3. Set Up APNs (Optional but Recommended)

- Create APNs Auth Key in Apple Developer portal
- Update `.env` with APNs credentials
- Restart server
- Commands will be delivered instantly via push notifications instead of polling

### 4. Add Authentication

Protect your endpoints:

```typescript
// Middleware example
app.post('/tool/tasks', authenticateUser, async (req, res) => {
  const { userId } = req.body;

  // Verify user owns this device
  if (req.user.id !== userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  // ... rest of handler
});
```

## 🐛 Troubleshooting

### Device Not Registering

**Problem:** `curl http://localhost:3000/status` shows no devices

**Solutions:**

- Make sure iOS app is running and in foreground
- Check that Reminders access was granted
- For simulator, the app might need to use `localhost:3000` instead of your IP
- Restart the app

### Commands Timing Out

**Problem:** `pollForResult()` times out

**Solutions:**

- iOS app must be in foreground (simulator limitation)
- Check app has Reminders permission
- Increase polling timeout
- In production, use APNs for instant delivery

### GPT Not Calling Function

**Problem:** GPT responds with text instead of calling the function

**Solutions:**

- Make prompt more explicit: "Add a reminder..." not "Can you add..."
- Check function description is clear
- Try `tool_choice: 'required'` during testing
- Ensure userId is valid

## 💡 Use Case Ideas

### Personal Assistant

- Natural language reminders
- Smart scheduling
- Task prioritization

### Email/Calendar Integration

- Auto-create reminders from emails
- Extract action items from meeting notes
- Smart follow-up reminders

### Smart Home

- Location-based reminders
- "When I leave home, remind me..."
- Shopping list management

### Team Productivity

- Shared task management
- Project milestone tracking
- Deadline reminders

## 📖 Additional Resources

- [INTEGRATION.md](INTEGRATION.md) - Detailed integration guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [QUICKSTART.md](QUICKSTART.md) - Initial setup guide
- [OpenAI Function Calling](https://platform.openai.com/docs/guides/function-calling) - Official docs

## 🎉 You're Ready!

Your Apple Reminders bridge is fully functional and ready to connect to GPT-5, GPT-4, GPT-4o, or any other LLM that supports function calling.

Start with the test script, then move on to the GPT example, and you'll be managing reminders through natural language in minutes!

---

**Questions or issues?** Check the troubleshooting section or open an issue.
