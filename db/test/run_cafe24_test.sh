#!/usr/bin/env bash
# 로컬 MariaDB 에서 카페24 SQL 검증 (빈 DB 새로 만들어 실행). 금지 동작 확인 문장은 오류가 나야 정상.
set -euo pipefail
cd "$(dirname "$0")/.."
M=${MARIADB:-"mariadb --default-character-set=utf8mb4 -S /var/tmp/mdb/sock -u root"}
$M -e "drop database if exists sead_test; create database sead_test character set utf8mb4"
$M sead_test < cafe24/001_schema.sql
$M sead_test < cafe24/002_schema_sales_oem.sql
# 트리거는 스키마에서 다시 생성해 저장소 파일과 같은지 확인
python3 cafe24/gen_triggers.py --socket "${SOCK:-/var/tmp/mdb/sock}" --db sead_test > /tmp/_triggers.sql
diff -q /tmp/_triggers.sql cafe24/003_triggers.sql || { echo "003_triggers.sql 가 스키마와 다릅니다. gen_triggers.py 로 다시 만드세요."; }
for f in cafe24/003_triggers.sql cafe24/004_views.sql cafe24/005_procedures.sql cafe24/006_sales_oem.sql; do
  echo "== $f"; $M sead_test < "$f"
done
echo "== test/cafe24_flow_test.sql"
$M --force -t sead_test < test/cafe24_flow_test.sql 2>&1
echo "== test/cafe24_sales_test.sql"
$M --force -t sead_test < test/cafe24_sales_test.sql 2>&1
