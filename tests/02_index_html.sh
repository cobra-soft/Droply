#!/bin/bash
# Test 2: index.html is a self-contained all-in-one app (no React/Vite)
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
INDEX="$PROJECT_DIR/frontend/index.html"
PASS=0
FAIL=0

echo "=== TEST 2: index.html self-contained app ==="

if [ ! -f "$INDEX" ]; then
  echo "  [FAIL] frontend/index.html does not exist"
  echo "TEST 2: FAILED"
  exit 1
fi

has() {
  if grep -q "$1" "$INDEX"; then
    echo "  [PASS] $2"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $2"
    FAIL=$((FAIL + 1))
  fi
}

has_not() {
  if grep -q "$1" "$INDEX"; then
    echo "  [FAIL] $2"
    FAIL=$((FAIL + 1))
  else
    echo "  [PASS] $2"
    PASS=$((PASS + 1))
  fi
}

has '<title>' "contains <title>"
has '<style>' "contains inline <style>"
has '<script>' "contains inline <script>"
has '<svg class="sprite"' "contains inline SVG sprite"
has '<symbol id="i-' "sprite defines icon symbols"
has 'id="tpl-home"' "contains home template"
has 'id="tpl-session"' "contains session template"
has 'id="tpl-expired"' "contains expired template"
has "url('assets/" "fonts referenced from local assets/"

has_not 'id="root"' "no React #root mount"
has_not '/src/main.tsx' "no reference to /src/main.tsx"
has_not 'lucide' "no lucide runtime dependency"
has_not 'react' "no React code"
has_not 'src="http' "no external script CDN"
has_not 'href="http' "no external stylesheet CDN"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 2: PASSED" || echo "TEST 2: FAILED"
exit $FAIL
