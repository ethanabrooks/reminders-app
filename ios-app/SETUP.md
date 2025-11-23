# iOS App Setup Guide

Complete guide for running the app in iOS Simulator and on a physical iPhone.

## Prerequisites

- Xcode 14+ installed
- Node.js 18+ installed
- Apple Developer Account (for physical device, free account works)
- Server running (see [server/README.md](../server/README.md))

---

## Part 1: iOS Simulator Setup (Development/Testing)

**Note**: Simulator doesn't support APNs push notifications, so the app will use **polling mode** (checks for commands every few seconds).

### Step 1: Generate Keys

```bash
cd server
npm install
npm run gen-keys
```

This creates `server/keys/public.pem` and `server/keys/private.pem`.

### Step 2: Add Public Key to Xcode Project

```bash
# From project root
node scripts/add-public-key-to-xcode.js
```

This script copies the file to the correct location and verifies it's in the project.

### Step 3: Configure Server URL

**Auto-detect Mac IP** (Recommended for Simulator):

```bash
# Automatically detects your Mac's IP and configures the app
node scripts/configure-server-url-auto.js
```

**Manual configuration**:

```bash
# Find your Mac's IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Configure server URL (replace with your IP)
node scripts/configure-server-url.js "http://192.168.1.100:3000"
```

**Note**: iOS Simulator cannot reach `localhost` on the host machine. You must use your Mac's actual IP address.

### Step 4: Build and Run

**Start the server** (in a separate terminal):

⚠️ **CRITICAL**: The server must remain running in this terminal for the app to work. Do not close it.

```bash
cd server
npm run dev
```

**Build and run the app** (in a NEW terminal):

```bash
# From project root
./scripts/build-and-run.sh simulator "iPhone 16 Pro"
```

**Grant Permissions** (in Simulator):

- When prompted, tap **"Grant Reminders Access"**
- Tap **"Allow"** in the system permission dialog

**Verify Registration**:

```bash
# Check server logs or:
curl http://localhost:3000/status
```

You should see your device UUID in the response.

### Step 5: Test (Polling Mode)

You can verify the entire flow (Server -> Polling -> Simulator -> EventKit -> Server) using the provided test script.

1.  Ensure the server is running (`npm run dev`).
2.  Ensure the Simulator app is running.
3.  Run the integration test:

```bash
./scripts/test-simulator-integration.sh
```

If successful, you will see:

```
✅ E2E Test Passed: Server -> Polling -> Simulator -> EventKit -> Server
```

This script automatically:

1.  Finds your device ID from the server.
2.  Sends a "Create Task" command.
3.  Polls the server until the simulator processes it and returns a result.

**Manual Method**:

If you prefer to test manually:

```bash
# Get your userId from status
USER_ID=$(curl -s http://localhost:3000/status | grep -o '"userId":"[^"]*"' | head -1 | cut -d'"' -f4)

# Send a command
curl -X POST http://localhost:3000/tool/tasks \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$USER_ID\",
    \"op\": \"create_task\",
    \"args\": {\"title\": \"Test from Simulator\"}
  }"
```

The app will pick it up on the next poll cycle (within 2 seconds).

---

## Part 2: Physical iPhone Setup (Production)

For real push notifications, you need APNs configured.

### Step 1: Apple Developer Setup

**Note**: This step requires the Apple Developer Portal (web GUI). There's no CLI alternative.

1. **Create APNs Auth Key**:
   - Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys)
   - Click **"+"** to create a new key
   - Name it "GPT Reminders APNs Key"
   - Check **"Apple Push Notifications service (APNs)"**
   - Click **Continue** → **Register**
   - **Download** the `.p8` file (you can only download once!)
   - Note the **Key ID** (shown on the page)

2. **Get your Team ID**:
   - In Apple Developer Portal, go to **Membership**
   - Copy your **Team ID** (10-character string)

### Step 2: Configure Server APNs

```bash
# Copy the .p8 file
cp ~/Downloads/AuthKey_XXXXXXXXXX.p8 server/keys/

# Create .env file
cd server
cp env.example .env
```

