SET NAMES utf8mb4;
-- =====================================================================
-- 업무 처리 프로시저 — Supabase 함수(003_functions.sql)와 같은 동작
--   CALL register_receipt(...)     입고 → 로트 + 재고 증가
--   CALL register_production(...)  생산 → BOM 자동 차감(선입선출) + 생산 로트 + 수율
--   CALL register_move(...)        출고·조정·폐기·기초
--   CALL void_receipt / void_production  취소(반대 기록)
-- 호출 전 PHP가 SET @app_user_id = <로그인 사용자 id>; 설정
-- 결과: 마지막 SELECT 한 줄(JSON)
-- =====================================================================
DELIMITER $$

CREATE FUNCTION app_role() RETURNS VARCHAR(10) READS SQL DATA
BEGIN
  RETURN (SELECT role FROM app_users WHERE id = @app_user_id AND active = 1);
END$$

CREATE PROCEDURE require_user(OUT p_role VARCHAR(10))
BEGIN
  SET p_role = app_role();
  IF p_role IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '로그인이 필요하거나 사용이 중지된 계정입니다.';
  END IF;
END$$

CREATE FUNCTION next_no(p_prefix VARCHAR(40), p_day DATE) RETURNS VARCHAR(60) MODIFIES SQL DATA
BEGIN
  DECLARE v INT;
  INSERT INTO doc_counters (prefix, day, last_no) VALUES (p_prefix, p_day, 1)
    ON DUPLICATE KEY UPDATE last_no = last_no + 1;
  SELECT last_no INTO v FROM doc_counters WHERE prefix = p_prefix AND day = p_day;
  RETURN CONCAT(p_prefix, '-', DATE_FORMAT(p_day, '%y%m%d'), '-', LPAD(v, 2, '0'));
END$$

CREATE FUNCTION to_base_qty(p_item_id BIGINT, p_qty DECIMAL(14,3), p_unit VARCHAR(10)) RETURNS DECIMAL(14,3) READS SQL DATA
BEGIN
  DECLARE v_base VARCHAR(10); DECLARE v_factor DECIMAL(14,4);
  SELECT unit INTO v_base FROM items WHERE id = p_item_id;
  IF v_base IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '품목이 없습니다.'; END IF;
  IF p_unit IS NULL OR p_unit = '' OR p_unit = v_base THEN RETURN p_qty; END IF;
  SELECT factor INTO v_factor FROM item_units WHERE item_id = p_item_id AND unit = p_unit AND is_void = 0;
  IF v_factor IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력 단위를 기본단위로 환산할 수 없습니다. 품목 단위환산(item_units)을 등록하세요.';
  END IF;
  RETURN p_qty * v_factor;
END$$

CREATE FUNCTION lot_balance(p_lot_id BIGINT) RETURNS DECIMAL(14,3) READS SQL DATA
BEGIN
  RETURN (SELECT COALESCE(SUM(qty), 0) FROM stock_moves WHERE lot_id = p_lot_id);
END$$

-- 점심(11:30~12:30) 제외 작업시간(분)
CREATE FUNCTION work_minutes(p_segments JSON) RETURNS INT DETERMINISTIC
BEGIN
  DECLARE i INT DEFAULT 0; DECLARE n INT; DECLARE v_total INT DEFAULT 0;
  DECLARE v_s TIME; DECLARE v_e TIME;
  IF p_segments IS NULL OR JSON_TYPE(p_segments) <> 'ARRAY' THEN RETURN NULL; END IF;
  SET n = JSON_LENGTH(p_segments);
  WHILE i < n DO
    SET v_s = JSON_UNQUOTE(JSON_EXTRACT(p_segments, CONCAT('$[', i, '].start')));
    SET v_e = JSON_UNQUOTE(JSON_EXTRACT(p_segments, CONCAT('$[', i, '].end')));
    IF v_s IS NOT NULL AND v_e IS NOT NULL AND v_e > v_s THEN
      SET v_total = v_total + TIMESTAMPDIFF(MINUTE, v_s, v_e)
                  - GREATEST(0, TIMESTAMPDIFF(MINUTE, GREATEST(v_s, TIME '11:30'), LEAST(v_e, TIME '12:30')));
    END IF;
    SET i = i + 1;
  END WHILE;
  RETURN v_total;
