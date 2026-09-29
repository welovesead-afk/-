-- =====================================================================
-- 판매·기타주문·개인정보 가림·OEM — 함수/뷰/프로시저 (Supabase 006_sales_oem.sql 과 같은 동작)
-- 대표/직원 구분은 app_role() (PHP가 SET @app_user_id 설정)
-- =====================================================================
SET NAMES utf8mb4;
DELIMITER $$

-- 마지막 낱말(이름)만 첫 글자 + ○   '중앙선관위 사무총장 허철훈' → '중앙선관위 사무총장 허○○'
CREATE FUNCTION mask_name(p VARCHAR(300)) RETURNS VARCHAR(300) DETERMINISTIC
BEGIN
  DECLARE t VARCHAR(300); DECLARE last_w VARCHAR(300);
  IF p IS NULL OR TRIM(p) = '' THEN RETURN p; END IF;
  SET t = TRIM(p);
  SET last_w = SUBSTRING_INDEX(t, ' ', -1);
  RETURN CONCAT(LEFT(t, CHAR_LENGTH(t) - CHAR_LENGTH(last_w)), LEFT(last_w, 1), REPEAT('○', GREATEST(CHAR_LENGTH(last_w) - 1, 1)));
END$$

CREATE FUNCTION mask_phone(p VARCHAR(50)) RETURNS VARCHAR(50) DETERMINISTIC
BEGIN
  IF p IS NULL THEN RETURN NULL; END IF;
  RETURN REGEXP_REPLACE(p, '([0-9]{2,3})[- ]?[0-9]{3,4}[- ]?([0-9]{4})', '\\1-****-\\2');
END$$

-- 판매 등록: 주문 + 품목 + 받는 사람 + (출고일 있으면) 선입선출 출고
CREATE PROCEDURE register_sale(IN p_order JSON, IN p_lines JSON, IN p_recipient JSON)
BEGIN
  DECLARE v_role VARCHAR(10); DECLARE v_id BIGINT; DECLARE v_no VARCHAR(20); DECLARE v_day DATE; DECLARE v_ship DATE;
  DECLARE v_partner BIGINT; DECLARE i INT DEFAULT 0; DECLARE n INT; DECLARE v_item BIGINT; DECLARE v_qty DECIMAL(14,3);
  DECLARE v_line BIGINT; DECLARE v_raw DECIMAL(14,3); DECLARE v_unmapped INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  CALL require_user(v_role);
  CALL warn_reset();
  IF p_lines IS NULL OR JSON_LENGTH(p_lines) = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '주문 품목이 없습니다.'; END IF;
  SET v_ship = NULLIF(JSON_VALUE(p_order, '$.ship_date'), '');
  SET v_day = COALESCE(v_ship, NULLIF(JSON_VALUE(p_order, '$.order_date'), ''), CURDATE());
  SET v_partner = NULLIF(JSON_VALUE(p_order, '$.channel_partner_id'), '');

  START TRANSACTION;
  SET v_no = next_no('S', v_day);
  INSERT INTO sales_orders (order_no, channel_type, channel_partner_id, order_date, ship_date, destination, delivery_method, writer, note)
  VALUES (v_no, JSON_VALUE(p_order, '$.channel_type'), v_partner, NULLIF(JSON_VALUE(p_order, '$.order_date'), ''), v_ship,
          JSON_VALUE(p_order, '$.destination'), JSON_VALUE(p_order, '$.delivery_method'), JSON_VALUE(p_order, '$.writer'),
          JSON_VALUE(p_order, '$.note'));
  SET v_id = LAST_INSERT_ID();

  IF p_recipient IS NOT NULL AND COALESCE(JSON_VALUE(p_recipient, '$.recipient_name'), JSON_VALUE(p_recipient, '$.recipient_org'),
                                          JSON_VALUE(p_recipient, '$.phone'), JSON_VALUE(p_recipient, '$.address')) IS NOT NULL THEN
    INSERT INTO sales_recipients (order_id, recipient_name, recipient_org, phone, address)
    VALUES (v_id, JSON_VALUE(p_recipient, '$.recipient_name'), JSON_VALUE(p_recipient, '$.recipient_org'),
            JSON_VALUE(p_recipient, '$.phone'), JSON_VALUE(p_recipient, '$.address'));
  END IF;

  SET n = JSON_LENGTH(p_lines);
  WHILE i < n DO
    SET v_item = NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].item_id')), '');
    SET v_qty = JSON_VALUE(p_lines, CONCAT('$[', i, '].qty'));
    INSERT INTO sales_lines (order_id, line_no, item_id, item_text, qty, unit, unit_price, supply_amount, vat, tax_type, shipping_fee, total, note)
    VALUES (v_id, i + 1, v_item,
            COALESCE(JSON_VALUE(p_lines, CONCAT('$[', i, '].item_text')), (SELECT name FROM items WHERE id = v_item)),
            v_qty, JSON_VALUE(p_lines, CONCAT('$[', i, '].unit')),
            NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].unit_price')), ''), NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].supply_amount')), ''),
            NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].vat')), ''), COALESCE(NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].tax_type')), ''), '미정'),
            NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].shipping_fee')), ''), NULLIF(JSON_VALUE(p_lines, CONCAT('$[', i, '].total')), ''),
            JSON_VALUE(p_lines, CONCAT('$[', i, '].note')));
    SET v_line = LAST_INSERT_ID();
    IF v_item IS NULL THEN
      SET v_unmapped = v_unmapped + 1;
    ELSEIF v_ship IS NOT NULL THEN
      CALL consume_fefo(v_item, v_qty, NULL, '출고', v_ship, v_partner, NULL, 'sales_lines', v_line, NULL, NULL, NULL, v_raw);
      UPDATE sales_lines SET shipped = 1 WHERE id = v_line;
    END IF;
    SET i = i + 1;
  END WHILE;
  IF v_unmapped > 0 THEN
    INSERT INTO _warn (msg) VALUES (CONCAT('품목이 확정되지 않은 줄 ', v_unmapped, '개는 재고 출고를 하지 않았습니다(품목 확정 후 출고).'));
  END IF;
  COMMIT;
  SELECT JSON_OBJECT('order_id', v_id, 'order_no', v_no, 'lines', n,
                     'warnings', (SELECT COALESCE(JSON_ARRAYAGG(msg), JSON_ARRAY()) FROM _warn)) AS result;
