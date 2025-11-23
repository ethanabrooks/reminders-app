// GPT <-> Apple Reminders Tasks Proxy Server
import express, { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { readFileSync } from 'fs';
import { join } from 'path';
import dotenv from 'dotenv';
import { CommandEnvelope, DeviceInfo, CommandResult, CommandKind } from './types';
import { initializeAPNs, sendSilentPush, shutdownAPNs } from './apns';
import { openAIFunctionSchema } from './openai-schema';

dotenv.config();

const app = express();
app.use(express.json());

// In-memory stores (replace with Redis/DB in production)
const devices = new Map<string, DeviceInfo>();
const pendingCommands = new Map<string, { userId: string; command: string }>();
const commandResults = new Map<string, CommandResult>();

// Load JWT private key
let JWT_PRIVATE: string;
try {
  const keyPath =
    process.env.COMMAND_SIGNING_PRIVATE_PATH || join(__dirname, '..', 'keys', 'private.pem');
  JWT_PRIVATE = readFileSync(keyPath, 'utf8');
} catch {
  if (process.env.COMMAND_SIGNING_PRIVATE) {
    JWT_PRIVATE = process.env.COMMAND_SIGNING_PRIVATE.replace(/\\n/g, '\n');
  } else {
    console.error('❌ No JWT private key found. Run: npm run gen-keys');
    process.exit(1);
  }
}

// Initialize APNs
initializeAPNs();

// Sign a command envelope
function signCommand<T>(cmd: Omit<CommandEnvelope<T>, 'iat' | 'exp'>): string {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    ...cmd,
    iat: now,
    exp: now + 60, // 60 second TTL
  };
  return jwt.sign(payload, JWT_PRIVATE, { algorithm: 'RS256' });
}

// Generate command ID
function generateCommandId(): string {
  return `cmd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// ==================== Device Endpoints ====================

// Device registers its APNs token
app.post('/device/register', (req: Request, res: Response) => {
  const { userId, apnsToken } = req.body;

  if (!userId || !apnsToken) {
    return res.status(400).json({ error: 'Missing userId or apnsToken' });
  }

  devices.set(userId, {
    userId,
    apnsToken,
    registeredAt: Date.now(),
  });

  console.log(`✅ Device registered for user: ${userId}`);
  res.json({ ok: true, message: 'Device registered successfully' });
});

// Device posts command results
app.post('/device/result', (req: Request, res: Response) => {
  const { commandId, success, result, error } = req.body;

  if (!commandId) {
    return res.status(400).json({ error: 'Missing commandId' });
  }

  const commandResult: CommandResult = {
    commandId,
    success,
    result,
    error,
    timestamp: Date.now(),
  };

  commandResults.set(commandId, commandResult);
  console.log(`📥 Result received for command ${commandId}: ${success ? '✅' : '❌'}`);

  res.json({ ok: true });
});

// Device polls for pending commands (alternative to push)
app.get('/device/commands/:userId', (req: Request, res: Response) => {
  const { userId } = req.params;
  const commands: Array<{ id: string; envelope: string }> = [];

  // Find all pending commands for this user
  pendingCommands.forEach((value, commandId) => {
    if (value.userId === userId) {
      commands.push({ id: commandId, envelope: value.command });
    }
  });

  res.json({ commands });

  // Clear delivered commands
  commands.forEach((cmd) => pendingCommands.delete(cmd.id));
});

// ==================== GPT Tool Endpoint ====================

// Map OpenAI function names to internal operation codes
const FUNCTION_TO_OP: Record<string, CommandKind> = {
  list_reminder_lists: 'list_lists',
  list_reminder_tasks: 'list_tasks',
  create_reminder_task: 'create_task',
  update_reminder_task: 'update_task',
  complete_reminder_task: 'complete_task',
  delete_reminder_task: 'delete_task',
};

// Main endpoint that GPT calls
app.post('/tool/tasks', async (req: Request, res: Response) => {
  // Support both OpenAI function calling format and legacy format
  let op: CommandKind;
  let args: Record<string, unknown>;

  if (req.body.function && req.body.arguments) {
    // OpenAI function calling format: { function: "create_reminder_task", arguments: {...} }
    const functionName = req.body.function;
    op = FUNCTION_TO_OP[functionName];
    if (!op) {
      return res.status(400).json({ error: `Unknown function: ${functionName}` });
    }
    args = req.body.arguments || {};
  } else if (req.body.op) {
    // Legacy format: { op: "create_task", args: {...} }
    op = req.body.op;
    args = req.body.args || {};
  } else {
    return res.status(400).json({ error: 'Missing "function" or "op" field' });
  }

  const { userId } = req.body;

  // In production, verify user auth token here
  if (!userId) {
    return res.status(400).json({ error: 'Missing userId' });
  }

  const device = devices.get(userId);
  if (!device) {
    return res.status(404).json({
      error: 'No registered device',
      hint: 'User must install and register the iOS app first',
    });
  }

  // Validate operation
  const validOps: CommandKind[] = [
    'list_lists',
    'list_tasks',
    'create_task',
    'update_task',
    'complete_task',
    'delete_task',
  ];

  if (!validOps.includes(op)) {
    return res.status(400).json({ error: `Invalid operation: ${op}` });
  }

  // Create signed command envelope
  const commandId = generateCommandId();
  const envelope = signCommand({
    id: commandId,
    kind: op,
    payload: args,
  });

  // Store pending command
  pendingCommands.set(commandId, { userId, command: envelope });

  // Try to send via APNs silent push
  const pushSent = await sendSilentPush(device.apnsToken, { envelope });

  if (!pushSent) {
    // Silent - device will poll instead (expected for Simulator)
  }

  // Return optimistically (device will POST result to /device/result)
  res.json({
    ok: true,
    commandId,
    message: 'Command dispatched to device',
    deliveryMethod: pushSent ? 'push' : 'polling',
  });
});

// Poll for command result (for synchronous GPT responses)
app.get('/tool/result/:commandId', (req: Request, res: Response) => {
  const { commandId } = req.params;
  const result = commandResults.get(commandId);

  if (!result) {
    return res.status(404).json({ error: 'Result not available yet' });
  }

  res.json(result);
});

// ==================== OpenAI Tool Schema ====================

// Return the OpenAI function schema (array of functions)
app.get('/tool/schema', (_req: Request, res: Response) => {
  res.json(openAIFunctionSchema);
});

// ==================== Health & Status ====================

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    ok: true,
    devices: devices.size,
    pendingCommands: pendingCommands.size,
  });
});

app.get('/status', (_req: Request, res: Response) => {
  const deviceList = Array.from(devices.values()).map((d) => ({
    userId: d.userId,
    registeredAt: new Date(d.registeredAt).toISOString(),
  }));

  res.json({
    devices: deviceList,
    pendingCommands: pendingCommands.size,
    completedResults: commandResults.size,
  });
});

// ==================== Start Server ====================

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`
╭─────────────────────────────────────────────╮
│  🍎 GPT → Apple Reminders Proxy Server     │
│  🚀 Running on http://localhost:${PORT}      │
╰─────────────────────────────────────────────╯

Endpoints:
  POST /device/register      - Register iOS device
  POST /device/result        - Receive command results
  GET  /device/commands/:id  - Poll for commands
  POST /tool/tasks           - GPT tool endpoint
  GET  /tool/schema          - OpenAI function schema
  GET  /health               - Health check
  GET  /status               - Server status
`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully...');
  shutdownAPNs();
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});
