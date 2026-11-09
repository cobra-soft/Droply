#!/bin/bash
# Test 10: Local font files present and referenced by index.html
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
ASSETS="$PROJECT_DIR/frontend/assets"
INDEX="$PROJECT_DIR/frontend/index.html"
PASS=0
FAIL=0

echo "=== TEST 10: Font Files & CSS References ==="

for font in BalsamiqSans-Regular.ttf BalsamiqSans-Bold.ttf BalsamiqSans-Italic.ttf BalsamiqSans-BoldItalic.ttf; do
  if [ -f "$ASSETS/$font" ]; then
    size=$(wc -c < "$ASSETS/$font")
    if [ "$size" -gt 1000 ]; then
      echo "  [PASS] assets/$font ($size bytes)"
      PASS=$((PASS + 1))
    else
      echo "  [FAIL] assets/$font too small ($size bytes)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  [FAIL] assets/$font MISSING"
    FAIL=$((FAIL + 1))
  fi
done

if grep -q "@font-face" "$INDEX"; then
  echo "  [PASS] index.html declares @font-face"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] index.html missing @font-face"
  FAIL=$((FAIL + 1))
fi

count=$(grep -c "src:url('assets/" "$INDEX" || true)
if [ "$count" -ge 4 ]; then
  echo "  [PASS] index.html references $count local font files"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] expected 4 local font references, found $count"
  FAIL=$((FAIL + 1))
fi

if grep -q "fonts.googleapis\|fonts.gstatic" "$INDEX"; then
  echo "  [FAIL] external Google Fonts reference found"
  FAIL=$((FAIL + 1))
else
  echo "  [PASS] no external font CDN"
  PASS=$((PASS + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 10: PASSED" || echo "TEST 10: FAILED"
exit $FAIL