END$$

CREATE PROCEDURE ship_sales_line(IN p_line_id BIGINT, IN p_item_id BIGINT)
BEGIN
  DECLARE v_role VARCHAR(10); DECLARE v_qty DECIMAL(14,3); DECLARE v_shipped INT; DECLARE v_void INT;
  DECLARE v_ship DATE; DECLARE v_partner BIGINT; DECLARE v_raw DECIMAL(14,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  CALL require_user(v_role);
  CALL warn_reset();
  START TRANSACTION;
  SELECT l.qty, l.shipped, l.is_void, o.ship_date, o.channel_partner_id INTO v_qty, v_shipped, v_void, v_ship, v_partner
    FROM sales_lines l JOIN sales_orders o ON o.id = l.order_id WHERE l.id = p_line_id FOR UPDATE;
  IF v_qty IS NULL OR v_void THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '주문 품목 줄이 없거나 취소되었습니다.'; END IF;
  IF v_shipped THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '이미 출고 처리된 줄입니다.'; END IF;
  UPDATE sales_lines SET item_id = p_item_id WHERE id = p_line_id;
  CALL consume_fefo(p_item_id, v_qty, NULL, '출고', COALESCE(v_ship, CURDATE()), v_partner, NULL, 'sales_lines', p_line_id, NULL, NULL, NULL, v_raw);
  UPDATE sales_lines SET shipped = 1 WHERE id = p_line_id;
  COMMIT;
  SELECT JSON_OBJECT('line_id', p_line_id, 'warnings', (SELECT COALESCE(JSON_ARRAYAGG(msg), JSON_ARRAY()) FROM _warn)) AS result;
END$$

CREATE PROCEDURE void_sale(IN p_order_id BIGINT, IN p_reason TEXT)
BEGIN
  DECLARE v_role VARCHAR(10); DECLARE v_no VARCHAR(20); DECLARE v_void INT; DECLARE v_by INT; DECLARE v_at DATETIME;
  DECLARE v_line BIGINT; DECLARE v_done INT DEFAULT 0;
  DECLARE cur CURSOR FOR SELECT id FROM sales_lines WHERE order_id = p_order_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  CALL require_user(v_role);
  START TRANSACTION;
  SELECT order_no, is_void, created_by, created_at INTO v_no, v_void, v_by, v_at FROM sales_orders WHERE id = p_order_id FOR UPDATE;
  IF v_no IS NULL OR v_void THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소할 주문이 없거나 이미 취소되었습니다.'; END IF;
  IF NOT can_void(v_by, v_at) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.'; END IF;
  IF COALESCE(TRIM(p_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유를 입력하세요.'; END IF;
  OPEN cur;
  line_loop: LOOP
    FETCH cur INTO v_line;
    IF v_done THEN LEAVE line_loop; END IF;
    CALL reverse_moves('sales_lines', v_line, p_reason);
  END LOOP;
  CLOSE cur;
  UPDATE sales_lines SET is_void = 1, void_reason = p_reason WHERE order_id = p_order_id;
  UPDATE sales_recipients SET is_void = 1, void_reason = p_reason WHERE order_id = p_order_id;
  UPDATE sales_orders SET is_void = 1, void_reason = p_reason WHERE id = p_order_id;
  COMMIT;
  SELECT JSON_OBJECT('order_no', v_no, 'voided', TRUE) AS result;
END$$

DELIMITER ;

-- 주문 목록: 대표 = 원문, 직원 = 가린 값
CREATE OR REPLACE VIEW v_sales_list AS
SELECT o.id, o.order_no, o.channel_type, p.name AS channel_name, o.order_date, o.ship_date, o.destination,
       o.delivery_method, o.writer, o.note, o.is_void, o.void_reason,
       IF(app_role() = 'owner', r.recipient_name, mask_name(r.recipient_name)) AS recipient_name,
       r.recipient_org,
       IF(app_role() = 'owner', r.phone, mask_phone(r.phone)) AS phone,
       IF(app_role() = 'owner', r.address, IF(r.address IS NULL, NULL, CONCAT(SUBSTRING_INDEX(r.address, ' ', 1), ' …'))) AS address,
       (SELECT COUNT(*) FROM sales_lines l WHERE l.order_id = o.id AND l.is_void = 0)                        AS line_count,
       (SELECT SUM(l.qty) FROM sales_lines l WHERE l.order_id = o.id AND l.is_void = 0)                      AS qty_total,
       (SELECT SUM(COALESCE(l.total, l.supply_amount)) FROM sales_lines l WHERE l.order_id = o.id AND l.is_void = 0) AS amount_total,
       (SELECT COUNT(*) FROM sales_lines l WHERE l.order_id = o.id AND l.is_void = 0 AND l.item_id IS NULL)  AS unmapped_lines
  FROM sales_orders o
  LEFT JOIN partners p ON p.id = o.channel_partner_id
  LEFT JOIN sales_recipients r ON r.order_id = o.id AND r.is_void = 0
 WHERE app_role() IS NOT NULL;

CREATE OR REPLACE VIEW v_sales_monthly AS
SELECT DATE_FORMAT(COALESCE(o.ship_date, o.order_date), '%Y-%m-01') AS month,
       o.channel_type, p.name AS channel_name,
       COUNT(DISTINCT o.id) AS orders, SUM(l.qty) AS qty,
       SUM(COALESCE(l.total, l.supply_amount)) AS amount,
       SUM(l.total IS NULL AND l.supply_amount IS NULL) AS lines_without_amount
  FROM sales_orders o
  JOIN sales_lines l ON l.order_id = o.id AND l.is_void = 0
  LEFT JOIN partners p ON p.id = o.channel_partner_id
 WHERE o.is_void = 0
 GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW v_oem_items AS
SELECT i.id AS item_id, i.code, i.name, i.oem_type, p.name AS oem_partner, i.unit, s.stock_qty, i.safety_stock, s.below_safety
  FROM items i
  LEFT JOIN partners p ON p.id = i.oem_partner_id
  LEFT JOIN v_item_stock s ON s.item_id = i.id
 WHERE i.oem_type IS NOT NULL AND i.is_void = 0;
