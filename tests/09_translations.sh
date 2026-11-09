#!/bin/bash
# Test 9: Inline i18n completeness (en/ru/uk) in frontend/index.html
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
INDEX="$PROJECT_DIR/frontend/index.html"
PASS=0
FAIL=0

echo "=== TEST 9: Translation Completeness ==="

if [ ! -f "$INDEX" ]; then
  echo "  [FAIL] frontend/index.html missing"
  echo "TEST 9: FAILED"
  exit 1
fi

python3 - "$INDEX" <<'PY'
import re, sys
html = open(sys.argv[1], encoding='utf-8').read()
langs = {}
for lang in ('en', 'ru', 'uk'):
    m = re.search(r'\n    ' + lang + r': \{(.*?)\n    \}[,\n]', html, re.S)
    if not m:
        print(f"  [FAIL] language '{lang}' MISSING")
        continue
    keys = set(re.findall(r'\n      ([A-Za-z][A-Za-z0-9]*):', m.group(1)))
    langs[lang] = keys
    print(f"  [PASS] language '{lang}' defined ({len(keys)} keys)")

if len(langs) != 3:
    print("RESULT: incomplete")
    sys.exit(1)

common = set.intersection(*langs.values())
union = set.union(*langs.values())
drift = sorted(union - common)
if drift:
    print(f"  [FAIL] keys missing in some language(s): {', '.join(drift)}")
else:
    print(f"  [PASS] all {len(common)} keys present in en/ru/uk")

ui = set(re.findall(r'data-i(?:-ph|-aria)?="([^"]+)"', html))
missing = sorted(ui - common)
if missing:
    print(f"  [FAIL] UI keys without translation: {', '.join(missing)}")
else:
    print(f"  [PASS] all {len(ui)} data-i UI keys translated")

if re.search(r"t\('files', \{ count:", html):
    print("  [PASS] pluralised files counter uses vars")
else:
    print("  [FAIL] files counter does not use translation vars")

sys.exit(0 if not drift and not missing else 1)
PY
rc=$?
if [ $rc -eq 0 ]; then
  PASS=$((PASS + 3))
else
  FAIL=$((FAIL + 1))
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 9: PASSED" || echo "TEST 9: FAILED"
exit $FAIL
