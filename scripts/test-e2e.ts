import { spawn, ChildProcess } from 'child_process';
import path from 'path';
// import { fetch } from 'undici'; // Node 18+ has global fetch

// Assume Node 18+
declare const fetch: any;

const PORT = 3001;
const SERVER_URL = `http://localhost:${PORT}`;
// We set APNS_PRODUCTION to false to match the dev environment
const ENV = { ...process.env, PORT: String(PORT), SERVER_URL, APNS_PRODUCTION: 'false' };
const ROOT_DIR = path.join(__dirname, '..');

let serverProcess: ChildProcess | null = null;
let simProcess: ChildProcess | null = null;

async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForServer(url: string, timeoutMs = 10000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`${url}/health`);
      if (res.ok) return true;
    } catch (e) {
      // ignore
    }
    await sleep(500);
  }
  return false;
}

async function waitForDevice(url: string, timeoutMs = 10000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`${url}/status`);
      if (res.ok) {
        const data: any = await res.json();
        if (data.devices && data.devices.length > 0) return true;
      }
    } catch (e) {
      // ignore
    }
    await sleep(500);
  }
  return false;
}

async function runTest() {
  console.log('🚀 Starting E2E Integration Test...');

  try {
    // 1. Start Server
    console.log('Starting server...');
    // We use the full path to tsx to avoid shell resolution issues if possible,
    // but npx is safer for path resolution.
    serverProcess = spawn('npx', ['tsx', 'server/src/index.ts'], {
      cwd: ROOT_DIR,
      env: ENV,
      // shell: false allows .kill() to work better on the child process itself
      // but 'npx' might need shell on some systems. On macOS/Linux standard spawn works for executables in path.
      shell: false,
      stdio: 'pipe',
    });

    if (!(await waitForServer(SERVER_URL))) {
      // If failed, maybe print stderr
      console.error('Server stderr:', serverProcess.stderr?.read()?.toString());
      throw new Error('Server failed to start');
    }
    console.log('✅ Server is up');

    // 2. Start Simulator
    console.log('Starting simulated device...');
    simProcess = spawn('npx', ['tsx', 'scripts/simulate-device.ts'], {
      cwd: ROOT_DIR,
      env: ENV,
      shell: false,
      stdio: 'pipe',
    });

    if (!(await waitForDevice(SERVER_URL))) {
      console.error('Simulator stderr:', simProcess.stderr?.read()?.toString());
      throw new Error('Simulator failed to register');
    }
    console.log('✅ Device registered');

    // 3. Run GPT Client
    console.log('Running GPT client...');
    const clientProcess = spawn(
      'npx',
      ['tsx', 'scripts/gpt-integration-example.ts', "What's on my todo list?"],
      {
        cwd: ROOT_DIR,
        env: { ...ENV, USER_ID: 'A0FE1D55-DA04-4848-825B-BC76BF0590EE' },
        shell: false,
        stdio: 'pipe',
      },
    );

    let output = '';
    clientProcess.stdout?.on('data', (data) => {
      const str = data.toString();
      output += str;
      process.stdout.write(str);
    });

    clientProcess.stderr?.on('data', (data) => {
      process.stderr.write(data);
    });

    const exitCode = await new Promise<number>((resolve) => {
      clientProcess.on('close', resolve);
    });

    if (exitCode !== 0) {
      throw new Error(`Client exited with code ${exitCode}`);
    }

    // Verify output
    if (!output.includes('✅ Result received') && !output.includes('Reminders')) {
      // "Reminders" appears in the list content
      throw new Error('Test failed: Did not see expected success output');
    }

    console.log('\n✅✅ E2E TEST PASSED! ✅✅\n');
  } catch (error) {
    console.error('\n❌ E2E TEST FAILED:', error);
    process.exit(1);
  } finally {
    // Cleanup
    console.log('Cleaning up...');
    if (serverProcess) serverProcess.kill();
    if (simProcess) simProcess.kill();

    // Wait a bit for cleanup
    setTimeout(() => process.exit(0), 500);
  }
}

runTest();