END$$

-- 경고 모음(프로시저 내부용)
CREATE PROCEDURE warn_reset()
BEGIN
  CREATE TEMPORARY TABLE IF NOT EXISTS _warn (id INT AUTO_INCREMENT PRIMARY KEY, msg TEXT);
  DELETE FROM _warn;
END$$

-- 선입선출 차감: 소비기한(없으면 건조일·입고일) 빠른 로트부터 감소 이동 기록
--  p_log_id / p_child_lot 이 있으면 production_inputs·lot_links 도 기록
CREATE PROCEDURE consume_fefo(
  IN p_item_id BIGINT, IN p_qty DECIMAL(14,3), IN p_lot_id BIGINT, IN p_move_type VARCHAR(10), IN p_date DATE,
  IN p_partner_id BIGINT, IN p_reason TEXT, IN p_ref_type VARCHAR(30), IN p_ref_id BIGINT,
  IN p_log_id BIGINT, IN p_child_lot BIGINT, IN p_planned DECIMAL(14,3), OUT p_raw_kg DECIMAL(14,3))
BEGIN
  DECLARE v_left DECIMAL(14,3) DEFAULT p_qty;
  DECLARE v_take DECIMAL(14,3);
  DECLARE v_lot BIGINT; DECLARE v_bal DECIMAL(14,3);
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_first INT DEFAULT 1;
  DECLARE v_is_raw_kg INT;
  DECLARE cur CURSOR FOR
    SELECT l.id, b.qty FROM lots l
      JOIN (SELECT lot_id, SUM(qty) qty FROM stock_moves WHERE item_id = p_item_id AND lot_id IS NOT NULL GROUP BY lot_id) b
        ON b.lot_id = l.id
     WHERE l.item_id = p_item_id AND l.is_void = 0 AND b.qty > 0
     ORDER BY COALESCE(l.expiry_date, l.dried_date, l.made_on) IS NULL, COALESCE(l.expiry_date, l.dried_date, l.made_on), l.id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  SELECT (item_type = 'RAW' AND unit = 'kg') INTO v_is_raw_kg FROM items WHERE id = p_item_id;
  SET p_raw_kg = IF(v_is_raw_kg, p_qty, 0);

  IF p_lot_id IS NOT NULL THEN
    INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id, reason)
    VALUES (p_date, p_item_id, p_lot_id, -p_qty, p_move_type, p_partner_id, p_ref_type, p_ref_id, p_reason);
    IF p_log_id IS NOT NULL THEN
      INSERT INTO production_inputs (log_id, item_id, lot_id, planned_qty, actual_qty) VALUES (p_log_id, p_item_id, p_lot_id, p_planned, p_qty);
      INSERT INTO lot_links (parent_lot_id, child_lot_id, production_log_id, qty_used) VALUES (p_lot_id, p_child_lot, p_log_id, p_qty);
    END IF;
    IF lot_balance(p_lot_id) < 0 THEN
      INSERT INTO _warn (msg) SELECT CONCAT('로트 ', lot_no, ' 재고가 음수가 되었습니다.') FROM lots WHERE id = p_lot_id;
    END IF;
    SET v_left = 0;
  ELSE
    OPEN cur;
    fefo: LOOP
      IF v_left <= 0 THEN LEAVE fefo; END IF;
      FETCH cur INTO v_lot, v_bal;
      IF v_done THEN LEAVE fefo; END IF;
      SET v_take = LEAST(v_bal, v_left);
      INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id, reason)
      VALUES (p_date, p_item_id, v_lot, -v_take, p_move_type, p_partner_id, p_ref_type, p_ref_id, p_reason);
      IF p_log_id IS NOT NULL THEN
        INSERT INTO production_inputs (log_id, item_id, lot_id, planned_qty, actual_qty)
        VALUES (p_log_id, p_item_id, v_lot, IF(v_first, p_planned, NULL), v_take);
        INSERT INTO lot_links (parent_lot_id, child_lot_id, production_log_id, qty_used) VALUES (v_lot, p_child_lot, p_log_id, v_take);
      END IF;
      SET v_first = 0;
      SET v_left = v_left - v_take;
    END LOOP;
    CLOSE cur;
  END IF;

  IF v_left > 0 THEN
    INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id, reason)
    VALUES (p_date, p_item_id, NULL, -v_left, p_move_type, p_partner_id, p_ref_type, p_ref_id, p_reason);
    IF p_log_id IS NOT NULL THEN
      INSERT INTO production_inputs (log_id, item_id, lot_id, planned_qty, actual_qty)
      VALUES (p_log_id, p_item_id, NULL, IF(v_first, p_planned, NULL), v_left);
    END IF;
    INSERT INTO _warn (msg)
    SELECT CONCAT(name, ' 재고 부족: ', v_left, ' ', unit, ' 을(를) 로트 없이 차감했습니다.') FROM items WHERE id = p_item_id;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 입고 등록
