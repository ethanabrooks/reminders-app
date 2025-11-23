// Node 18+ has global fetch by default

// Node 18+ has global fetch, so we might not need import if running with tsx

const SERVER_URL = process.env.SERVER_URL || 'http://localhost:3000';
const USER_ID = 'A0FE1D55-DA04-4848-825B-BC76BF0590EE'; // Matching the ID from the user's command
const POLLING_INTERVAL = 2000; // 2 seconds

async function registerDevice() {
    console.log(`📱 Registering simulated device...`);
    console.log(`   ID: ${USER_ID}`);

    try {
        const res = await fetch(`${SERVER_URL}/device/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                userId: USER_ID,
                apnsToken: 'SIMULATED_TOKEN_' + Date.now(),
            }),
        });

        if (!res.ok) {
            throw new Error(`Registration failed: ${res.status} ${res.statusText}`);
        }

        const data = await res.json();
        console.log(`✅ Registered!`, data);
    } catch (err) {
        console.error('❌ Failed to register:', err);
        process.exit(1);
    }
}

function decodeJwtPayload(token: string) {
    try {
        const parts = token.split('.');
        if (parts.length !== 3) return null;
        const payload = Buffer.from(parts[1], 'base64').toString();
        return JSON.parse(payload);
    } catch (e) {
        return null;
    }
}

async function pollForCommands() {
    try {
        const res = await fetch(`${SERVER_URL}/device/commands/${USER_ID}`);
        if (!res.ok) {
            // If 404 or connection error, just ignore and retry
            return;
        }

        const data: any = await res.json();
        const commands = data.commands || [];

        if (commands.length > 0) {
            console.log(`\n📥 Received ${commands.length} command(s)`);

            for (const cmd of commands) {
                const decoded = decodeJwtPayload(cmd.envelope);
                const op = decoded ? decoded.kind : 'unknown';
                const args = decoded ? decoded.payload : {};
                const commandId = decoded ? decoded.id : cmd.id;

                console.log(`   ▶ Executing: ${op}`, args);

                // Simulate "work"
                await new Promise(r => setTimeout(r, 500));

                // Mock result based on op
                let resultData: any = { status: 'done' };
                if (op === 'list_lists') {
                    resultData = {
                        lists: [
                            { id: 'l1', title: 'Reminders' },
                            { id: 'l2', title: 'Groceries' }
                        ]
                    };
                } else if (op === 'list_tasks') {
                    resultData = {
                        tasks: [
                            { id: '1', title: 'Buy milk', completed: false },
                            { id: '2', title: 'Walk the dog', completed: true }
                        ]
                    };
                } else if (op === 'create_task') {
                    resultData = { id: `task_${Date.now()}`, title: args.title, status: 'created' };
                }

                // Send result
                await sendResult(commandId, true, resultData);
            }
        }
    } catch (err) {
        // Silent fail on poll error to avoid console spam, maybe log occasionally
    }
}

async function sendResult(commandId: string, success: boolean, result: any) {
    try {
        await fetch(`${SERVER_URL}/device/result`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                commandId,
                success,
                result,
            }),
        });
        console.log(`   📤 Sent result for ${commandId}`);
    } catch (err) {
        console.error(`   ❌ Failed to send result:`, err);
    }
}

async function main() {
    await registerDevice();

    console.log(`\n🔄 Polling for commands every ${POLLING_INTERVAL / 1000}s...`);
    console.log(`   Keep this running. In another terminal, run the GPT example.`);

    while (true) {
        await pollForCommands();
        await checkRegistrationStatus();
        await new Promise(resolve => setTimeout(resolve, POLLING_INTERVAL));
    }
}

async function checkRegistrationStatus() {
    try {
        const res = await fetch(`${SERVER_URL}/status`);
        if (res.ok) {
            const data: any = await res.json();
            const isRegistered = data.devices.some((d: any) => d.userId === USER_ID);
            if (!isRegistered) {
                console.log('⚠️ Device not found on server (server likely restarted). Re-registering...');
                await registerDevice();
            }
        }
    } catch (err) {
        // Ignore connection errors, pollForCommands will handle/log them if persistent
    }
}

main().catch(console.error);

