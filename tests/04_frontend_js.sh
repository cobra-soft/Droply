#!/bin/bash
# Test 4: Inline frontend JavaScript parses cleanly (node --check)
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
INDEX="$PROJECT_DIR/frontend/index.html"
PASS=0
FAIL=0

echo "=== TEST 4: Frontend Inline JS Syntax ==="

if [ ! -f "$INDEX" ]; then
  echo "  [FAIL] frontend/index.html missing"
  echo "TEST 4: FAILED"
  exit 1
fi

TMP_JS=$(mktemp /tmp/droply-inline-XXXXXX.js)
python3 - "$INDEX" "$TMP_JS" <<'PY'
import re, sys
html = open(sys.argv[1], encoding='utf-8').read()
scripts = re.findall(r'<script>(.*?)</script>', html, re.S)
if not scripts:
    sys.exit(3)
open(sys.argv[2], 'w', encoding='utf-8').write(scripts[-1])
PY
rc=$?
if [ $rc -ne 0 ]; then
  echo "  [FAIL] no inline <script> found"
  rm -f "$TMP_JS"
  echo "TEST 4: FAILED"
  exit 1
fi
echo "  [PASS] inline script extracted"
PASS=$((PASS + 1))

if node --check "$TMP_JS"; then
  echo "  [PASS] node --check passed"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] node --check failed"
  FAIL=$((FAIL + 1))
fi

if grep -q "t('" "$TMP_JS"; then
  echo "  [PASS] uses translation helper t()"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] translation helper t() not used"
  FAIL=$((FAIL + 1))
fi

if grep -q "WebSocket(" "$TMP_JS"; then
  echo "  [PASS] WebSocket client present"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] WebSocket client missing"
  FAIL=$((FAIL + 1))
fi

rm -f "$TMP_JS"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 4: PASSED" || echo "TEST 4: FAILED"
exit $FAIL
