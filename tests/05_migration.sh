#!/bin/bash
# Test 5: D1 migration SQL validity
set -e

PROJECT_DIR="/storage/emulated/0/Download/Worker/Droply"
MIGRATION="$PROJECT_DIR/migrations/0001_initial.sql"
PASS=0
FAIL=0

echo "=== TEST 5: D1 Migration SQL Validity ==="

if [ ! -f "$MIGRATION" ]; then
  echo "  [FAIL] migrations/0001_initial.sql missing"
  echo "TEST 5: FAILED"
  exit 1
fi

# Check for sessions table
if grep -qi 'CREATE TABLE.*sessions' "$MIGRATION"; then
  echo "  [PASS] sessions table defined"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] sessions table MISSING"
  FAIL=$((FAIL + 1))
fi

# Check for files table
if grep -qi 'CREATE TABLE.*files' "$MIGRATION"; then
  echo "  [PASS] files table defined"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] files table MISSING"
  FAIL=$((FAIL + 1))
fi

# Check for indexes
if grep -qi 'CREATE INDEX' "$MIGRATION"; then
  echo "  [PASS] indexes defined"
  PASS=$((PASS + 1))
else
  echo "  [WARN] no indexes defined"
fi

# Check for foreign key
if grep -qi 'FOREIGN KEY' "$MIGRATION"; then
  echo "  [PASS] foreign key constraint defined"
  PASS=$((PASS + 1))
else
  echo "  [WARN] no foreign key constraint"
fi

# Check for ON DELETE CASCADE
if grep -qi 'ON DELETE CASCADE' "$MIGRATION"; then
  echo "  [PASS] ON DELETE CASCADE present"
  PASS=$((PASS + 1))
else
  echo "  [WARN] no ON DELETE CASCADE"
fi

# Check column types
for col in 'id TEXT' 'created_at INTEGER' 'expires_at INTEGER' 'ttl_minutes INTEGER' 'creator_ip TEXT'; do
  if grep -qi "$col" "$MIGRATION"; then
    echo "  [PASS] column type: $col"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] column type MISSING: $col"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "TEST 5: PASSED" || echo "TEST 5: FAILED"
exit $FAIL
