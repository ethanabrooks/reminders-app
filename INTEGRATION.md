# GPT Integration Guide

How to integrate this Apple Reminders bridge with your GPT/LLM application.

## OpenAI Function Calling

### 1. Register the Function

Add this to your OpenAI API call:

```typescript
const completion = await openai.chat.completions.create({
  model: "gpt-4",
  messages: [...],
  tools: [
    {
      type: "function",
      function: {
        name: "apple_reminders",
        description: "Read and write the user's Apple Reminders through a trusted bridge app on their iPhone. Use this to create tasks, check what's on their list, mark items complete, etc.",
        parameters: {
          type: "object",
          properties: {
            op: {
              type: "string",
              enum: [
                "list_lists",
                "list_tasks",
                "create_task",
                "update_task",
                "complete_task",
                "delete_task"
              ],
              description: "Operation to perform"
            },
            args: {
              type: "object",
              description: "Arguments for the operation. Schema varies by op.",
              properties: {
                // For list_tasks
                list_id: { type: "string", description: "Optional: Filter by list ID" },
                status: { type: "string", enum: ["needsAction", "completed"] },

                // For create_task
                title: { type: "string", description: "Task title (required for create)" },
                notes: { type: "string", description: "Task notes/description" },
                due_iso: { type: "string", description: "Due date in ISO8601 format" },

                // For update/complete/delete
                task_id: { type: "string", description: "Task ID to modify" }
              }
            }
          },
          required: ["op"]
        }
      }
    }
  ]
});
```

### 2. Implement the Function Handler

```typescript
import { getUserIdFromSession } from './auth';

async function handleAppleReminders(op: string, args: any, userId: string) {
  const response = await fetch('https://your-server.com/tool/tasks', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      // Add your auth header if needed
      Authorization: `Bearer ${getServerToken()}`,
    },
    body: JSON.stringify({
      userId, // Map to your user system
      op,
      args,
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to execute command');
  }

  const result = await response.json();

  // Optional: Poll for result if you need synchronous response
  if (result.commandId) {
    return await pollForResult(result.commandId);
  }

  return result;
}

// Optional: Wait for device to execute and return result
async function pollForResult(commandId: string, maxAttempts = 10) {
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise((resolve) => setTimeout(resolve, 500)); // Wait 500ms

    const response = await fetch(`https://your-server.com/tool/result/${commandId}`);
    if (response.ok) {
      const result = await response.json();
      if (result.success) {
        return result.result;
      } else {
        throw new Error(result.error || 'Command failed');
      }
    }
  }

  return { status: 'pending', commandId };
}
```

### 3. Process Function Calls

```typescript
// In your chat loop
for (const toolCall of completion.choices[0].message.tool_calls || []) {
  if (toolCall.function.name === 'apple_reminders') {
    const { op, args } = JSON.parse(toolCall.function.arguments);

    try {
      const result = await handleAppleReminders(op, args, getUserIdFromSession());

      // Return result to GPT
      messages.push({
        role: 'tool',
        tool_call_id: toolCall.id,
        content: JSON.stringify(result),
      });
    } catch (error) {
      messages.push({
        role: 'tool',
        tool_call_id: toolCall.id,
        content: JSON.stringify({ error: error.message }),
      });
    }
  }
}
```

## Example Conversations

### Create a reminder

**User:** "Add a reminder to call the dentist tomorrow at 2pm"

**GPT calls:**

```json
{
  "op": "create_task",
  "args": {
    "title": "Call dentist",
    "due_iso": "2025-11-10T14:00:00Z"
  }
}
```

**Response:**

```json
{
  "id": "reminder-uuid",
  "title": "Call dentist",
  "status": "needsAction",
  "dueISO": "2025-11-10T14:00:00Z",
  "url": "gptreminders://task/reminder-uuid"
}
```

**GPT:** "I've added a reminder to call the dentist tomorrow at 2 PM. [Tap here to view](gptreminders://task/reminder-uuid)"

### Check tasks

**User:** "What's on my todo list?"

**GPT calls:**

```json
{
  "op": "list_tasks",
  "args": {
    "status": "needsAction"
  }
}
```

**Response:**

```json
[
  {
    "id": "uuid-1",
    "title": "Call dentist",
    "dueISO": "2025-11-10T14:00:00Z",
    "status": "needsAction"
  },
  {
    "id": "uuid-2",
    "title": "Buy groceries",
    "status": "needsAction"
  }
]
```

**GPT:** "You have 2 tasks:\n1. Call dentist (due tomorrow at 2 PM)\n2. Buy groceries"

### Complete task

**User:** "I called the dentist, mark that done"

**GPT calls:**

```json
{
  "op": "complete_task",
  "args": {
    "task_id": "uuid-1"
  }
}
```

**GPT:** "Great! I've marked 'Call dentist' as complete."

## Custom GPT (ChatGPT)

If building a Custom GPT in ChatGPT:

### 1. Add Action

Go to Configure → Actions → Create new action

**Schema:**

```yaml
openapi: 3.0.0
info:
  title: Apple Reminders Bridge
  version: 1.0.0
