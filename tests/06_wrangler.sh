#!/bin/bash
# Test 6: wrangler.toml configuration validity
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
WRANGLER="$PROJECT_DIR/worker/wrangler.toml"
PASS=0
FAIL=0

echo "=== TEST 6: wrangler.toml Configuration ==="

if [ ! -f "$WRANGLER" ]; then
  echo "  [FAIL] worker/wrangler.toml missing"
  echo "TEST 6: FAILED"
  exit 1
fi

if grep -q 'durable_objects.bindings' "$WRANGLER"; then
  echo "  [PASS] Durable Object binding configured"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Durable Object binding MISSING"
  FAIL=$((FAIL + 1))
fi

if grep -q 'name = "SESSIONS"' "$WRANGLER"; then
  echo "  [PASS] SESSIONS binding name correct"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] SESSIONS binding name MISSING"
  FAIL=$((FAIL + 1))
fi

if grep -q 'd1_databases' "$WRANGLER"; then
  echo "  [PASS] D1 database binding configured"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] D1 database binding MISSING"
  FAIL=$((FAIL + 1))
fi

if grep -q 'r2_buckets' "$WRANGLER"; then
  echo "  [PASS] R2 bucket binding configured"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] R2 bucket binding MISSING"
  FAIL=$((FAIL + 1))
fi

if grep -q 'crons' "$WRANGLER"; then
  echo "  [PASS] cron triggers configured"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] cron triggers MISSING"
  FAIL=$((FAIL + 1))
fi

if grep -q 'main = "src/index.ts"' "$WRANGLER"; then
  echo "  [PASS] main entry point is src/index.ts"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] main entry point MISSING or incorrect"
  FAIL=$((FAIL + 1))
fi

if grep -q 'directory = "../frontend"' "$WRANGLER"; then
  echo "  [PASS] assets directory is ../frontend"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] assets directory should be ../frontend"
  FAIL=$((FAIL + 1))
fi

if grep -q 'class_name = "SessionDO"' "$WRANGLER"; then
  echo "  [PASS] SESSIONS class_name is SessionDO"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] SESSIONS class_name MISSING or incorrect"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 6: PASSED" || echo "TEST 6: FAILED"
exit $FAIL
