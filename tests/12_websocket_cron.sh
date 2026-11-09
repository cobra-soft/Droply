#!/bin/bash
# Test 12: WebSocket route and cron integration
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
INDEX="$PROJECT_DIR/worker/src/index.ts"
PASS=0
FAIL=0

echo "=== TEST 12: WebSocket Route & Cron Integration ==="

# Check WebSocket route line vs GET route line
WS_LINE=$(grep -n "wsMatch = pathname.match" "$INDEX" | head -1 | cut -d: -f1)
GET_LINE=$(grep -n "getSession(sessionId)" "$INDEX" | head -1 | cut -d: -f1)
if [ -n "$WS_LINE" ] && [ -n "$GET_LINE" ] && [ "$WS_LINE" -lt "$GET_LINE" ]; then
  echo "  [PASS] WebSocket route checked before GET /api/sessions/:id (line $WS_LINE < $GET_LINE)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WebSocket route NOT before GET /api/sessions/:id (WS=$WS_LINE, GET=$GET_LINE)"
  FAIL=$((FAIL + 1))
fi

# Check cron handler exists
if grep -q 'async scheduled' "$INDEX"; then
  echo "  [PASS] scheduled() cron handler present in index.ts"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] scheduled() cron handler MISSING from index.ts"
  FAIL=$((FAIL + 1))
fi

# Check cron deletes R2 files
if grep -q 'getExpiredFileKeys' "$INDEX"; then
  echo "  [PASS] Cron reads R2 keys before deleting D1 rows"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Cron does not read R2 keys before deletion"
  FAIL=$((FAIL + 1))
fi

# Check cron deletes from R2 bucket
if grep -q 'r2.deleteFile' "$INDEX"; then
  echo "  [PASS] Cron deletes files from R2 bucket"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Cron does not delete from R2 bucket"
  FAIL=$((FAIL + 1))
fi

# Check db.ts has getExpiredFileKeys
DB="$PROJECT_DIR/worker/src/db.ts"
if grep -q 'getExpiredFileKeys' "$DB"; then
  echo "  [PASS] db.ts has getExpiredFileKeys() method"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] db.ts MISSING getExpiredFileKeys() method"
  FAIL=$((FAIL + 1))
fi

# Check wrangler.toml has cron trigger
WRANGLER="$PROJECT_DIR/worker/wrangler.toml"
if grep -q 'crons' "$WRANGLER"; then
  echo "  [PASS] wrangler.toml has cron trigger"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] wrangler.toml MISSING cron trigger"
  FAIL=$((FAIL + 1))
fi

# Check session.ts has alarm() for TTL
SESSION="$PROJECT_DIR/worker/src/session.ts"
if grep -q 'async alarm()' "$SESSION"; then
  echo "  [PASS] session.ts has alarm() for TTL expiration"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] session.ts MISSING alarm()"
  FAIL=$((FAIL + 1))
fi

# Check session.ts expireSession deletes from R2
if grep -q 'env.BUCKET.delete' "$SESSION"; then
  echo "  [PASS] session.ts expireSession() deletes from R2"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] session.ts expireSession() does not delete from R2"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 12: PASSED" || echo "TEST 12: FAILED"
exit $FAIL
