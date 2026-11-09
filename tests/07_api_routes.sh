#!/bin/bash
# Test 7: API route coverage - all required endpoints present
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
INDEX="$PROJECT_DIR/worker/src/index.ts"
PASS=0
FAIL=0

echo "=== TEST 7: API Route Coverage ==="

if [ ! -f "$INDEX" ]; then
  echo "  [FAIL] worker/src/index.ts missing"
  echo "TEST 7: FAILED"
  exit 1
fi

# POST /api/sessions
if grep -q "/api/sessions' && request.method === 'POST'" "$INDEX"; then
  echo "  [PASS] POST /api/sessions (create session)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] POST /api/sessions MISSING"
  FAIL=$((FAIL + 1))
fi

# GET /api/sessions/:id
if grep -q "getSession(sessionId)" "$INDEX"; then
  echo "  [PASS] GET /api/sessions/:id (session info)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] GET /api/sessions/:id MISSING"
  FAIL=$((FAIL + 1))
fi

# POST /api/sessions/:id/upload
if grep -q "uploadMatch = pathname.match" "$INDEX"; then
  echo "  [PASS] POST /api/sessions/:id/upload (file upload)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] POST /api/sessions/:id/upload MISSING"
  FAIL=$((FAIL + 1))
fi

# GET /api/files/:fileId
if grep -q "/api/files/" "$INDEX"; then
  echo "  [PASS] GET /api/files/:fileId (file download)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] GET /api/files/:fileId MISSING"
  FAIL=$((FAIL + 1))
fi

# DELETE /api/files/:fileId
if grep -q "method === 'DELETE'" "$INDEX"; then
  echo "  [PASS] DELETE /api/files/:fileId (file delete)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] DELETE /api/files/:fileId MISSING"
  FAIL=$((FAIL + 1))
fi

# WebSocket route /api/sessions/:id/ws
if grep -q "wsMatch = pathname.match" "$INDEX"; then
  echo "  [PASS] WS /api/sessions/:id/ws (real-time channel)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WS /api/sessions/:id/ws MISSING"
  FAIL=$((FAIL + 1))
fi

# WebSocket forwards to Durable Object
if grep -q 'stub.fetch(request)' "$INDEX"; then
  echo "  [PASS] WebSocket request forwarded to Durable Object via stub.fetch()"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WebSocket request NOT forwarded to Durable Object"
  FAIL=$((FAIL + 1))
fi

# R2 direct stream via r2.getFile(
if grep -q 'r2.getFile(' "$INDEX"; then
  echo "  [PASS] File download streams directly from R2 via r2.getFile()"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] File download does not stream from R2"
  FAIL=$((FAIL + 1))
fi

# No AWS SDK imports
if grep -q '@aws-sdk' "$INDEX"; then
  echo "  [FAIL] AWS SDK still imported"
  FAIL=$((FAIL + 1))
else
  echo "  [PASS] No AWS SDK imports"
  PASS=$((PASS + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 7: PASSED" || echo "TEST 7: FAILED"
exit $FAIL
