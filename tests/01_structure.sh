#!/bin/bash
# Test 1: Project structure validation (single-file frontend)
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
PASS=0
FAIL=0

check_file() {
  if [ -f "$PROJECT_DIR/$1" ]; then
    echo "  [PASS] $1"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 MISSING"
    FAIL=$((FAIL + 1))
  fi
}

check_dir() {
  if [ -d "$PROJECT_DIR/$1" ]; then
    echo "  [PASS] $1/ (directory)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1/ (directory) MISSING"
    FAIL=$((FAIL + 1))
  fi
}

check_absent() {
  if [ ! -e "$PROJECT_DIR/$1" ]; then
    echo "  [PASS] $1 absent (removed)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 should be removed"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== TEST 1: Project Structure ==="
check_dir "frontend"
check_dir "frontend/assets"
check_dir "worker"
check_dir "worker/src"
check_dir "migrations"

echo ""
echo "  --- Frontend files ---"
check_file "frontend/index.html"

echo ""
echo "  --- No React/Vite build artifacts ---"
check_absent "frontend/src"
check_absent "frontend/public"
check_absent "frontend/dist"
check_absent "frontend/package.json"
check_absent "frontend/tsconfig.json"
check_absent "frontend/vite.config.ts"

echo ""
echo "  --- Worker files ---"
check_file "worker/wrangler.toml"
check_file "worker/package.json"
check_file "worker/tsconfig.json"
check_file "worker/src/index.ts"
check_file "worker/src/session.ts"
check_file "worker/src/db.ts"
check_file "worker/src/r2.ts"
check_file "worker/src/rateLimit.ts"
# cron.ts intentionally deleted — scheduled() lives in index.ts
if [ ! -f "$PROJECT_DIR/worker/src/cron.ts" ]; then
  echo "  [PASS] worker/src/cron.ts intentionally removed"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] worker/src/cron.ts should be deleted"
  FAIL=$((FAIL + 1))
fi
check_file "worker/src/types.ts"
check_file "worker/src/cloudflare.d.ts"

echo ""
echo "  --- Migration ---"
check_file "migrations/0001_initial.sql"

echo ""
echo "  --- Root files ---"
check_file "README.md"
check_file ".gitignore"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 1: PASSED" || echo "TEST 1: FAILED"
exit $FAIL
