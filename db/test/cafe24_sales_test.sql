SET NAMES utf8mb4;
-- 판매·기타주문·개인정보·OEM 검증 (cafe24_flow_test.sql 다음) — supabase_sales_test.sql 과 같은 흐름
SET @app_user_id = 1;
INSERT INTO partners (code, name, is_customer, category) VALUES
  ('C-0001','주식회사 아난티',1,'B2B'), ('C-0002','중앙선거관리위원회',1,'B2G'),
  ('C-0003','전화 및 기타 주문',1,'기타'), ('C-0004','주식회사 와이즐리컴퍼니',1,'OEM');
INSERT INTO items (code, name, item_type, unit, oem_type, oem_partner_id)
SELECT 'OEM-WZ-01','와이즐리 자른미역 200g','FG','ea','OEM납품', id FROM partners WHERE code = 'C-0004';
UPDATE items SET oem_type = 'OEM매입' WHERE code = 'PK-B-22';

SET @anati = (SELECT id FROM partners WHERE code='C-0001'), @nec = (SELECT id FROM partners WHERE code='C-0002'),
    @etc = (SELECT id FROM partners WHERE code='C-0003'), @sp03 = (SELECT id FROM items WHERE code='SP-03');
CALL register_sale(JSON_OBJECT('channel_type','기업','channel_partner_id',@anati,'order_date','2026-09-28','ship_date','2026-09-28','destination','아난티코브 모비딕마켓','writer','정지영'),
                   JSON_ARRAY(JSON_OBJECT('item_id',@sp03,'item_text','기장미역150g 박스','qty',3,'unit','EA','unit_price',10000,'supply_amount',30000,'vat',0,'tax_type','면세','total',30000)), NULL);
CALL register_sale(JSON_OBJECT('channel_type','개인','channel_partner_id',@nec,'order_date','2026-09-28','ship_date','2026-09-29','delivery_method','택배'),
                   JSON_ARRAY(JSON_OBJECT('item_id',@sp03,'qty',1,'unit_price',34000,'total',34000)),
                   JSON_OBJECT('recipient_name','중앙선관위 사무총장 허철훈','recipient_org','중앙선관위','phone','010-1234-5678','address','경기도 과천시 홍촌말로 44'));
CALL register_sale(JSON_OBJECT('channel_type','기타주문','channel_partner_id',@etc,'order_date','2026-09-29','ship_date','2026-09-29'),
                   '[{"item_text":"한끼용 기장미역20G","qty":30},{"item_text":"부산바다선물세트","qty":1}]', JSON_OBJECT('recipient_name','여가거가'));

SELECT '--- 대표가 보는 주문 목록' AS '';
SELECT order_no, channel_type, channel_name, recipient_name, phone, address, line_count, amount_total, unmapped_lines FROM v_sales_list ORDER BY order_no;
SET @app_user_id = 2;
SELECT '--- 직원이 보는 주문 목록' AS '';
SELECT order_no, channel_type, recipient_name, phone, address FROM v_sales_list ORDER BY order_no;
CALL ship_sales_line((SELECT id FROM sales_lines WHERE item_text = '한끼용 기장미역20G'), (SELECT id FROM items WHERE code='SP-02'));
SELECT '--- 월별 판매 집계' AS '';
SELECT month, channel_type, channel_name, orders, qty, amount, lines_without_amount FROM v_sales_monthly ORDER BY channel_type;
SELECT '--- OEM 품목' AS '';
SELECT code, name, oem_type, oem_partner FROM v_oem_items ORDER BY code;
SET @app_user_id = 1;
SELECT stock_qty AS sp03_before FROM v_item_stock WHERE code = 'SP-03';
CALL void_sale((SELECT id FROM sales_orders WHERE channel_type = '기업'), '테스트 취소');
SELECT stock_qty AS sp03_after FROM v_item_stock WHERE code = 'SP-03';
SELECT mask_name('중앙선관위 사무총장 허철훈') a, mask_name('여가거가') b, mask_name('김') c, mask_phone('010-1234-5678') d;
SELECT '--- 금지: 출고된 줄 수량 수정 / 주문 삭제' AS '';
UPDATE sales_lines SET qty = 99 WHERE item_text = '한끼용 기장미역20G';
DELETE FROM sales_orders WHERE channel_type = '개인';
