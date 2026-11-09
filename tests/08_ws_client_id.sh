#!/bin/bash
# Test 8: Durable Object WebSocket client tracking
# Uses Set<WebSocket> (reference identity), not String(ws)
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
SESSION="$PROJECT_DIR/worker/src/session.ts"
PASS=0
FAIL=0

echo "=== TEST 8: WebSocket Client Tracking ==="

if [ ! -f "$SESSION" ]; then
  echo "  [FAIL] worker/src/session.ts missing"
  echo "TEST 8: FAILED"
  exit 1
fi

# Check that String(ws) is NOT used as actual code (only in comments OK)
# Count actual String(ws) usage outside comments
STRING_WS_COUNT=$(grep -v '^\s*//' "$SESSION" | grep -c "String(ws)" || true)
if [ "$STRING_WS_COUNT" -gt 0 ]; then
  echo "  [FAIL] String(ws) used in actual code (not just comments)"
  FAIL=$((FAIL + 1))
else
  echo "  [PASS] String(ws) NOT used as client key"
  PASS=$((PASS + 1))
fi

# Check that Set<WebSocket> is used (reference identity = unique per connection)
if grep -q "Set<WebSocket>" "$SESSION"; then
  echo "  [PASS] clients stored in Set<WebSocket> (unique per connection)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] clients NOT stored in Set<WebSocket>"
  FAIL=$((FAIL + 1))
fi

# Check that webSocketClose deletes by object reference
if grep -q "this.clients.delete(ws)" "$SESSION"; then
  echo "  [PASS] webSocketClose deletes by WebSocket reference"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webSocketClose does not delete by WebSocket reference"
  FAIL=$((FAIL + 1))
fi

# Check that broadcastRaw iterates over clients.values()
if grep -q "this.clients.values()" "$SESSION"; then
  echo "  [PASS] broadcastRaw iterates over clients.values()"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] broadcastRaw does not iterate over clients.values()"
  FAIL=$((FAIL + 1))
fi

# Check that webSocketOpen adds ws to set
if grep -q "this.clients.add(ws)" "$SESSION"; then
  echo "  [PASS] webSocketOpen adds ws to clients set"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] webSocketOpen does not add ws to clients set"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 8: PASSED" || echo "TEST 8: FAILED"
exit $FAIL
