# 데이터베이스 (1단계: 기준정보 + 입고·생산·재고·로트)

같은 설계를 두 저장소에 만들어 비교합니다. 테이블·컬럼·뷰 이름과 업무 처리 결과가 같습니다
(로컬 테스트에서 같은 시나리오의 재고·로트·수율 결과가 일치함을 확인).

| | Supabase (PostgreSQL) | 카페24 (MariaDB) |
|---|---|---|
| 파일 | `supabase/001~005` | `cafe24/001~004` |
| 로그인 | Supabase Auth (`profiles`) | `app_users` + PHP 세션 (`SET @app_user_id`) |
| 업무 처리 | 함수 `select register_receipt(...)` | 프로시저 `CALL register_receipt(...)` |
| 권한 | RLS: 조회=활성 사용자, 기준정보 쓰기=대표, 거래는 함수로만 | PHP API에서 역할 확인 + 프로시저 내부 확인 |
| 삭제 금지 | 트리거 + 권한 회수 (TRUNCATE 포함) | 트리거 (TRUNCATE는 트리거로 막을 수 없음 → PHP에서 미사용) |

## 테이블

| 테이블 | 내용 |
|---|---|
| `items` | 품목. `item_type`: RAW 원재료 / SUB 부재료 / PACK 포장재 / SEMI 반제품 / FG 완제품 |
| `item_units` | 단위 환산 (예: 건미역 1묶음 = 10kg, 하트미역 1롤 = 4,000개) |
| `item_suppliers`, `item_aliases` | 품목별 공급처·단가, 다른 파일의 표기 |
| `bom` | 상위 1개당 하위 소요량 (`loss_rate`, 대체품 `alt_group`) |
| `partners`, `partner_aliases` | 거래처 (사업자번호 중복 불가) |
| `production_standards` | 표준 수율·초/개 (임시값 표시) |
| `lots` | 로트. 건조일 → 소비기한 자동, 생산 로트는 가장 이른 건조일 상속 |
| `lot_links` | 투입 로트 → 생산 로트 (원물까지 역추적) |
| `receipts` | 입고 |
| `production_logs` / `production_steps` / `production_inputs` | 생산일지 / 단계별 중량(수율 자동) / 로트별 투입 |
| `stock_moves` | 재고 원장 — 추가만 가능, 현재고 = 합계 |
| `audit_log` | 수정 이력 — 누가·언제·전/후 값 |

뷰: `v_item_stock`(현재고), `v_lot_stock`(로트 재고·잔여 소비기한), `v_safety_shortage`(안전재고 미달),
`v_monthly_yield`(월별 제품 수율, 표준 대비), `v_production_list`, `v_receipt_list`. Supabase는 `lot_trace(lot_no)` 추가.

## 규칙
- 삭제 불가. 잘못 입력한 입고·생산은 **취소**(사유 필수) → 반대 재고 이동이 자동으로 추가됨
- 직원은 당일 본인 기록만 취소, 대표는 모두. 이미 다음 공정·출고에 쓰인 로트는 사용 기록부터 취소
- 재고가 모자라도 저장은 되고 경고를 돌려줌(로트 없이 차감) — 초기 재고가 부정확한 기간을 위한 설정
- 재고 조정·기초재고 입력은 대표만

## 적용 방법
**Supabase**: 프로젝트(지역 Seoul) → SQL Editor 에 `supabase/001` ~ `005` 를 순서대로 붙여넣어 실행.
**카페24**: 호스팅 관리 → DB 관리(phpMyAdmin) → SQL 가져오기로 `cafe24/001` ~ `004` 를 순서대로 실행.
`002_triggers.sql` 은 생성 파일입니다. 테이블을 바꾸면 `python3 cafe24/gen_triggers.py` 로 다시 만드세요.

## 로컬 테스트
```bash
db/test/run_supabase_test.sh   # PostgreSQL 16 (Supabase auth 흉내)
db/test/run_cafe24_test.sh     # MariaDB 10.11
```
