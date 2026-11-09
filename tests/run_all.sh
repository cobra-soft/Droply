#!/bin/bash
# Master test runner for Droply project
# Runs all 12+ tests and reports results
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
TESTS_DIR="$PROJECT_DIR/tests"

echo "========================================"
echo "  DROPLY PROJECT TEST SUITE"
echo "========================================"
echo ""

# Make all tests executable
chmod +x "$TESTS_DIR"/*.sh 2>/dev/null || true

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_TESTS=0

run_test() {
  local test_name="$1"
  local test_script="$2"
  
  if [ ! -f "$test_script" ]; then
    echo "  [SKIP] $test_name - script not found: $test_script"
    return
  fi
  
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo "----------------------------------------"
  echo "Running: $test_name"
  echo "----------------------------------------"
  
  if bash "$test_script"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
    echo ""
    echo ">>> $test_name: PASSED"
  else
    local exit_code=$?
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    echo ""
    echo ">>> $test_name: FAILED (exit code $exit_code)"
  fi
  echo ""
}

run_test "Project Structure"           "$TESTS_DIR/01_structure.sh"
run_test "index.html Self-contained App" "$TESTS_DIR/02_index_html.sh"
run_test "Worker TypeScript Compilation" "$TESTS_DIR/03_worker_ts.sh"
run_test "Frontend Inline JS Syntax"    "$TESTS_DIR/04_frontend_js.sh"
run_test "D1 Migration SQL Validity"   "$TESTS_DIR/05_migration.sh"
run_test "wrangler.toml Configuration" "$TESTS_DIR/06_wrangler.sh"
run_test "API Route Coverage"          "$TESTS_DIR/07_api_routes.sh"
run_test "WebSocket Client ID Uniqueness" "$TESTS_DIR/08_ws_client_id.sh"
run_test "Translation Completeness"    "$TESTS_DIR/09_translations.sh"
run_test "Font Files & CSS References" "$TESTS_DIR/10_fonts.sh"
run_test "CSS Variables & Theme"       "$TESTS_DIR/11_css_variables.sh"
run_test "WebSocket Route & Cron Integration" "$TESTS_DIR/12_websocket_cron.sh"

echo "========================================"
echo "  FINAL RESULTS"
echo "========================================"
echo "  Total tests run:  $TOTAL_TESTS"
echo "  Passed:           $TOTAL_PASS"
echo "  Failed:           $TOTAL_FAIL"
echo ""

if [ $TOTAL_FAIL -eq 0 ]; then
  echo "  ALL TESTS PASSED ✓"
  exit 0
else
  echo "  SOME TESTS FAILED ✗"
  exit 1
fi
