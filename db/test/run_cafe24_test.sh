#!/usr/bin/env bash
# 로컬 MariaDB 에서 카페24 SQL 검증 (빈 DB 새로 만들어 실행). 금지 동작 확인 문장은 오류가 나야 정상.
set -euo pipefail
cd "$(dirname "$0")/.."
M=${MARIADB:-"mariadb --default-character-set=utf8mb4 -S /var/tmp/mdb/sock -u root"}
$M -e "drop database if exists sead_test; create database sead_test character set utf8mb4"
for f in cafe24/001_schema.sql cafe24/002_triggers.sql cafe24/003_views.sql cafe24/004_procedures.sql; do
  echo "== $f"; $M sead_test < "$f"
done
echo "== test/cafe24_flow_test.sql"
$M --force -t sead_test < test/cafe24_flow_test.sql 2>&1