Edit `server/.env`:

```bash
APNS_KEY_PATH=./keys/AuthKey_XXXXXXXXXX.p8
APNS_KEY_ID=XXXXXXXXXX          # From Apple Developer Portal
APNS_TEAM_ID=YYYYYYYYYY          # Your Team ID
APNS_BUNDLE_ID=com.yourname.GPTReminders
APNS_PRODUCTION=false            # true for App Store builds
```

**Restart server**:

```bash
npm run dev
```

You should see:

```
✅ APNs initialized (sandbox)
```

### Step 3: Configure Xcode for Device

**Update Bundle Identifier**:

```bash
# From project root
node scripts/configure-bundle-id.js com.yourname.GPTReminders
```

**Update Server URL** (if needed):

```bash
# For local testing (use your Mac's IP)
ifconfig | grep "inet " | grep -v 127.0.0.1
node scripts/configure-server-url.js "http://192.168.1.100:3000"

# For production
node scripts/configure-server-url.js "https://your-server.com"
```

**Configure Signing** (requires Xcode GUI):

- Open Xcode: `open ios-app/GPTReminders.xcodeproj`
- Select **GPTReminders** target
- Go to **"Signing & Capabilities"**
- Select your **Team** under Signing
- Xcode will automatically create a provisioning profile

### Step 4: Build & Install on iPhone

**Connect iPhone** via USB and trust the computer if prompted.

**Build and install**:

```bash
# This will open Xcode for device selection and signing
./scripts/build-and-run.sh device
```

Or build from Xcode:

- Select your iPhone from device menu
- Press **⌘R** to build and run

**On iPhone**:

- Go to **Settings → General → VPN & Device Management**
- Trust your developer certificate
- Open the **GPT Reminders** app
- Grant Reminders permission when prompted

### Step 5: Verify Push Notifications

```bash
# Check registration
curl http://localhost:3000/status

# Get userId
USER_ID=$(curl -s http://localhost:3000/status | grep -o '"userId":"[^"]*"' | head -1 | cut -d'"' -f4)

# Send a test command
curl -X POST http://localhost:3000/tool/tasks \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$USER_ID\",
    \"op\": \"create_task\",
    \"args\": {\"title\": \"Test Push Notification\"}
  }"
```

**Expected behavior**:

- Command should arrive **instantly** via push (not polling)
- Check iPhone logs in Xcode Console: `xcrun simctl spawn booted log stream --predicate 'processImagePath contains "GPTReminders"'`
- Task should appear in Apple Reminders app

---

## Troubleshooting

### Simulator: "No envelope in notification"

- **Cause**: Simulator doesn't receive real APNs pushes
- **Solution**: This is expected. Commands will be delivered via polling instead.

### Device: "Failed to register for remote notifications"

- **Cause**: APNs not configured or invalid credentials
- **Solution**:

  ```bash
  # Verify .env configuration
  cat server/.env | grep APNS

  # Check Key ID and Team ID match Apple Developer Portal
  # Ensure Bundle ID matches in Xcode and .env
  ```

### "public.pem not found in Bundle"

- **Cause**: File not added to target
- **Solution**:

  ```bash
  # Re-run the setup script
  node scripts/add-public-key-to-xcode.js

  # Clean and rebuild
  xcodebuild -project ios-app/GPTReminders.xcodeproj -scheme GPTReminders clean
  ```

### Server: "No registered device"

- **Cause**: App hasn't registered yet
- **Solution**:

  ```bash
  # Check server logs
  # Verify server is running
  curl http://localhost:3000/health

  # Verify serverURL in AppDelegate.swift
  grep serverURL ios-app/GPTReminders/Sources/AppDelegate.swift
  ```

---

## Next Steps

Once your app is running and registered, see:

- **[GPT Integration Guide](../GPT_INTEGRATION_QUICKSTART.md)** - Connect to ChatGPT
- **[Server README](../server/README.md)** - API documentation
- **[Scripts README](../scripts/README.md)** - Testing tools
