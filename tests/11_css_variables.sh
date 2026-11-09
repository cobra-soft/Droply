#!/bin/bash
# Test 11: CSS variables and theme completeness in frontend/index.html
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
INDEX="$PROJECT_DIR/frontend/index.html"
PASS=0
FAIL=0

echo "=== TEST 11: CSS Variables & Theme ==="

if [ ! -f "$INDEX" ]; then
  echo "  [FAIL] frontend/index.html missing"
  echo "TEST 11: FAILED"
  exit 1
fi

LIGHT_VARS="--bg --on --surface --surface-high --primary --on-primary --primary-container --outline --muted --error"
for var in $LIGHT_VARS; do
  if grep -q -F -e "${var}:" "$INDEX"; then
    echo "  [PASS] Theme variable: $var"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Theme variable MISSING: $var"
    FAIL=$((FAIL + 1))
  fi
done

if grep -q "\[data-theme='dark'\]" "$INDEX"; then
  echo "  [PASS] Dark theme override block exists"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Dark theme override block MISSING"
  FAIL=$((FAIL + 1))
fi

MOTION_VARS="--ease --ease-dec --spring"
for var in $MOTION_VARS; do
  if grep -q -F -e "${var}:" "$INDEX"; then
    echo "  [PASS] Motion token: $var"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Motion token MISSING: $var"
    FAIL=$((FAIL + 1))
  fi
done

RADIUS_VARS="--r-xl --r-lg --r-md --r-sm"
for var in $RADIUS_VARS; do
  if grep -q -F -e "${var}:" "$INDEX"; then
    echo "  [PASS] Radius variable: $var"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Radius variable MISSING: $var"
    FAIL=$((FAIL + 1))
  fi
done

if grep -q -F -e 'background:var(--bg)' "$INDEX"; then
  echo "  [PASS] body background uses var(--bg)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] body background does not use var(--bg)"
  FAIL=$((FAIL + 1))
fi

if grep -q "prefers-color-scheme" "$INDEX"; then
  echo "  [PASS] system theme preference respected"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] system theme preference not handled"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 11: PASSED" || echo "TEST 11: FAILED"
exit $FAIL