-- ---------------------------------------------------------------------
CREATE PROCEDURE register_receipt(
  IN p_item_id BIGINT, IN p_qty DECIMAL(14,3), IN p_received_on DATE, IN p_unit VARCHAR(10), IN p_lot_no VARCHAR(40),
  IN p_partner_id BIGINT, IN p_dried_date DATE, IN p_expiry_date DATE, IN p_bulk_count DECIMAL(10,2),
  IN p_unit_price DECIMAL(14,2), IN p_note TEXT)
BEGIN
  DECLARE v_role VARCHAR(10);
  DECLARE v_type VARCHAR(4); DECLARE v_unit VARCHAR(10); DECLARE v_base DECIMAL(14,3);
  DECLARE v_lot_id BIGINT; DECLARE v_lot_item BIGINT; DECLARE v_lot_void INT; DECLARE v_lot_no VARCHAR(40);
  DECLARE v_receipt_id BIGINT; DECLARE v_receipt_no VARCHAR(20); DECLARE v_dried DATE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  CALL require_user(v_role);
  CALL warn_reset();
  SET p_received_on = COALESCE(p_received_on, CURDATE());
  SELECT item_type, unit INTO v_type, v_unit FROM items WHERE id = p_item_id AND is_void = 0;
  IF v_type IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '품목을 찾을 수 없습니다.'; END IF;
  IF p_qty IS NULL OR p_qty <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '수량은 0보다 커야 합니다.'; END IF;
  SET v_unit = COALESCE(NULLIF(TRIM(p_unit), ''), v_unit);

  START TRANSACTION;
  SET v_base = to_base_qty(p_item_id, p_qty, v_unit);

  IF NULLIF(TRIM(p_lot_no), '') IS NOT NULL THEN
    SELECT id, item_id, is_void, lot_no INTO v_lot_id, v_lot_item, v_lot_void, v_lot_no FROM lots WHERE lot_no = TRIM(p_lot_no);
    IF v_lot_id IS NOT NULL THEN
      IF v_lot_item <> p_item_id THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '다른 품목의 로트번호입니다.'; END IF;
      IF v_lot_void THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 로트번호입니다.'; END IF;
      INSERT INTO _warn (msg) VALUES (CONCAT('기존 로트 ', v_lot_no, '에 수량을 추가했습니다.'));
    END IF;
  END IF;

  IF v_lot_id IS NULL THEN
    SET v_lot_no = COALESCE(NULLIF(TRIM(p_lot_no), ''),
                            next_no(CASE v_type WHEN 'RAW' THEN 'RM' WHEN 'SUB' THEN 'BY' WHEN 'PACK' THEN 'PK' ELSE 'GR' END, p_received_on));
    INSERT INTO lots (lot_no, item_id, source, dried_date, expiry_date, made_on)
    VALUES (v_lot_no, p_item_id, '입고', p_dried_date, p_expiry_date, p_received_on);
    SET v_lot_id = LAST_INSERT_ID();
  END IF;

  SELECT dried_date INTO v_dried FROM lots WHERE id = v_lot_id;
  IF v_type = 'RAW' AND v_dried IS NULL THEN
    INSERT INTO _warn (msg) VALUES ('원재료 건조일이 비어 있어 소비기한을 계산하지 못했습니다.');
  END IF;

  SET v_receipt_no = next_no('R', p_received_on);
  INSERT INTO receipts (receipt_no, received_on, item_id, partner_id, qty, unit, base_qty, bulk_count, unit_price, lot_id, note)
  VALUES (v_receipt_no, p_received_on, p_item_id, p_partner_id, p_qty, v_unit, v_base, p_bulk_count, p_unit_price, v_lot_id, p_note);
  SET v_receipt_id = LAST_INSERT_ID();
  UPDATE lots SET receipt_id = v_receipt_id WHERE id = v_lot_id AND receipt_id IS NULL;

  INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id)
  VALUES (p_received_on, p_item_id, v_lot_id, v_base, '입고', p_partner_id, 'receipts', v_receipt_id);
  COMMIT;

  SELECT JSON_OBJECT('receipt_id', v_receipt_id, 'receipt_no', v_receipt_no, 'lot_id', v_lot_id, 'lot_no', v_lot_no,
                     'base_qty', v_base,
                     'warnings', (SELECT COALESCE(JSON_ARRAYAGG(msg), JSON_ARRAY()) FROM _warn)) AS result;
