#!/usr/bin/env bash
# 로컬 PostgreSQL 16 에서 Supabase SQL 검증 (빈 DB를 새로 만들어 실행)
set -euo pipefail
cd "$(dirname "$0")/.."
PSQL=${PSQL:-"psql -h /var/tmp/pgtest -p 5433 -U postgres"}
$PSQL -q -c "drop database if exists sead_test" -c "create database sead_test"
for f in test/supabase_stub.sql supabase/0*.sql test/supabase_flow_test.sql; do
  echo "== $f"
  $PSQL -d sead_test -v ON_ERROR_STOP=1 -q -f "$f"
done
