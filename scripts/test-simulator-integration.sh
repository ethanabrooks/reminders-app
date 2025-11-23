#!/bin/bash
set -e

SERVER_URL="http://localhost:3000"

echo "🔍 Checking server status..."
# Check if server is reachable
if ! curl -s --head "$SERVER_URL/health" > /dev/null; then
  echo "❌ Server is not running at $SERVER_URL"
  echo "   Run 'npm run dev' in the server directory."
  exit 1
fi

STATUS=$(curl -s "$SERVER_URL/status")

# Extract User ID
# We use grep/cut to avoid requiring 'jq', though 'jq' is better if available.
USER_ID=$(echo "$STATUS" | grep -o '"userId":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
  echo "❌ No devices registered."
  echo "   1. Run the server."
  echo "   2. Launch the iOS Simulator app."
  echo "   3. Wait for '✅ Device registered' in server logs."
  exit 1
fi

echo "📱 Found Device ID: $USER_ID"

TASK_TITLE="Test Task $(date +%H:%M:%S)"
echo "🚀 Sending 'create_task' command: \"$TASK_TITLE\"..."

RESPONSE=$(curl -s -X POST "$SERVER_URL/tool/tasks" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$USER_ID\",
    \"op\": \"create_task\",
    \"args\": {\"title\": \"$TASK_TITLE\"}
  }")

# Extract Command ID
COMMAND_ID=$(echo "$RESPONSE" | grep -o '"commandId":"[^"]*"' | cut -d'"' -f4)

if [ -z "$COMMAND_ID" ]; then
  echo "❌ Failed to send command. Response:"
  echo "$RESPONSE"
  exit 1
fi

echo "✅ Command sent! ID: $COMMAND_ID"
echo "⏳ Waiting for result (polling)..."

# Poll for result (up to 10 seconds)
for _ in {1..10}; do
  RESULT_JSON=$(curl -s "$SERVER_URL/tool/result/$COMMAND_ID")

  # Check if result is available (not the 404 error message)
  if [[ "$RESULT_JSON" != *"Result not available yet"* ]]; then
    echo ""
    echo "🎉 Success! Result received:"
    echo "$RESULT_JSON"
    echo ""
    echo "✅ E2E Test Passed: Server -> Polling -> Simulator -> EventKit -> Server"
    exit 0
  fi

  printf "."
  sleep 1
done

echo ""
echo "❌ Timed out waiting for result."
echo "   Check simulator logs to ensure it is polling."
exit 1
