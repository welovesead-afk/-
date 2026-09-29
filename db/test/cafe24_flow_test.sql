SET NAMES utf8mb4;
-- 로컬 검증 시나리오 (카페24 MariaDB) — supabase_flow_test.sql 과 같은 흐름
INSERT INTO app_users (login_id, name, password_hash, role) VALUES ('owner','대표','x','owner'), ('staff','직원A','x','staff');

-- 대표
SET @app_user_id = 1;
INSERT INTO partners (code, name, biz_no, is_supplier, category) VALUES
  ('P-0001','기장해초생상자영업인','160-86-01232',1,'원물생산자'),
  ('P-0002','금호산업 주식회사','615-81-90282',1,'포장재');
INSERT INTO items (code, name, item_type, unit, shelf_life_months, origin, safety_stock) VALUES
  ('RM-01','자연건조미역(기장산)','RAW','kg',36,'부산 기장군',20),
  ('RM-SCRAP','미역 자투리(20cm 이하)','RAW','kg',36,'부산 기장군',0);
INSERT INTO items (code, name, item_type, pack_kind, unit, size, safety_stock) VALUES
  ('PK-W-01','150g 무지포장지','PACK','포장지','ea','24*34',500),
  ('PK-B-22','기장미역 150g IN box','PACK','박스','ea',NULL,100);
INSERT INTO items (code, name, item_type, unit, spec, net_weight_g, shelf_life_months, safety_stock) VALUES
  ('SP-02','기장미역150g (무지)','SEMI','ea','150g',150,36,50),
  ('SP-03','기장미역150g(박스)','SEMI','ea','150g',150,36,30);
INSERT INTO item_units (item_id, unit, factor) SELECT id, '묶음', 10 FROM items WHERE code = 'RM-01';
INSERT INTO bom (parent_item_id, child_item_id, qty_per, step, sort)
SELECT p.id, c.id, v.q, v.st, v.s FROM (
  SELECT 'SP-02' pc, 'RM-01' cc, 0.150 q, '내포장' st, 1 s UNION ALL SELECT 'SP-02','PK-W-01',1,'내포장',2
  UNION ALL SELECT 'SP-03','SP-02',1,'외포장',1 UNION ALL SELECT 'SP-03','PK-B-22',1,'외포장',2) v
JOIN items p ON p.code = v.pc JOIN items c ON c.code = v.cc;
INSERT INTO production_standards (item_id, step, std_yield_pct, std_sec_per_ea, bulk_unit_kg, sample_count, source)
SELECT id, '내포장', 97.5, 208, 10, 1, '생산동향 기록표 2026-07-21' FROM items WHERE code = 'SP-02';

CALL register_move((SELECT id FROM items WHERE code='PK-W-01'), 1000, '기초', '2026-09-01', NULL, NULL, '기초재고', 0, NULL, NULL);
CALL register_move((SELECT id FROM items WHERE code='PK-B-22'), 40, '기초', '2026-09-01', NULL, NULL, '기초재고', 0, NULL, NULL);

-- 직원
SET @app_user_id = 2;
CALL register_receipt((SELECT id FROM items WHERE code='RM-01'), 1, '2026-09-10', '묶음', NULL, (SELECT id FROM partners WHERE code='P-0001'), '2026-04-20', NULL, NULL, NULL, NULL);
CALL register_receipt((SELECT id FROM items WHERE code='RM-01'), 5, '2026-09-20', 'kg', NULL, (SELECT id FROM partners WHERE code='P-0001'), '2026-05-02', NULL, NULL, NULL, NULL);
CALL register_production((SELECT id FROM items WHERE code='SP-02'), 65, '2026-09-25', NULL,
  '[{"step_name":"절단·소분","input_kg":10,"output_kg":9.75,"loss_kg":0.05,"scrap_kg":0.2,"loss_reason":"절단 자투리"}]',
  0, 1, '[{"start":"08:30","end":"12:10"}]', NULL, NULL, NULL);
CALL register_production((SELECT id FROM items WHERE code='SP-03'), 30, '2026-09-26', NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL);
CALL register_move((SELECT id FROM items WHERE code='SP-03'), 5, '출고', '2026-09-27', NULL, NULL, NULL, 0, NULL, NULL);

SELECT '--- 품목별 현재고' AS '';
SELECT code, name, stock_qty, safety_stock, below_safety FROM v_item_stock ORDER BY code;
SELECT '--- 로트별 재고' AS '';
SELECT lot_no, code, stock_qty, dried_date, expiry_date, mixed_dried_dates FROM v_lot_stock ORDER BY lot_no;
SELECT '--- 이번 달 수율' AS '';
SELECT month, code, runs, input_kg, output_kg, yield_pct, std_yield_pct, yield_gap_pct, work_minutes FROM v_monthly_yield ORDER BY code;

SELECT '--- 금지 동작' AS '';
-- 아래 문장들은 오류가 나야 정상 (run 스크립트가 --force 로 계속 진행)
DELETE FROM items WHERE code = 'RM-01';
UPDATE stock_moves SET qty = 1 WHERE id = 1;
UPDATE receipts SET qty = 999 WHERE id = 1;
CALL register_move(1, 1, '조정', NULL, NULL, NULL, '테스트', 0, NULL, NULL);
CALL void_receipt(1, '수량 오기');

SET @app_user_id = 1;
CALL void_production((SELECT id FROM production_logs WHERE log_no LIKE 'W-260926-%'), '테스트');
CALL register_receipt((SELECT id FROM items WHERE code='RM-01'), 2, '2026-09-28', 'kg', NULL, NULL, '2026-05-10', NULL, NULL, NULL, NULL);
CALL void_receipt((SELECT MAX(id) FROM receipts), '중복 입력');

SELECT '--- 재고 부족 생산 → 취소' AS '';
CALL register_production((SELECT id FROM items WHERE code='SP-02'), 40, '2026-09-28', NULL,
  '[{"step_name":"절단·소분","input_kg":6.2,"output_kg":6.0,"loss_kg":0.2}]', 0, NULL, NULL, NULL, NULL, NULL);
CALL void_production((SELECT id FROM production_logs WHERE log_no LIKE 'W-260928-%'), '재고 부족 테스트 취소');
SELECT code, stock_qty FROM v_item_stock WHERE code IN ('RM-01','SP-02','PK-W-01') ORDER BY code;

SELECT '--- 수정 이력' AS '';
SELECT table_name, action, COUNT(*) FROM audit_log GROUP BY 1, 2 ORDER BY 1, 2;
