# GPT Integration Quick Start

Connect your Apple Reminders bridge to GPT-4, GPT-4o, or any OpenAI model.

## Prerequisites

✅ Server running (`npm run dev` in `server/` directory)
✅ iOS app installed and registered
✅ OpenAI API key

## Step 1: Get Your Device ID

The device ID is needed to route commands to your iPhone:

```bash
curl http://localhost:3000/status
```

Look for the `userId` field. It will look something like:
```json
{
  "devices": [
    {
      "userId": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
      "registeredAt": "2025-11-09T..."
    }
  ]
}
```

Copy that `userId` - you'll need it!

## Step 2: Install OpenAI SDK

```bash
npm install openai
# or if in the root directory
cd /path/to/your/gpt-app && npm install openai
```

## Step 3: Set Environment Variables

```bash
export OPENAI_API_KEY="sk-your-openai-api-key-here"
export USER_ID="your-device-uuid-from-step-1"
```

## Step 4: Run the Example

I've created a complete example script for you:

```bash
# From the gpt-apple-reminders directory
npx tsx gpt-integration-example.ts "What's on my todo list?"
```

### Other Examples:

```bash
# Create a reminder
npx tsx gpt-integration-example.ts "Add a reminder to call mom tomorrow at 2pm"

# Check tasks
npx tsx gpt-integration-example.ts "Show me all my incomplete tasks"

# Complete a task (you'll need to know the task title first)
npx tsx gpt-integration-example.ts "I finished calling mom, mark it as done"
```

## How It Works

```
User Request → GPT-4 → apple_reminders function → Your Server
                                                         ↓
                                                    iOS Device
                                                         ↓
                                                  Apple Reminders
                                                         ↓
                                                      Result
                                                         ↓
                                                    Your Server
                                                         ↓
                                                      GPT-4 → Response to User
```

## Integration Code Snippet

Here's the minimal code to add Apple Reminders to your GPT app:

```typescript
import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// 1. Add the tool definition
const tools = [{
  type: 'function',
  function: {
    name: 'apple_reminders',
    description: 'Manage Apple Reminders',
    parameters: {
      type: 'object',
      properties: {
        op: {
          type: 'string',
          enum: ['list_tasks', 'create_task', 'complete_task'],
        },
        args: { type: 'object' }
      },
      required: ['op']
    }
  }
}];

// 2. Call OpenAI with tools
const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: 'Add reminder to buy milk' }],
  tools,
});

// 3. Handle function calls
for (const toolCall of response.choices[0].message.tool_calls || []) {
  if (toolCall.function.name === 'apple_reminders') {
    const { op, args } = JSON.parse(toolCall.function.arguments);

    // Call your server
    const result = await fetch('http://localhost:3000/tool/tasks', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId: YOUR_USER_ID, op, args })
    });

    // Return result to GPT...
  }
}
```

## Use Cases

### Personal Assistant
- "Add a reminder to take out the trash on Thursday"
- "What do I need to do today?"
- "Mark 'dentist appointment' as done"

### Smart Home Integration
- "When I leave home, remind me to lock the door"
- "Add all these groceries to my shopping list"

### Meeting Notes
- "Create reminders from this meeting summary: [paste notes]"
- GPT extracts action items and creates reminders automatically

### Email Integration
- "Scan my unread emails and create reminders for follow-ups"
- GPT reads emails, identifies tasks, creates reminders

## Production Setup

For production use:

1. **Deploy the server** to a cloud provider (Railway, Render, Fly.io)
2. **Update iOS app** with production server URL
3. **Add authentication** to protect the `/tool/tasks` endpoint
4. **Set up APNs** for instant delivery (optional, but recommended)
5. **Monitor usage** and set rate limits

## Troubleshooting

### "No registered device" error
- Make sure your iOS app is running and has granted Reminders access
- Check server status: `curl http://localhost:3000/status`
- Restart the iOS app if needed

### "Result not available yet"
- The iOS device might be offline or the app is backgrounded
- Try opening the app on the simulator/device
- In polling mode, commands can take 5-30 seconds

### GPT doesn't call the function
- Make sure your prompt is clear: "Add a reminder..." not "Maybe add..."
- Check that the function description is accurate
- Try using `tool_choice: 'required'` for testing

## Next Steps

- Read [INTEGRATION.md](./INTEGRATION.md) for advanced topics
- Check [ARCHITECTURE.md](./ARCHITECTURE.md) to understand the system
- Deploy to production following [deployment guide]

---

**Questions?** Open an issue or check the docs!
