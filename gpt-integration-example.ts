#!/usr/bin/env node
/**
 * GPT-4 + Apple Reminders Integration Example
 *
 * This demonstrates how to integrate your Apple Reminders bridge with OpenAI's GPT models.
 *
 * Setup:
 * 1. Install dependencies: npm install openai
 * 2. Set your OpenAI API key: export OPENAI_API_KEY="sk-..."
 * 3. Get your device userId from: curl http://localhost:3000/status
 * 4. Run: npx tsx gpt-integration-example.ts
 */

import OpenAI from 'openai';

// Configuration
const SERVER_URL = process.env.SERVER_URL || 'http://localhost:3000';
const USER_ID = process.env.USER_ID || 'YOUR_DEVICE_UUID_HERE'; // Get from /status endpoint

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Function to call Apple Reminders bridge
async function callAppleReminders(op: string, args: any = {}) {
  console.log(`📱 Calling Apple Reminders: ${op}`, args);

  const response = await fetch(`${SERVER_URL}/tool/tasks`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: USER_ID,
      op,
      args,
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  const result = await response.json();
  console.log(`✅ Command dispatched: ${result.commandId}`);

  // Wait for device to execute (poll for result)
  if (result.commandId) {
    return await pollForResult(result.commandId);
  }

  return result;
}

// Poll for command result
async function pollForResult(commandId: string, maxAttempts = 15): Promise<any> {
  console.log(`⏳ Waiting for device to execute...`);

  for (let i = 0; i < maxAttempts; i++) {
    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second

    try {
      const response = await fetch(`${SERVER_URL}/tool/result/${commandId}`);
      if (response.ok) {
        const result = await response.json();
        if (result.success) {
          console.log(`✅ Result received:`, result.result);
          return result.result;
        } else {
          throw new Error(result.error || 'Command failed');
        }
      }
    } catch (error) {
      if (i === maxAttempts - 1) throw error;
    }
  }

  return { status: 'timeout', message: 'Device did not respond in time' };
}

// Main chat function with Apple Reminders integration
async function chatWithReminders(userMessage: string) {
  console.log('\n' + '='.repeat(60));
  console.log(`User: ${userMessage}`);
  console.log('='.repeat(60));

  const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    {
      role: 'system',
      content: `You are a helpful assistant that can manage the user's Apple Reminders.

When the user asks to create reminders, check their todo list, or mark tasks complete, use the apple_reminders function.

Current date/time: ${new Date().toISOString()}

Be concise and friendly.`,
    },
    {
      role: 'user',
      content: userMessage,
    },
  ];

  // Define the Apple Reminders function tool
  const tools: OpenAI.Chat.ChatCompletionTool[] = [
    {
      type: 'function',
      function: {
        name: 'apple_reminders',
        description: 'Read and write Apple Reminders through a trusted bridge app on the user\'s iPhone. Use this to create tasks, check what\'s on their list, mark items complete, etc.',
        parameters: {
          type: 'object',
          properties: {
            op: {
              type: 'string',
              enum: ['list_lists', 'list_tasks', 'create_task', 'update_task', 'complete_task', 'delete_task'],
              description: 'Operation to perform',
            },
            args: {
              type: 'object',
              description: 'Arguments for the operation. Schema varies by op.',
              properties: {
                // For list_tasks
                list_id: { type: 'string', description: 'Optional: Filter by list ID' },
                status: {
                  type: 'string',
                  enum: ['needsAction', 'completed'],
                  description: 'Filter tasks by status'
                },
                // For create_task
                title: { type: 'string', description: 'Task title (required for create)' },
                notes: { type: 'string', description: 'Task notes/description' },
                due_iso: { type: 'string', description: 'Due date in ISO8601 format (e.g., 2025-11-10T14:00:00Z)' },
                list_id_for_create: { type: 'string', description: 'List ID to add task to' },
                // For update/complete/delete
                task_id: { type: 'string', description: 'Task ID to modify' },
              },
            },
          },
          required: ['op'],
        },
      },
    },
  ];

  // First API call
  let response = await openai.chat.completions.create({
    model: 'gpt-4o',  // or 'gpt-4-turbo', 'gpt-4'
    messages,
    tools,
    tool_choice: 'auto',
  });

  let assistantMessage = response.choices[0].message;

  // Handle function calls
  while (assistantMessage.tool_calls && assistantMessage.tool_calls.length > 0) {
    messages.push(assistantMessage);

    // Process each tool call
    for (const toolCall of assistantMessage.tool_calls) {
      if (toolCall.function.name === 'apple_reminders') {
        const args = JSON.parse(toolCall.function.arguments);
        console.log(`\n🤖 GPT wants to call: ${args.op}`);

        try {
          const result = await callAppleReminders(args.op, args.args || {});

          messages.push({
            role: 'tool',
            tool_call_id: toolCall.id,
            content: JSON.stringify(result),
          });
        } catch (error: any) {
          console.error(`❌ Error:`, error.message);
          messages.push({
            role: 'tool',
            tool_call_id: toolCall.id,
            content: JSON.stringify({ error: error.message }),
          });
        }
      }
    }

    // Get next response from GPT
    response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages,
      tools,
      tool_choice: 'auto',
    });

    assistantMessage = response.choices[0].message;
  }

  // Final response
  console.log(`\n🤖 Assistant: ${assistantMessage.content}\n`);
  return assistantMessage.content;
}

// Example usage
async function main() {
  // Check configuration
  if (!process.env.OPENAI_API_KEY) {
    console.error('❌ Please set OPENAI_API_KEY environment variable');
    console.error('   export OPENAI_API_KEY="sk-..."');
    process.exit(1);
  }

  if (USER_ID === 'YOUR_DEVICE_UUID_HERE') {
    console.error('❌ Please set USER_ID in the script or environment variable');
    console.error('   Get your device UUID from: curl http://localhost:3000/status');
    console.error('   Then set: export USER_ID="your-device-uuid"');
    process.exit(1);
  }

  // Check server connectivity
  try {
    const healthCheck = await fetch(`${SERVER_URL}/health`);
    if (!healthCheck.ok) throw new Error('Server not responding');
    console.log('✅ Connected to Apple Reminders bridge server');
  } catch (error) {
    console.error(`❌ Cannot connect to server at ${SERVER_URL}`);
    console.error('   Make sure the server is running: npm run dev');
    process.exit(1);
  }

  // Example conversations
  const examples = [
    "What's on my todo list?",
    "Add a reminder to buy milk tomorrow at 10am",
    "Show me all my completed tasks from today",
  ];

  // Run the first example
  const userInput = process.argv[2] || examples[0];

  console.log('\n🍎 Apple Reminders + GPT-4 Integration Demo\n');

  await chatWithReminders(userInput);

  console.log('\n💡 Try other examples:');
  examples.forEach((ex, i) => {
    console.log(`   ${i + 1}. npx tsx gpt-integration-example.ts "${ex}"`);
  });
}

// Run if executed directly
if (require.main === module) {
  main().catch(console.error);
}

export { chatWithReminders, callAppleReminders };
