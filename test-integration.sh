#!/bin/bash
#
# Simple test script for Apple Reminders bridge
# This tests the integration without needing GPT/OpenAI API
#

set -e

SERVER_URL="${SERVER_URL:-http://localhost:3000}"

echo "🍎 Testing Apple Reminders Bridge Integration"
echo "============================================="
echo ""

# Check server health
echo "1. Checking server health..."
HEALTH=$(curl -s "$SERVER_URL/health")
echo "   ✅ Server is running"
echo "   $HEALTH"
echo ""

# Get registered devices
echo "2. Checking for registered devices..."
STATUS=$(curl -s "$SERVER_URL/status")
echo "   $STATUS"

# Extract userId (requires jq, or just copy manually)
USER_ID=$(echo "$STATUS" | grep -o '"userId":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo ""
  echo "   ⚠️  No device registered yet!"
  echo ""
  echo "   To register your device:"
  echo "   1. Make sure the iOS app is running in the simulator"
  echo "   2. Tap 'Grant Reminders Access' if you haven't already"
  echo "   3. The app should automatically register with the server"
  echo ""
  echo "   Then run this script again!"
  exit 1
fi

echo ""
echo "   ✅ Found device: $USER_ID"
echo ""

# Test list_tasks operation
echo "3. Testing list_tasks operation..."
COMMAND_RESPONSE=$(curl -s -X POST "$SERVER_URL/tool/tasks" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":\"$USER_ID\",\"op\":\"list_tasks\",\"args\":{\"status\":\"needsAction\"}}")

echo "   Command Response: $COMMAND_RESPONSE"

COMMAND_ID=$(echo "$COMMAND_RESPONSE" | grep -o '"commandId":"[^"]*"' | cut -d'"' -f4)

if [ -z "$COMMAND_ID" ]; then
  echo "   ❌ Failed to dispatch command"
  exit 1
fi

echo "   ✅ Command dispatched: $COMMAND_ID"
echo ""

# Poll for result
echo "4. Waiting for device to execute (polling for result)..."
ATTEMPTS=0
MAX_ATTEMPTS=15

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  sleep 1
  RESULT=$(curl -s "$SERVER_URL/tool/result/$COMMAND_ID" || echo "{}")

  if echo "$RESULT" | grep -q '"success":true'; then
    echo "   ✅ Result received!"
    echo ""
    echo "   Result:"
    echo "$RESULT" | python3 -m json.tool 2> /dev/null || echo "$RESULT"
    echo ""
    echo "============================================="
    echo "✅ Integration test passed!"
    echo ""
    echo "Next steps:"
    echo "1. Set your OpenAI API key: export OPENAI_API_KEY='sk-...'"
    echo "2. Run the GPT example: npx tsx gpt-integration-example.ts"
    exit 0
  fi

  if echo "$RESULT" | grep -q '"success":false'; then
    echo "   ❌ Command failed!"
    echo "$RESULT"
    exit 1
  fi

  ATTEMPTS=$((ATTEMPTS + 1))
  echo "   ⏳ Still waiting... (attempt $ATTEMPTS/$MAX_ATTEMPTS)"
done

echo ""
echo "   ⚠️  Timeout waiting for result"
echo ""
echo "   This could mean:"
echo "   - The iOS app is not running or is backgrounded"
echo "   - The app doesn't have Reminders permission"
echo "   - Network connectivity issue"
echo ""
echo "   Try:"
echo "   1. Open the Simulator app"
echo "   2. Make sure GPT Reminders app is in the foreground"
echo "   3. Check the app has Reminders access"
echo "   4. Run this script again"