END$$

-- ---------------------------------------------------------------------
-- 생산일지 등록 (p_inputs: NULL = BOM 자동 / [{"item_id":..,"qty":..,"lot_id":..}])
-- ---------------------------------------------------------------------
CREATE PROCEDURE register_production(
  IN p_product_id BIGINT, IN p_output_qty DECIMAL(14,3), IN p_work_date DATE, IN p_inputs JSON, IN p_steps JSON,
  IN p_defect_qty DECIMAL(14,3), IN p_workers INT, IN p_segments JSON, IN p_issues TEXT, IN p_suggestion TEXT, IN p_note TEXT)
BEGIN
  DECLARE v_role VARCHAR(10);
  DECLARE v_type VARCHAR(4); DECLARE v_code VARCHAR(30); DECLARE v_net DECIMAL(12,3); DECLARE v_shelf INT;
  DECLARE v_log_id BIGINT; DECLARE v_log_no VARCHAR(20); DECLARE v_lot_id BIGINT; DECLARE v_lot_no VARCHAR(40);
  DECLARE i INT DEFAULT 0; DECLARE n INT;
  DECLARE v_item BIGINT; DECLARE v_qty DECIMAL(14,3); DECLARE v_lot BIGINT; DECLARE v_planned DECIMAL(14,3);
  DECLARE v_raw DECIMAL(14,3); DECLARE v_raw_kg DECIMAL(14,3) DEFAULT 0;
  DECLARE v_min_dried DATE; DECLARE v_min_exp DATE; DECLARE v_dcnt INT;
  DECLARE v_scrap DECIMAL(12,3) DEFAULT 0; DECLARE v_scrap_item BIGINT; DECLARE v_scrap_lot BIGINT;
  DECLARE v_done INT DEFAULT 0;
  DECLARE cur CURSOR FOR SELECT item_id, planned, qty, lot_id FROM _need WHERE qty > 0 ORDER BY id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  CALL require_user(v_role);
  CALL warn_reset();
  SET p_work_date = COALESCE(p_work_date, CURDATE());
  SELECT item_type, code, net_weight_g, shelf_life_months INTO v_type, v_code, v_net, v_shelf
    FROM items WHERE id = p_product_id AND is_void = 0;
  IF v_type IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '생산 제품을 찾을 수 없습니다.'; END IF;
  IF v_type NOT IN ('SEMI','FG') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '반제품·완제품만 생산 등록할 수 있습니다.'; END IF;
  IF p_output_qty IS NULL OR p_output_qty <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '산출 수량은 0보다 커야 합니다.'; END IF;

  START TRANSACTION;
  SET v_log_no = next_no('W', p_work_date);
  INSERT INTO production_logs (log_no, work_date, product_item_id, output_qty, defect_qty, workers, segments, work_minutes, issues, suggestion, note)
  VALUES (v_log_no, p_work_date, p_product_id, p_output_qty, COALESCE(p_defect_qty, 0), p_workers, p_segments,
          work_minutes(p_segments), p_issues, p_suggestion, p_note);
  SET v_log_id = LAST_INSERT_ID();

  -- 1) 투입 목록
  CREATE TEMPORARY TABLE IF NOT EXISTS _need (id INT AUTO_INCREMENT PRIMARY KEY, item_id BIGINT, planned DECIMAL(14,3), qty DECIMAL(14,3), lot_id BIGINT);
  DELETE FROM _need;
  IF p_inputs IS NULL OR JSON_LENGTH(p_inputs) = 0 THEN
    INSERT INTO _need (item_id, planned, qty)
    SELECT b.child_item_id, ROUND(b.qty_per * p_output_qty * (1 + b.loss_rate / 100), 3), ROUND(b.qty_per * p_output_qty * (1 + b.loss_rate / 100), 3)
      FROM bom b
     WHERE b.parent_item_id = p_product_id AND b.is_void = 0
       AND b.id = (SELECT b2.id FROM bom b2 WHERE b2.parent_item_id = b.parent_item_id AND b2.is_void = 0
                      AND COALESCE(b2.alt_group, CONCAT('#', b2.id)) = COALESCE(b.alt_group, CONCAT('#', b.id))
                    ORDER BY b2.sort, b2.id LIMIT 1)
     ORDER BY b.sort, b.id;
    IF ROW_COUNT() = 0 THEN INSERT INTO _warn (msg) VALUES ('이 제품의 BOM(구성)이 없어 투입 차감을 하지 않았습니다.'); END IF;
    IF p_steps IS NOT NULL AND JSON_LENGTH(p_steps) > 0 AND JSON_EXTRACT(p_steps, '$[0].input_kg') IS NOT NULL
       AND (SELECT COUNT(*) FROM _need nn JOIN items it ON it.id = nn.item_id WHERE it.item_type = 'RAW' AND it.unit = 'kg') = 1 THEN
      UPDATE _need nn JOIN items it ON it.id = nn.item_id
         SET nn.qty = JSON_VALUE(p_steps, '$[0].input_kg')
       WHERE it.item_type = 'RAW' AND it.unit = 'kg';
    END IF;
  ELSE
    SET n = JSON_LENGTH(p_inputs);
    WHILE i < n DO
      SET v_item = JSON_VALUE(p_inputs, CONCAT('$[', i, '].item_id'));
      SET v_planned = NULL;
      SELECT ROUND(qty_per * p_output_qty * (1 + loss_rate / 100), 3) INTO v_planned
        FROM bom WHERE parent_item_id = p_product_id AND child_item_id = v_item AND is_void = 0;
      INSERT INTO _need (item_id, planned, qty, lot_id)
      VALUES (v_item, v_planned, JSON_VALUE(p_inputs, CONCAT('$[', i, '].qty')), NULLIF(JSON_VALUE(p_inputs, CONCAT('$[', i, '].lot_id')), 'null'));
      SET i = i + 1;
    END WHILE;
  END IF;

  -- 2) 생산 로트
  SET v_lot_no = next_no(CONCAT(IF(v_type = 'SEMI', 'IP-', 'FP-'), v_code), p_work_date);
  INSERT INTO lots (lot_no, item_id, source, made_on, production_log_id) VALUES (v_lot_no, p_product_id, '생산', p_work_date, v_log_id);
  SET v_lot_id = LAST_INSERT_ID();

  -- 3) 투입 차감
  SET v_done = 0;
  OPEN cur;
  inputs: LOOP
    FETCH cur INTO v_item, v_planned, v_qty, v_lot;
    IF v_done THEN LEAVE inputs; END IF;
    CALL consume_fefo(v_item, v_qty, v_lot, '생산투입', p_work_date, NULL, NULL, 'production_logs', v_log_id,
                      v_log_id, v_lot_id, v_planned, v_raw);
    SET v_raw_kg = v_raw_kg + v_raw;
    SET v_done = 0;
  END LOOP;
  CLOSE cur;

  -- 4) 건조일·소비기한 상속
  SELECT MIN(l.dried_date), MIN(l.expiry_date), COUNT(DISTINCT l.dried_date) INTO v_min_dried, v_min_exp, v_dcnt
    FROM lot_links k JOIN lots l ON l.id = k.parent_lot_id WHERE k.child_lot_id = v_lot_id;
  UPDATE lots SET dried_date = v_min_dried,
                  expiry_date = IF(v_shelf IS NULL, v_min_exp, DATE_ADD(v_min_dried, INTERVAL v_shelf MONTH)),
                  mixed_dried_dates = (COALESCE(v_dcnt, 0) > 1)
   WHERE id = v_lot_id;
  IF COALESCE(v_dcnt, 0) > 1 THEN
    INSERT INTO _warn (msg) VALUES ('건조일이 다른 원재료 로트가 섞였습니다. 가장 이른 건조일로 소비기한을 계산했습니다.');
  END IF;
  UPDATE production_logs SET output_lot_id = v_lot_id WHERE id = v_log_id;

  -- 5) 산출 재고
  INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, ref_type, ref_id)
  VALUES (p_work_date, p_product_id, v_lot_id, p_output_qty, '생산산출', 'production_logs', v_log_id);

  -- 6) 단계 중량
  IF p_steps IS NOT NULL AND JSON_LENGTH(p_steps) > 0 THEN
    SET i = 0; SET n = JSON_LENGTH(p_steps);
    WHILE i < n DO
      INSERT INTO production_steps (log_id, step_no, step_name, input_kg, output_kg, loss_kg, scrap_kg, loss_reason, note)
      VALUES (v_log_id, i + 1,
              COALESCE(JSON_VALUE(p_steps, CONCAT('$[', i, '].step_name')), '내포장'),
              JSON_VALUE(p_steps, CONCAT('$[', i, '].input_kg')),
              JSON_VALUE(p_steps, CONCAT('$[', i, '].output_kg')),
              COALESCE(JSON_VALUE(p_steps, CONCAT('$[', i, '].loss_kg')), 0),
              COALESCE(JSON_VALUE(p_steps, CONCAT('$[', i, '].scrap_kg')), 0),
              NULLIF(JSON_VALUE(p_steps, CONCAT('$[', i, '].loss_reason')), ''),
              JSON_VALUE(p_steps, CONCAT('$[', i, '].note')));
      SET v_scrap = v_scrap + COALESCE(JSON_VALUE(p_steps, CONCAT('$[', i, '].scrap_kg')), 0);
      SET i = i + 1;
    END WHILE;
  ELSEIF v_raw_kg > 0 AND v_net IS NOT NULL THEN
    INSERT INTO production_steps (log_id, step_no, step_name, input_kg, output_kg, note)
    VALUES (v_log_id, 1, '내포장', v_raw_kg, ROUND(p_output_qty * v_net / 1000, 3), '투입량·순중량으로 자동 계산');
  END IF;

  IF EXISTS (SELECT 1 FROM production_steps WHERE log_id = v_log_id AND input_kg > 0
               AND ABS(balance_kg) > GREATEST(0.05, input_kg * 0.02)) THEN
    INSERT INTO _warn (msg) VALUES ('투입 − 산출 − 손실 − 자투리 차이가 2%를 넘습니다. 중량을 확인하세요.');
  END IF;

  -- 7) 자투리 재고
  IF v_scrap > 0 THEN
    SELECT id INTO v_scrap_item FROM items WHERE code = 'RM-SCRAP' AND is_void = 0;
    IF v_scrap_item IS NULL THEN
      INSERT INTO _warn (msg) VALUES ('자투리 품목(RM-SCRAP)이 없어 자투리 재고를 올리지 못했습니다.');
    ELSE
      INSERT INTO lots (lot_no, item_id, source, dried_date, made_on, production_log_id, note)
      VALUES (next_no('SC', p_work_date), v_scrap_item, '생산', v_min_dried, p_work_date, v_log_id, CONCAT(v_log_no, ' 자투리'));
      SET v_scrap_lot = LAST_INSERT_ID();
      INSERT INTO lot_links (parent_lot_id, child_lot_id, production_log_id, qty_used)
      SELECT parent_lot_id, v_scrap_lot, v_log_id, 0 FROM lot_links WHERE child_lot_id = v_lot_id;
      INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, ref_type, ref_id, reason)
      VALUES (p_work_date, v_scrap_item, v_scrap_lot, v_scrap, '생산산출', 'production_logs', v_log_id, '재사용 자투리');
    END IF;
  END IF;
  COMMIT;

  SELECT JSON_OBJECT('log_id', v_log_id, 'log_no', v_log_no, 'lot_id', v_lot_id, 'lot_no', v_lot_no,
           'inputs', (SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('item', it.name, 'qty', pi.actual_qty, 'unit', it.unit, 'lot_no', l.lot_no)), JSON_ARRAY())
                        FROM production_inputs pi JOIN items it ON it.id = pi.item_id LEFT JOIN lots l ON l.id = pi.lot_id
                       WHERE pi.log_id = v_log_id),
           'yield_pct', (SELECT ROUND(SUM(output_kg) / NULLIF(SUM(input_kg), 0) * 100, 2) FROM production_steps WHERE log_id = v_log_id),
           'warnings', (SELECT COALESCE(JSON_ARRAYAGG(msg), JSON_ARRAY()) FROM _warn)) AS result;
