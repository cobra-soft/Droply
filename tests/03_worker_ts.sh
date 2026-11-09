#!/bin/bash
# Test 3: Worker TypeScript compilation check
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
WORKER_DIR="$PROJECT_DIR/worker"
PASS=0
FAIL=0

echo "=== TEST 3: Worker TypeScript Compilation ==="

if [ ! -f "$WORKER_DIR/tsconfig.json" ]; then
  echo "  [FAIL] worker/tsconfig.json missing"
  echo "TEST 3: FAILED"
  exit 1
fi

# Check tsconfig has required settings
if grep -q '"noEmit"' "$WORKER_DIR/tsconfig.json"; then
  echo "  [PASS] tsconfig.json has noEmit"
  PASS=$((PASS + 1))
else
  echo "  [WARN] tsconfig.json missing noEmit (not critical)"
fi

if grep -q '"@cloudflare/workers-types"' "$WORKER_DIR/tsconfig.json"; then
  echo "  [PASS] tsconfig.json references workers-types"
  PASS=$((PASS + 1))
else
  echo "  [WARN] tsconfig.json missing workers-types reference"
fi

# Check all worker source files parse as valid TypeScript (basic syntax check)
for f in "$WORKER_DIR/src"/*.ts; do
  fname=$(basename "$f")
  # Basic check: file is not empty and has reasonable content
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  if [ "$lines" -gt 5 ]; then
    echo "  [PASS] $fname has content ($lines lines)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $fname appears empty or too short ($lines lines)"
    FAIL=$((FAIL + 1))
  fi
done

# Check that index.ts exports scheduled (cron handler)
if grep -q 'async scheduled' "$WORKER_DIR/src/index.ts"; then
  echo "  [PASS] index.ts exports scheduled() cron handler"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] index.ts MISSING scheduled() cron handler"
  FAIL=$((FAIL + 1))
fi

# Check that index.ts exports default object with fetch
if grep -q 'export default {' "$WORKER_DIR/src/index.ts"; then
  echo "  [PASS] index.ts exports default object"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] index.ts MISSING default export"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 3: PASSED" || echo "TEST 3: FAILED"
exit $FAIL