servers:
  - url: https://your-server.com
paths:
  /tool/tasks:
    post:
      operationId: executeReminderCommand
      summary: Execute a command on Apple Reminders
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                userId:
                  type: string
                  description: User identifier
                op:
                  type: string
                  enum:
                    [list_lists, list_tasks, create_task, update_task, complete_task, delete_task]
                args:
                  type: object
              required: [userId, op]
      responses:
        '200':
          description: Command dispatched
          content:
            application/json:
              schema:
                type: object
```

### 2. Configure Auth

Add API key authentication if your server requires it.

### 3. Instructions

Add to Custom GPT instructions:

```
You can interact with the user's Apple Reminders using the executeReminderCommand action.

Available operations:
- list_lists: Get all reminder lists
- list_tasks: Get tasks (optionally filter by list_id or status)
- create_task: Create new reminder (requires title, optional: notes, list_id, due_iso)
- update_task: Update existing reminder (requires task_id)
- complete_task: Mark task as done (requires task_id)
- delete_task: Delete task (requires task_id)

Always pass the user's ID as userId parameter.

When creating tasks with due dates, convert natural language ("tomorrow at 2pm") to ISO8601 format.

After creating/updating tasks, include the deep link (url field) in your response so users can tap to open.
```

## Rate Limiting Best Practices

```typescript
import rateLimit from 'express-rate-limit';

// Apply to /tool/tasks endpoint
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 requests per minute
  message: { error: 'Too many requests, please try again later' },
});

app.post('/tool/tasks', limiter, async (req, res) => {
  // ... handler
});
```

## User Authentication

Map your auth system to device registration:

```typescript
// When user signs in and installs iOS app
app.post('/device/register', authenticateUser, (req, res) => {
  const userId = req.user.id; // From your auth middleware
  const { apnsToken } = req.body;

  devices.set(userId, { userId, apnsToken, registeredAt: Date.now() });
  res.json({ ok: true });
});

// Verify user can access their own reminders
app.post('/tool/tasks', authenticateUser, (req, res) => {
  const requestingUserId = req.user.id;
  const { userId } = req.body;

  if (requestingUserId !== userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  // ... continue
});
```

## Error Handling

```typescript
try {
  const result = await handleAppleReminders(op, args, userId);
  return result;
} catch (error) {
  // Map errors to user-friendly messages
  const errorMap = {
    'No registered device': 'You need to install the iOS app first. Download it from...',
    'JWT expired': 'The command took too long. Please try again.',
    'Task not found': 'That task no longer exists.',
    'Permission denied': 'The app needs access to Reminders. Open Settings on your iPhone.',
  };

  const message = errorMap[error.message] || error.message;

  // Return to GPT
  return {
    error: true,
    message,
    hint: 'Try checking the app or your Reminders settings.',
  };
}
```

## Testing

```typescript
// Mock for testing
const mockRemindersAPI = {
  lists: [
    { id: 'list-1', title: 'Personal' },
    { id: 'list-2', title: 'Work' },
  ],
  tasks: [{ id: 'task-1', listId: 'list-1', title: 'Buy milk', status: 'needsAction' }],
};

if (process.env.NODE_ENV === 'test') {
  app.post('/tool/tasks', (req, res) => {
    const { op, args } = req.body;

    if (op === 'list_lists') {
      return res.json({ ok: true, result: mockRemindersAPI.lists });
    }

    if (op === 'create_task') {
      const newTask = {
        id: `task-${Date.now()}`,
        ...args,
        status: 'needsAction',
      };
      mockRemindersAPI.tasks.push(newTask);
      return res.json({ ok: true, result: newTask });
    }

    // ... other ops
  });
}
```

## Production Considerations

1. **Async by default:** Commands may take 1-5 seconds to execute on device
2. **Offline handling:** Device might be offline; consider storing commands for later delivery
3. **Conflict resolution:** User might change reminders outside of GPT; implement sync strategy
4. **Bulk operations:** Batch multiple creates/updates into single command to reduce latency
5. **Push quota:** APNs has rate limits; implement exponential backoff for retries

## Next Steps

1. Deploy server to production (Railway, Render, etc.)
2. Update iOS app with production server URL
3. Distribute app via TestFlight or App Store
4. Integrate function calling in your GPT application
5. Monitor command success rates and latency
6. Add analytics for popular operations

Happy integrating! 🎉