END$$

-- ---------------------------------------------------------------------
-- 출고·조정·폐기·기초
-- ---------------------------------------------------------------------
CREATE PROCEDURE register_move(
  IN p_item_id BIGINT, IN p_qty DECIMAL(14,3), IN p_move_type VARCHAR(10), IN p_move_date DATE, IN p_lot_id BIGINT,
  IN p_partner_id BIGINT, IN p_reason TEXT, IN p_increase TINYINT, IN p_unit VARCHAR(10), IN p_dried_date DATE)
BEGIN
  DECLARE v_role VARCHAR(10); DECLARE v_base DECIMAL(14,3); DECLARE v_lot BIGINT; DECLARE v_raw DECIMAL(14,3);
  DECLARE v_sign INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  CALL require_user(v_role);
  CALL warn_reset();
  SET p_move_date = COALESCE(p_move_date, CURDATE());
  IF p_move_type NOT IN ('출고','조정','폐기','기초') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '구분은 출고·조정·폐기·기초 중 하나입니다.'; END IF;
  IF p_move_type IN ('조정','기초') AND v_role <> 'owner' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '재고 조정·기초재고는 대표만 등록할 수 있습니다.'; END IF;
  IF p_move_type IN ('조정','폐기') AND COALESCE(TRIM(p_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '사유를 입력하세요.'; END IF;
  IF p_qty IS NULL OR p_qty <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '수량은 0보다 커야 합니다.'; END IF;

  START TRANSACTION;
  SET v_base = to_base_qty(p_item_id, p_qty, p_unit);
  SET v_sign = IF(p_move_type = '기초' OR (p_move_type = '조정' AND p_increase), 1, -1);
  IF v_sign > 0 THEN
    SET v_lot = p_lot_id;
    IF v_lot IS NULL THEN
      INSERT INTO lots (lot_no, item_id, source, dried_date, made_on, note)
      VALUES (next_no('OP', p_move_date), p_item_id, IF(p_move_type = '기초', '기초', '조정'), p_dried_date, p_move_date, p_reason);
      SET v_lot = LAST_INSERT_ID();
    END IF;
    INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, reason)
    VALUES (p_move_date, p_item_id, v_lot, v_base, p_move_type, p_partner_id, p_reason);
  ELSE
    CALL consume_fefo(p_item_id, v_base, p_lot_id, p_move_type, p_move_date, p_partner_id, p_reason, NULL, NULL, NULL, NULL, NULL, v_raw);
  END IF;
  COMMIT;
  SELECT JSON_OBJECT('base_qty', v_base * v_sign, 'warnings', (SELECT COALESCE(JSON_ARRAYAGG(msg), JSON_ARRAY()) FROM _warn)) AS result;
END$$

-- ---------------------------------------------------------------------
-- 취소 (직원은 당일 본인 기록만, 대표는 모두)
-- ---------------------------------------------------------------------
CREATE FUNCTION can_void(p_created_by INT, p_created_at DATETIME) RETURNS TINYINT READS SQL DATA
BEGIN
  RETURN app_role() = 'owner' OR (p_created_by = @app_user_id AND DATE(p_created_at) = CURDATE());
END$$

CREATE PROCEDURE reverse_moves(IN p_ref_type VARCHAR(30), IN p_ref_id BIGINT, IN p_reason TEXT)
BEGIN
  INSERT INTO stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id, reverses_id, reason)
  SELECT CURDATE(), m.item_id, m.lot_id, -m.qty, '취소', m.partner_id, m.ref_type, m.ref_id, m.id, p_reason
    FROM stock_moves m
   WHERE m.ref_type = p_ref_type AND m.ref_id = p_ref_id AND m.move_type <> '취소'
     AND NOT EXISTS (SELECT 1 FROM stock_moves x WHERE x.reverses_id = m.id);
END$$

CREATE PROCEDURE void_receipt(IN p_receipt_id BIGINT, IN p_reason TEXT)
BEGIN
  DECLARE v_role VARCHAR(10); DECLARE v_no VARCHAR(20); DECLARE v_void INT; DECLARE v_lot BIGINT;
  DECLARE v_base DECIMAL(14,3); DECLARE v_by INT; DECLARE v_at DATETIME;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  CALL require_user(v_role);
  START TRANSACTION;
  SELECT receipt_no, is_void, lot_id, base_qty, created_by, created_at INTO v_no, v_void, v_lot, v_base, v_by, v_at
    FROM receipts WHERE id = p_receipt_id FOR UPDATE;
  IF v_no IS NULL OR v_void THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소할 입고가 없거나 이미 취소되었습니다.'; END IF;
  IF NOT can_void(v_by, v_at) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.'; END IF;
  IF COALESCE(TRIM(p_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유를 입력하세요.'; END IF;
  IF lot_balance(v_lot) < v_base THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '이 입고 로트는 이미 생산·출고에 사용되었습니다. 사용 기록을 먼저 취소하세요.';
  END IF;
  CALL reverse_moves('receipts', p_receipt_id, p_reason);
  UPDATE receipts SET is_void = 1, void_reason = p_reason WHERE id = p_receipt_id;
  UPDATE lots SET is_void = 1, void_reason = p_reason
   WHERE id = v_lot AND lot_balance(id) = 0
     AND NOT EXISTS (SELECT 1 FROM receipts r WHERE r.lot_id = v_lot AND r.is_void = 0);
  COMMIT;
  SELECT JSON_OBJECT('receipt_no', v_no, 'voided', TRUE) AS result;
END$$

CREATE PROCEDURE void_production(IN p_log_id BIGINT, IN p_reason TEXT)
BEGIN
  DECLARE v_role VARCHAR(10); DECLARE v_no VARCHAR(20); DECLARE v_void INT; DECLARE v_by INT; DECLARE v_at DATETIME;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  CALL require_user(v_role);
  START TRANSACTION;
  SELECT log_no, is_void, created_by, created_at INTO v_no, v_void, v_by, v_at FROM production_logs WHERE id = p_log_id FOR UPDATE;
  IF v_no IS NULL OR v_void THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소할 생산일지가 없거나 이미 취소되었습니다.'; END IF;
  IF NOT can_void(v_by, v_at) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.'; END IF;
  IF COALESCE(TRIM(p_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유를 입력하세요.'; END IF;
  IF EXISTS (SELECT 1 FROM lots l WHERE l.production_log_id = p_log_id AND lot_balance(l.id) <
               (SELECT COALESCE(SUM(m.qty), 0) FROM stock_moves m
                 WHERE m.lot_id = l.id AND m.ref_type = 'production_logs' AND m.ref_id = p_log_id AND m.qty > 0)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '이 생산 로트는 이미 다음 공정·출고에 사용되었습니다. 사용 기록을 먼저 취소하세요.';
  END IF;
  CALL reverse_moves('production_logs', p_log_id, p_reason);
  UPDATE production_logs   SET is_void = 1, void_reason = p_reason WHERE id = p_log_id;
  UPDATE production_inputs SET is_void = 1, void_reason = p_reason WHERE log_id = p_log_id;
  UPDATE production_steps  SET is_void = 1, void_reason = p_reason WHERE log_id = p_log_id;
  UPDATE lot_links         SET is_void = 1, void_reason = p_reason WHERE production_log_id = p_log_id;
  UPDATE lots              SET is_void = 1, void_reason = p_reason WHERE production_log_id = p_log_id;
  COMMIT;
  SELECT JSON_OBJECT('log_no', v_no, 'voided', TRUE) AS result;
END$$

DELIMITER ;
