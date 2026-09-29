SET NAMES utf8mb4;
-- =====================================================================
-- 자동 생성 파일 (gen_triggers.py) — 직접 고치지 말고 생성기를 다시 실행하세요
-- 삭제 금지 · 원장 수정 금지 · 수정 시각/작성자 · 취소 규칙 · 수정 이력
-- 작성자 = 세션 변수 @app_user_id (PHP가 로그인 확인 후 설정)
-- =====================================================================
DELIMITER $$

-- partners
CREATE TRIGGER partners_bi BEFORE INSERT ON partners FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER partners_bu BEFORE UPDATE ON partners FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER partners_bd BEFORE DELETE ON partners FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[partners] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER partners_ai AFTER INSERT ON partners FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('partners', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'code', NEW.`code`, 'name', NEW.`name`, 'biz_no', NEW.`biz_no`, 'ceo_name', NEW.`ceo_name`, 'tax_code', NEW.`tax_code`, 'is_supplier', NEW.`is_supplier`, 'is_customer', NEW.`is_customer`, 'category', NEW.`category`, 'contact_name', NEW.`contact_name`, 'phone', NEW.`phone`, 'email', NEW.`email`, 'address', NEW.`address`, 'needs_review', NEW.`needs_review`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER partners_au AFTER UPDATE ON partners FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'code', NEW.`code`, 'name', NEW.`name`, 'biz_no', NEW.`biz_no`, 'ceo_name', NEW.`ceo_name`, 'tax_code', NEW.`tax_code`, 'is_supplier', NEW.`is_supplier`, 'is_customer', NEW.`is_customer`, 'category', NEW.`category`, 'contact_name', NEW.`contact_name`, 'phone', NEW.`phone`, 'email', NEW.`email`, 'address', NEW.`address`, 'needs_review', NEW.`needs_review`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'code', OLD.`code`, 'name', OLD.`name`, 'biz_no', OLD.`biz_no`, 'ceo_name', OLD.`ceo_name`, 'tax_code', OLD.`tax_code`, 'is_supplier', OLD.`is_supplier`, 'is_customer', OLD.`is_customer`, 'category', OLD.`category`, 'contact_name', OLD.`contact_name`, 'phone', OLD.`phone`, 'email', OLD.`email`, 'address', OLD.`address`, 'needs_review', OLD.`needs_review`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('partners', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'code', OLD.`code`, 'name', OLD.`name`, 'biz_no', OLD.`biz_no`, 'ceo_name', OLD.`ceo_name`, 'tax_code', OLD.`tax_code`, 'is_supplier', OLD.`is_supplier`, 'is_customer', OLD.`is_customer`, 'category', OLD.`category`, 'contact_name', OLD.`contact_name`, 'phone', OLD.`phone`, 'email', OLD.`email`, 'address', OLD.`address`, 'needs_review', OLD.`needs_review`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'code', NEW.`code`, 'name', NEW.`name`, 'biz_no', NEW.`biz_no`, 'ceo_name', NEW.`ceo_name`, 'tax_code', NEW.`tax_code`, 'is_supplier', NEW.`is_supplier`, 'is_customer', NEW.`is_customer`, 'category', NEW.`category`, 'contact_name', NEW.`contact_name`, 'phone', NEW.`phone`, 'email', NEW.`email`, 'address', NEW.`address`, 'needs_review', NEW.`needs_review`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- partner_aliases
CREATE TRIGGER partner_aliases_bi BEFORE INSERT ON partner_aliases FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER partner_aliases_bu BEFORE UPDATE ON partner_aliases FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER partner_aliases_bd BEFORE DELETE ON partner_aliases FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[partner_aliases] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER partner_aliases_ai AFTER INSERT ON partner_aliases FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('partner_aliases', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'partner_id', NEW.`partner_id`, 'alias', NEW.`alias`, 'source', NEW.`source`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER partner_aliases_au AFTER UPDATE ON partner_aliases FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'partner_id', NEW.`partner_id`, 'alias', NEW.`alias`, 'source', NEW.`source`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'partner_id', OLD.`partner_id`, 'alias', OLD.`alias`, 'source', OLD.`source`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('partner_aliases', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'partner_id', OLD.`partner_id`, 'alias', OLD.`alias`, 'source', OLD.`source`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'partner_id', NEW.`partner_id`, 'alias', NEW.`alias`, 'source', NEW.`source`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- items
CREATE TRIGGER items_bi BEFORE INSERT ON items FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER items_bu BEFORE UPDATE ON items FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER items_bd BEFORE DELETE ON items FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[items] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER items_ai AFTER INSERT ON items FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('items', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'code', NEW.`code`, 'name', NEW.`name`, 'item_type', NEW.`item_type`, 'pack_kind', NEW.`pack_kind`, 'is_set', NEW.`is_set`, 'unit', NEW.`unit`, 'spec', NEW.`spec`, 'size', NEW.`size`, 'model', NEW.`model`, 'net_weight_g', NEW.`net_weight_g`, 'safety_stock', NEW.`safety_stock`, 'shelf_life_months', NEW.`shelf_life_months`, 'origin', NEW.`origin`, 'storage', NEW.`storage`, 'procure_type', NEW.`procure_type`, 'sale_type', NEW.`sale_type`, 'status', NEW.`status`, 'hs_code', NEW.`hs_code`, 'retail_price', NEW.`retail_price`, 'box_qty', NEW.`box_qty`, 'needs_review', NEW.`needs_review`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`, 'oem_type', NEW.`oem_type`, 'oem_partner_id', NEW.`oem_partner_id`))$$
CREATE TRIGGER items_au AFTER UPDATE ON items FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'code', NEW.`code`, 'name', NEW.`name`, 'item_type', NEW.`item_type`, 'pack_kind', NEW.`pack_kind`, 'is_set', NEW.`is_set`, 'unit', NEW.`unit`, 'spec', NEW.`spec`, 'size', NEW.`size`, 'model', NEW.`model`, 'net_weight_g', NEW.`net_weight_g`, 'safety_stock', NEW.`safety_stock`, 'shelf_life_months', NEW.`shelf_life_months`, 'origin', NEW.`origin`, 'storage', NEW.`storage`, 'procure_type', NEW.`procure_type`, 'sale_type', NEW.`sale_type`, 'status', NEW.`status`, 'hs_code', NEW.`hs_code`, 'retail_price', NEW.`retail_price`, 'box_qty', NEW.`box_qty`, 'needs_review', NEW.`needs_review`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`, 'oem_type', NEW.`oem_type`, 'oem_partner_id', NEW.`oem_partner_id`) <=> JSON_OBJECT('id', OLD.`id`, 'code', OLD.`code`, 'name', OLD.`name`, 'item_type', OLD.`item_type`, 'pack_kind', OLD.`pack_kind`, 'is_set', OLD.`is_set`, 'unit', OLD.`unit`, 'spec', OLD.`spec`, 'size', OLD.`size`, 'model', OLD.`model`, 'net_weight_g', OLD.`net_weight_g`, 'safety_stock', OLD.`safety_stock`, 'shelf_life_months', OLD.`shelf_life_months`, 'origin', OLD.`origin`, 'storage', OLD.`storage`, 'procure_type', OLD.`procure_type`, 'sale_type', OLD.`sale_type`, 'status', OLD.`status`, 'hs_code', OLD.`hs_code`, 'retail_price', OLD.`retail_price`, 'box_qty', OLD.`box_qty`, 'needs_review', OLD.`needs_review`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`, 'oem_type', OLD.`oem_type`, 'oem_partner_id', OLD.`oem_partner_id`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('items', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'code', OLD.`code`, 'name', OLD.`name`, 'item_type', OLD.`item_type`, 'pack_kind', OLD.`pack_kind`, 'is_set', OLD.`is_set`, 'unit', OLD.`unit`, 'spec', OLD.`spec`, 'size', OLD.`size`, 'model', OLD.`model`, 'net_weight_g', OLD.`net_weight_g`, 'safety_stock', OLD.`safety_stock`, 'shelf_life_months', OLD.`shelf_life_months`, 'origin', OLD.`origin`, 'storage', OLD.`storage`, 'procure_type', OLD.`procure_type`, 'sale_type', OLD.`sale_type`, 'status', OLD.`status`, 'hs_code', OLD.`hs_code`, 'retail_price', OLD.`retail_price`, 'box_qty', OLD.`box_qty`, 'needs_review', OLD.`needs_review`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`, 'oem_type', OLD.`oem_type`, 'oem_partner_id', OLD.`oem_partner_id`),
            JSON_OBJECT('id', NEW.`id`, 'code', NEW.`code`, 'name', NEW.`name`, 'item_type', NEW.`item_type`, 'pack_kind', NEW.`pack_kind`, 'is_set', NEW.`is_set`, 'unit', NEW.`unit`, 'spec', NEW.`spec`, 'size', NEW.`size`, 'model', NEW.`model`, 'net_weight_g', NEW.`net_weight_g`, 'safety_stock', NEW.`safety_stock`, 'shelf_life_months', NEW.`shelf_life_months`, 'origin', NEW.`origin`, 'storage', NEW.`storage`, 'procure_type', NEW.`procure_type`, 'sale_type', NEW.`sale_type`, 'status', NEW.`status`, 'hs_code', NEW.`hs_code`, 'retail_price', NEW.`retail_price`, 'box_qty', NEW.`box_qty`, 'needs_review', NEW.`needs_review`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`, 'oem_type', NEW.`oem_type`, 'oem_partner_id', NEW.`oem_partner_id`));
  END IF;
END$$

-- item_aliases
CREATE TRIGGER item_aliases_bi BEFORE INSERT ON item_aliases FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER item_aliases_bu BEFORE UPDATE ON item_aliases FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER item_aliases_bd BEFORE DELETE ON item_aliases FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[item_aliases] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER item_aliases_ai AFTER INSERT ON item_aliases FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('item_aliases', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'alias', NEW.`alias`, 'source', NEW.`source`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER item_aliases_au AFTER UPDATE ON item_aliases FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'alias', NEW.`alias`, 'source', NEW.`source`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'alias', OLD.`alias`, 'source', OLD.`source`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('item_aliases', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'alias', OLD.`alias`, 'source', OLD.`source`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'alias', NEW.`alias`, 'source', NEW.`source`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- item_units
CREATE TRIGGER item_units_bi BEFORE INSERT ON item_units FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER item_units_bu BEFORE UPDATE ON item_units FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER item_units_bd BEFORE DELETE ON item_units FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[item_units] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER item_units_ai AFTER INSERT ON item_units FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('item_units', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'unit', NEW.`unit`, 'factor', NEW.`factor`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER item_units_au AFTER UPDATE ON item_units FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'unit', NEW.`unit`, 'factor', NEW.`factor`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'unit', OLD.`unit`, 'factor', OLD.`factor`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('item_units', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'unit', OLD.`unit`, 'factor', OLD.`factor`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'unit', NEW.`unit`, 'factor', NEW.`factor`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- item_suppliers
CREATE TRIGGER item_suppliers_bi BEFORE INSERT ON item_suppliers FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER item_suppliers_bu BEFORE UPDATE ON item_suppliers FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER item_suppliers_bd BEFORE DELETE ON item_suppliers FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[item_suppliers] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER item_suppliers_ai AFTER INSERT ON item_suppliers FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('item_suppliers', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'partner_id', NEW.`partner_id`, 'unit_price', NEW.`unit_price`, 'is_primary', NEW.`is_primary`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER item_suppliers_au AFTER UPDATE ON item_suppliers FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'partner_id', NEW.`partner_id`, 'unit_price', NEW.`unit_price`, 'is_primary', NEW.`is_primary`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'partner_id', OLD.`partner_id`, 'unit_price', OLD.`unit_price`, 'is_primary', OLD.`is_primary`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('item_suppliers', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'partner_id', OLD.`partner_id`, 'unit_price', OLD.`unit_price`, 'is_primary', OLD.`is_primary`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'partner_id', NEW.`partner_id`, 'unit_price', NEW.`unit_price`, 'is_primary', NEW.`is_primary`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- bom
CREATE TRIGGER bom_bi BEFORE INSERT ON bom FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER bom_bu BEFORE UPDATE ON bom FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER bom_bd BEFORE DELETE ON bom FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[bom] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER bom_ai AFTER INSERT ON bom FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('bom', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'parent_item_id', NEW.`parent_item_id`, 'child_item_id', NEW.`child_item_id`, 'qty_per', NEW.`qty_per`, 'step', NEW.`step`, 'loss_rate', NEW.`loss_rate`, 'alt_group', NEW.`alt_group`, 'sort', NEW.`sort`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER bom_au AFTER UPDATE ON bom FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'parent_item_id', NEW.`parent_item_id`, 'child_item_id', NEW.`child_item_id`, 'qty_per', NEW.`qty_per`, 'step', NEW.`step`, 'loss_rate', NEW.`loss_rate`, 'alt_group', NEW.`alt_group`, 'sort', NEW.`sort`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'parent_item_id', OLD.`parent_item_id`, 'child_item_id', OLD.`child_item_id`, 'qty_per', OLD.`qty_per`, 'step', OLD.`step`, 'loss_rate', OLD.`loss_rate`, 'alt_group', OLD.`alt_group`, 'sort', OLD.`sort`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('bom', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'parent_item_id', OLD.`parent_item_id`, 'child_item_id', OLD.`child_item_id`, 'qty_per', OLD.`qty_per`, 'step', OLD.`step`, 'loss_rate', OLD.`loss_rate`, 'alt_group', OLD.`alt_group`, 'sort', OLD.`sort`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'parent_item_id', NEW.`parent_item_id`, 'child_item_id', NEW.`child_item_id`, 'qty_per', NEW.`qty_per`, 'step', NEW.`step`, 'loss_rate', NEW.`loss_rate`, 'alt_group', NEW.`alt_group`, 'sort', NEW.`sort`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- production_standards
CREATE TRIGGER production_standards_bi BEFORE INSERT ON production_standards FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER production_standards_bu BEFORE UPDATE ON production_standards FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER production_standards_bd BEFORE DELETE ON production_standards FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_standards] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER production_standards_ai AFTER INSERT ON production_standards FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('production_standards', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'step', NEW.`step`, 'std_yield_pct', NEW.`std_yield_pct`, 'std_sec_per_ea', NEW.`std_sec_per_ea`, 'bulk_unit_kg', NEW.`bulk_unit_kg`, 'sample_count', NEW.`sample_count`, 'is_provisional', NEW.`is_provisional`, 'source', NEW.`source`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER production_standards_au AFTER UPDATE ON production_standards FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'step', NEW.`step`, 'std_yield_pct', NEW.`std_yield_pct`, 'std_sec_per_ea', NEW.`std_sec_per_ea`, 'bulk_unit_kg', NEW.`bulk_unit_kg`, 'sample_count', NEW.`sample_count`, 'is_provisional', NEW.`is_provisional`, 'source', NEW.`source`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'step', OLD.`step`, 'std_yield_pct', OLD.`std_yield_pct`, 'std_sec_per_ea', OLD.`std_sec_per_ea`, 'bulk_unit_kg', OLD.`bulk_unit_kg`, 'sample_count', OLD.`sample_count`, 'is_provisional', OLD.`is_provisional`, 'source', OLD.`source`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('production_standards', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'item_id', OLD.`item_id`, 'step', OLD.`step`, 'std_yield_pct', OLD.`std_yield_pct`, 'std_sec_per_ea', OLD.`std_sec_per_ea`, 'bulk_unit_kg', OLD.`bulk_unit_kg`, 'sample_count', OLD.`sample_count`, 'is_provisional', OLD.`is_provisional`, 'source', OLD.`source`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'item_id', NEW.`item_id`, 'step', NEW.`step`, 'std_yield_pct', NEW.`std_yield_pct`, 'std_sec_per_ea', NEW.`std_sec_per_ea`, 'bulk_unit_kg', NEW.`bulk_unit_kg`, 'sample_count', NEW.`sample_count`, 'is_provisional', NEW.`is_provisional`, 'source', NEW.`source`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- lots
CREATE TRIGGER lots_bi BEFORE INSERT ON lots FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
  IF NEW.expiry_date IS NULL AND NEW.dried_date IS NOT NULL THEN
    SET NEW.expiry_date = (SELECT DATE_ADD(NEW.dried_date, INTERVAL shelf_life_months MONTH) FROM items WHERE id = NEW.item_id);
  END IF;
END$$
CREATE TRIGGER lots_bu BEFORE UPDATE ON lots FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.dried_date <=> OLD.dried_date) AND NEW.dried_date IS NOT NULL AND NEW.expiry_date <=> OLD.expiry_date THEN
    SET NEW.expiry_date = (SELECT DATE_ADD(NEW.dried_date, INTERVAL shelf_life_months MONTH) FROM items WHERE id = NEW.item_id);
  END IF;
END$$
CREATE TRIGGER lots_bd BEFORE DELETE ON lots FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[lots] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER lots_ai AFTER INSERT ON lots FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('lots', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'lot_no', NEW.`lot_no`, 'item_id', NEW.`item_id`, 'source', NEW.`source`, 'dried_date', NEW.`dried_date`, 'expiry_date', NEW.`expiry_date`, 'made_on', NEW.`made_on`, 'receipt_id', NEW.`receipt_id`, 'production_log_id', NEW.`production_log_id`, 'mixed_dried_dates', NEW.`mixed_dried_dates`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER lots_au AFTER UPDATE ON lots FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'lot_no', NEW.`lot_no`, 'item_id', NEW.`item_id`, 'source', NEW.`source`, 'dried_date', NEW.`dried_date`, 'expiry_date', NEW.`expiry_date`, 'made_on', NEW.`made_on`, 'receipt_id', NEW.`receipt_id`, 'production_log_id', NEW.`production_log_id`, 'mixed_dried_dates', NEW.`mixed_dried_dates`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'lot_no', OLD.`lot_no`, 'item_id', OLD.`item_id`, 'source', OLD.`source`, 'dried_date', OLD.`dried_date`, 'expiry_date', OLD.`expiry_date`, 'made_on', OLD.`made_on`, 'receipt_id', OLD.`receipt_id`, 'production_log_id', OLD.`production_log_id`, 'mixed_dried_dates', OLD.`mixed_dried_dates`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('lots', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'lot_no', OLD.`lot_no`, 'item_id', OLD.`item_id`, 'source', OLD.`source`, 'dried_date', OLD.`dried_date`, 'expiry_date', OLD.`expiry_date`, 'made_on', OLD.`made_on`, 'receipt_id', OLD.`receipt_id`, 'production_log_id', OLD.`production_log_id`, 'mixed_dried_dates', OLD.`mixed_dried_dates`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'lot_no', NEW.`lot_no`, 'item_id', NEW.`item_id`, 'source', NEW.`source`, 'dried_date', NEW.`dried_date`, 'expiry_date', NEW.`expiry_date`, 'made_on', NEW.`made_on`, 'receipt_id', NEW.`receipt_id`, 'production_log_id', NEW.`production_log_id`, 'mixed_dried_dates', NEW.`mixed_dried_dates`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- receipts
CREATE TRIGGER receipts_bi BEFORE INSERT ON receipts FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER receipts_bu BEFORE UPDATE ON receipts FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.`item_id` <=> OLD.`item_id`) OR NOT (NEW.`qty` <=> OLD.`qty`) OR NOT (NEW.`unit` <=> OLD.`unit`) OR NOT (NEW.`base_qty` <=> OLD.`base_qty`) OR NOT (NEW.`lot_id` <=> OLD.`lot_id`) OR NOT (NEW.`received_on` <=> OLD.`received_on`) OR NOT (NEW.`receipt_no` <=> OLD.`receipt_no`) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[receipts] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER receipts_bd BEFORE DELETE ON receipts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[receipts] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER receipts_ai AFTER INSERT ON receipts FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('receipts', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'receipt_no', NEW.`receipt_no`, 'received_on', NEW.`received_on`, 'item_id', NEW.`item_id`, 'partner_id', NEW.`partner_id`, 'qty', NEW.`qty`, 'unit', NEW.`unit`, 'base_qty', NEW.`base_qty`, 'bulk_count', NEW.`bulk_count`, 'unit_price', NEW.`unit_price`, 'lot_id', NEW.`lot_id`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER receipts_au AFTER UPDATE ON receipts FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'receipt_no', NEW.`receipt_no`, 'received_on', NEW.`received_on`, 'item_id', NEW.`item_id`, 'partner_id', NEW.`partner_id`, 'qty', NEW.`qty`, 'unit', NEW.`unit`, 'base_qty', NEW.`base_qty`, 'bulk_count', NEW.`bulk_count`, 'unit_price', NEW.`unit_price`, 'lot_id', NEW.`lot_id`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'receipt_no', OLD.`receipt_no`, 'received_on', OLD.`received_on`, 'item_id', OLD.`item_id`, 'partner_id', OLD.`partner_id`, 'qty', OLD.`qty`, 'unit', OLD.`unit`, 'base_qty', OLD.`base_qty`, 'bulk_count', OLD.`bulk_count`, 'unit_price', OLD.`unit_price`, 'lot_id', OLD.`lot_id`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('receipts', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'receipt_no', OLD.`receipt_no`, 'received_on', OLD.`received_on`, 'item_id', OLD.`item_id`, 'partner_id', OLD.`partner_id`, 'qty', OLD.`qty`, 'unit', OLD.`unit`, 'base_qty', OLD.`base_qty`, 'bulk_count', OLD.`bulk_count`, 'unit_price', OLD.`unit_price`, 'lot_id', OLD.`lot_id`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'receipt_no', NEW.`receipt_no`, 'received_on', NEW.`received_on`, 'item_id', NEW.`item_id`, 'partner_id', NEW.`partner_id`, 'qty', NEW.`qty`, 'unit', NEW.`unit`, 'base_qty', NEW.`base_qty`, 'bulk_count', NEW.`bulk_count`, 'unit_price', NEW.`unit_price`, 'lot_id', NEW.`lot_id`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- production_logs
CREATE TRIGGER production_logs_bi BEFORE INSERT ON production_logs FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER production_logs_bu BEFORE UPDATE ON production_logs FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.`product_item_id` <=> OLD.`product_item_id`) OR NOT (NEW.`output_qty` <=> OLD.`output_qty`) OR NOT (NEW.`defect_qty` <=> OLD.`defect_qty`) OR NOT (NEW.`work_date` <=> OLD.`work_date`) OR NOT (NEW.`log_no` <=> OLD.`log_no`) OR (OLD.output_lot_id IS NOT NULL AND NOT (NEW.output_lot_id <=> OLD.output_lot_id)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_logs] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER production_logs_bd BEFORE DELETE ON production_logs FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_logs] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER production_logs_ai AFTER INSERT ON production_logs FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('production_logs', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'log_no', NEW.`log_no`, 'work_date', NEW.`work_date`, 'product_item_id', NEW.`product_item_id`, 'output_qty', NEW.`output_qty`, 'defect_qty', NEW.`defect_qty`, 'output_lot_id', NEW.`output_lot_id`, 'workers', NEW.`workers`, 'segments', NEW.`segments`, 'work_minutes', NEW.`work_minutes`, 'issues', NEW.`issues`, 'suggestion', NEW.`suggestion`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER production_logs_au AFTER UPDATE ON production_logs FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'log_no', NEW.`log_no`, 'work_date', NEW.`work_date`, 'product_item_id', NEW.`product_item_id`, 'output_qty', NEW.`output_qty`, 'defect_qty', NEW.`defect_qty`, 'output_lot_id', NEW.`output_lot_id`, 'workers', NEW.`workers`, 'segments', NEW.`segments`, 'work_minutes', NEW.`work_minutes`, 'issues', NEW.`issues`, 'suggestion', NEW.`suggestion`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'log_no', OLD.`log_no`, 'work_date', OLD.`work_date`, 'product_item_id', OLD.`product_item_id`, 'output_qty', OLD.`output_qty`, 'defect_qty', OLD.`defect_qty`, 'output_lot_id', OLD.`output_lot_id`, 'workers', OLD.`workers`, 'segments', OLD.`segments`, 'work_minutes', OLD.`work_minutes`, 'issues', OLD.`issues`, 'suggestion', OLD.`suggestion`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('production_logs', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'log_no', OLD.`log_no`, 'work_date', OLD.`work_date`, 'product_item_id', OLD.`product_item_id`, 'output_qty', OLD.`output_qty`, 'defect_qty', OLD.`defect_qty`, 'output_lot_id', OLD.`output_lot_id`, 'workers', OLD.`workers`, 'segments', OLD.`segments`, 'work_minutes', OLD.`work_minutes`, 'issues', OLD.`issues`, 'suggestion', OLD.`suggestion`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'log_no', NEW.`log_no`, 'work_date', NEW.`work_date`, 'product_item_id', NEW.`product_item_id`, 'output_qty', NEW.`output_qty`, 'defect_qty', NEW.`defect_qty`, 'output_lot_id', NEW.`output_lot_id`, 'workers', NEW.`workers`, 'segments', NEW.`segments`, 'work_minutes', NEW.`work_minutes`, 'issues', NEW.`issues`, 'suggestion', NEW.`suggestion`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- production_steps
CREATE TRIGGER production_steps_bi BEFORE INSERT ON production_steps FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER production_steps_bu BEFORE UPDATE ON production_steps FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.`log_id` <=> OLD.`log_id`) OR NOT (NEW.`step_no` <=> OLD.`step_no`) OR NOT (NEW.`input_kg` <=> OLD.`input_kg`) OR NOT (NEW.`output_kg` <=> OLD.`output_kg`) OR NOT (NEW.`loss_kg` <=> OLD.`loss_kg`) OR NOT (NEW.`scrap_kg` <=> OLD.`scrap_kg`) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_steps] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER production_steps_bd BEFORE DELETE ON production_steps FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_steps] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER production_steps_ai AFTER INSERT ON production_steps FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('production_steps', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'log_id', NEW.`log_id`, 'step_no', NEW.`step_no`, 'step_name', NEW.`step_name`, 'input_kg', NEW.`input_kg`, 'output_kg', NEW.`output_kg`, 'loss_kg', NEW.`loss_kg`, 'scrap_kg', NEW.`scrap_kg`, 'loss_reason', NEW.`loss_reason`, 'yield_pct', NEW.`yield_pct`, 'balance_kg', NEW.`balance_kg`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER production_steps_au AFTER UPDATE ON production_steps FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'log_id', NEW.`log_id`, 'step_no', NEW.`step_no`, 'step_name', NEW.`step_name`, 'input_kg', NEW.`input_kg`, 'output_kg', NEW.`output_kg`, 'loss_kg', NEW.`loss_kg`, 'scrap_kg', NEW.`scrap_kg`, 'loss_reason', NEW.`loss_reason`, 'yield_pct', NEW.`yield_pct`, 'balance_kg', NEW.`balance_kg`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'log_id', OLD.`log_id`, 'step_no', OLD.`step_no`, 'step_name', OLD.`step_name`, 'input_kg', OLD.`input_kg`, 'output_kg', OLD.`output_kg`, 'loss_kg', OLD.`loss_kg`, 'scrap_kg', OLD.`scrap_kg`, 'loss_reason', OLD.`loss_reason`, 'yield_pct', OLD.`yield_pct`, 'balance_kg', OLD.`balance_kg`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('production_steps', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'log_id', OLD.`log_id`, 'step_no', OLD.`step_no`, 'step_name', OLD.`step_name`, 'input_kg', OLD.`input_kg`, 'output_kg', OLD.`output_kg`, 'loss_kg', OLD.`loss_kg`, 'scrap_kg', OLD.`scrap_kg`, 'loss_reason', OLD.`loss_reason`, 'yield_pct', OLD.`yield_pct`, 'balance_kg', OLD.`balance_kg`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'log_id', NEW.`log_id`, 'step_no', NEW.`step_no`, 'step_name', NEW.`step_name`, 'input_kg', NEW.`input_kg`, 'output_kg', NEW.`output_kg`, 'loss_kg', NEW.`loss_kg`, 'scrap_kg', NEW.`scrap_kg`, 'loss_reason', NEW.`loss_reason`, 'yield_pct', NEW.`yield_pct`, 'balance_kg', NEW.`balance_kg`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- production_inputs
CREATE TRIGGER production_inputs_bi BEFORE INSERT ON production_inputs FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER production_inputs_bu BEFORE UPDATE ON production_inputs FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.`log_id` <=> OLD.`log_id`) OR NOT (NEW.`item_id` <=> OLD.`item_id`) OR NOT (NEW.`lot_id` <=> OLD.`lot_id`) OR NOT (NEW.`planned_qty` <=> OLD.`planned_qty`) OR NOT (NEW.`actual_qty` <=> OLD.`actual_qty`) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_inputs] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER production_inputs_bd BEFORE DELETE ON production_inputs FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[production_inputs] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER production_inputs_ai AFTER INSERT ON production_inputs FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('production_inputs', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'log_id', NEW.`log_id`, 'item_id', NEW.`item_id`, 'lot_id', NEW.`lot_id`, 'planned_qty', NEW.`planned_qty`, 'actual_qty', NEW.`actual_qty`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER production_inputs_au AFTER UPDATE ON production_inputs FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'log_id', NEW.`log_id`, 'item_id', NEW.`item_id`, 'lot_id', NEW.`lot_id`, 'planned_qty', NEW.`planned_qty`, 'actual_qty', NEW.`actual_qty`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'log_id', OLD.`log_id`, 'item_id', OLD.`item_id`, 'lot_id', OLD.`lot_id`, 'planned_qty', OLD.`planned_qty`, 'actual_qty', OLD.`actual_qty`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('production_inputs', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'log_id', OLD.`log_id`, 'item_id', OLD.`item_id`, 'lot_id', OLD.`lot_id`, 'planned_qty', OLD.`planned_qty`, 'actual_qty', OLD.`actual_qty`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'log_id', NEW.`log_id`, 'item_id', NEW.`item_id`, 'lot_id', NEW.`lot_id`, 'planned_qty', NEW.`planned_qty`, 'actual_qty', NEW.`actual_qty`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- lot_links
CREATE TRIGGER lot_links_bi BEFORE INSERT ON lot_links FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER lot_links_bu BEFORE UPDATE ON lot_links FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.`parent_lot_id` <=> OLD.`parent_lot_id`) OR NOT (NEW.`child_lot_id` <=> OLD.`child_lot_id`) OR NOT (NEW.`production_log_id` <=> OLD.`production_log_id`) OR NOT (NEW.`qty_used` <=> OLD.`qty_used`) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[lot_links] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER lot_links_bd BEFORE DELETE ON lot_links FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[lot_links] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER lot_links_ai AFTER INSERT ON lot_links FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('lot_links', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'parent_lot_id', NEW.`parent_lot_id`, 'child_lot_id', NEW.`child_lot_id`, 'production_log_id', NEW.`production_log_id`, 'qty_used', NEW.`qty_used`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER lot_links_au AFTER UPDATE ON lot_links FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'parent_lot_id', NEW.`parent_lot_id`, 'child_lot_id', NEW.`child_lot_id`, 'production_log_id', NEW.`production_log_id`, 'qty_used', NEW.`qty_used`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'parent_lot_id', OLD.`parent_lot_id`, 'child_lot_id', OLD.`child_lot_id`, 'production_log_id', OLD.`production_log_id`, 'qty_used', OLD.`qty_used`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('lot_links', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'parent_lot_id', OLD.`parent_lot_id`, 'child_lot_id', OLD.`child_lot_id`, 'production_log_id', OLD.`production_log_id`, 'qty_used', OLD.`qty_used`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'parent_lot_id', NEW.`parent_lot_id`, 'child_lot_id', NEW.`child_lot_id`, 'production_log_id', NEW.`production_log_id`, 'qty_used', NEW.`qty_used`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- sales_orders
CREATE TRIGGER sales_orders_bi BEFORE INSERT ON sales_orders FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER sales_orders_bu BEFORE UPDATE ON sales_orders FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF NOT (NEW.`order_no` <=> OLD.`order_no`) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[sales_orders] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER sales_orders_bd BEFORE DELETE ON sales_orders FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[sales_orders] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER sales_orders_ai AFTER INSERT ON sales_orders FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('sales_orders', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'order_no', NEW.`order_no`, 'channel_type', NEW.`channel_type`, 'channel_partner_id', NEW.`channel_partner_id`, 'order_date', NEW.`order_date`, 'ship_date', NEW.`ship_date`, 'destination', NEW.`destination`, 'delivery_method', NEW.`delivery_method`, 'writer', NEW.`writer`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER sales_orders_au AFTER UPDATE ON sales_orders FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'order_no', NEW.`order_no`, 'channel_type', NEW.`channel_type`, 'channel_partner_id', NEW.`channel_partner_id`, 'order_date', NEW.`order_date`, 'ship_date', NEW.`ship_date`, 'destination', NEW.`destination`, 'delivery_method', NEW.`delivery_method`, 'writer', NEW.`writer`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'order_no', OLD.`order_no`, 'channel_type', OLD.`channel_type`, 'channel_partner_id', OLD.`channel_partner_id`, 'order_date', OLD.`order_date`, 'ship_date', OLD.`ship_date`, 'destination', OLD.`destination`, 'delivery_method', OLD.`delivery_method`, 'writer', OLD.`writer`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('sales_orders', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'order_no', OLD.`order_no`, 'channel_type', OLD.`channel_type`, 'channel_partner_id', OLD.`channel_partner_id`, 'order_date', OLD.`order_date`, 'ship_date', OLD.`ship_date`, 'destination', OLD.`destination`, 'delivery_method', OLD.`delivery_method`, 'writer', OLD.`writer`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'order_no', NEW.`order_no`, 'channel_type', NEW.`channel_type`, 'channel_partner_id', NEW.`channel_partner_id`, 'order_date', NEW.`order_date`, 'ship_date', NEW.`ship_date`, 'destination', NEW.`destination`, 'delivery_method', NEW.`delivery_method`, 'writer', NEW.`writer`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- sales_recipients
CREATE TRIGGER sales_recipients_bi BEFORE INSERT ON sales_recipients FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER sales_recipients_bu BEFORE UPDATE ON sales_recipients FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
END$$
CREATE TRIGGER sales_recipients_bd BEFORE DELETE ON sales_recipients FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[sales_recipients] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER sales_recipients_ai AFTER INSERT ON sales_recipients FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('sales_recipients', NEW.order_id, 'INSERT', @app_user_id, JSON_OBJECT('order_id', NEW.`order_id`, 'recipient_name', NEW.`recipient_name`, 'recipient_org', NEW.`recipient_org`, 'phone', NEW.`phone`, 'address', NEW.`address`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER sales_recipients_au AFTER UPDATE ON sales_recipients FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('order_id', NEW.`order_id`, 'recipient_name', NEW.`recipient_name`, 'recipient_org', NEW.`recipient_org`, 'phone', NEW.`phone`, 'address', NEW.`address`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('order_id', OLD.`order_id`, 'recipient_name', OLD.`recipient_name`, 'recipient_org', OLD.`recipient_org`, 'phone', OLD.`phone`, 'address', OLD.`address`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('sales_recipients', NEW.order_id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('order_id', OLD.`order_id`, 'recipient_name', OLD.`recipient_name`, 'recipient_org', OLD.`recipient_org`, 'phone', OLD.`phone`, 'address', OLD.`address`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('order_id', NEW.`order_id`, 'recipient_name', NEW.`recipient_name`, 'recipient_org', NEW.`recipient_org`, 'phone', NEW.`phone`, 'address', NEW.`address`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- sales_lines
CREATE TRIGGER sales_lines_bi BEFORE INSERT ON sales_lines FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;
  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;
END$$
CREATE TRIGGER sales_lines_bu BEFORE UPDATE ON sales_lines FOR EACH ROW BEGIN
  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;
  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;
  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.'; END IF;
  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN
    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '취소 사유(void_reason)를 입력하세요.'; END IF;
    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;
  ELSEIF NEW.is_void = OLD.is_void THEN
    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;
  END IF;
  IF OLD.shipped = 1 AND (NOT (NEW.item_id <=> OLD.item_id) OR NOT (NEW.qty <=> OLD.qty)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '출고 처리된 품목·수량은 직접 수정할 수 없습니다. 주문을 취소 후 다시 등록하세요.';
  END IF;
END$$
CREATE TRIGGER sales_lines_bd BEFORE DELETE ON sales_lines FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[sales_lines] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.'$$
CREATE TRIGGER sales_lines_ai AFTER INSERT ON sales_lines FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('sales_lines', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'order_id', NEW.`order_id`, 'line_no', NEW.`line_no`, 'item_id', NEW.`item_id`, 'item_text', NEW.`item_text`, 'qty', NEW.`qty`, 'unit', NEW.`unit`, 'unit_price', NEW.`unit_price`, 'supply_amount', NEW.`supply_amount`, 'vat', NEW.`vat`, 'tax_type', NEW.`tax_type`, 'shipping_fee', NEW.`shipping_fee`, 'total', NEW.`total`, 'shipped', NEW.`shipped`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`))$$
CREATE TRIGGER sales_lines_au AFTER UPDATE ON sales_lines FOR EACH ROW BEGIN
  IF NOT (JSON_OBJECT('id', NEW.`id`, 'order_id', NEW.`order_id`, 'line_no', NEW.`line_no`, 'item_id', NEW.`item_id`, 'item_text', NEW.`item_text`, 'qty', NEW.`qty`, 'unit', NEW.`unit`, 'unit_price', NEW.`unit_price`, 'supply_amount', NEW.`supply_amount`, 'vat', NEW.`vat`, 'tax_type', NEW.`tax_type`, 'shipping_fee', NEW.`shipping_fee`, 'total', NEW.`total`, 'shipped', NEW.`shipped`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`) <=> JSON_OBJECT('id', OLD.`id`, 'order_id', OLD.`order_id`, 'line_no', OLD.`line_no`, 'item_id', OLD.`item_id`, 'item_text', OLD.`item_text`, 'qty', OLD.`qty`, 'unit', OLD.`unit`, 'unit_price', OLD.`unit_price`, 'supply_amount', OLD.`supply_amount`, 'vat', OLD.`vat`, 'tax_type', OLD.`tax_type`, 'shipping_fee', OLD.`shipping_fee`, 'total', OLD.`total`, 'shipped', OLD.`shipped`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`)) THEN
    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)
    VALUES ('sales_lines', NEW.id, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,
            JSON_OBJECT('id', OLD.`id`, 'order_id', OLD.`order_id`, 'line_no', OLD.`line_no`, 'item_id', OLD.`item_id`, 'item_text', OLD.`item_text`, 'qty', OLD.`qty`, 'unit', OLD.`unit`, 'unit_price', OLD.`unit_price`, 'supply_amount', OLD.`supply_amount`, 'vat', OLD.`vat`, 'tax_type', OLD.`tax_type`, 'shipping_fee', OLD.`shipping_fee`, 'total', OLD.`total`, 'shipped', OLD.`shipped`, 'note', OLD.`note`, 'created_at', OLD.`created_at`, 'created_by', OLD.`created_by`, 'updated_at', OLD.`updated_at`, 'updated_by', OLD.`updated_by`, 'is_void', OLD.`is_void`, 'void_reason', OLD.`void_reason`, 'voided_at', OLD.`voided_at`, 'voided_by', OLD.`voided_by`),
            JSON_OBJECT('id', NEW.`id`, 'order_id', NEW.`order_id`, 'line_no', NEW.`line_no`, 'item_id', NEW.`item_id`, 'item_text', NEW.`item_text`, 'qty', NEW.`qty`, 'unit', NEW.`unit`, 'unit_price', NEW.`unit_price`, 'supply_amount', NEW.`supply_amount`, 'vat', NEW.`vat`, 'tax_type', NEW.`tax_type`, 'shipping_fee', NEW.`shipping_fee`, 'total', NEW.`total`, 'shipped', NEW.`shipped`, 'note', NEW.`note`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`, 'updated_at', NEW.`updated_at`, 'updated_by', NEW.`updated_by`, 'is_void', NEW.`is_void`, 'void_reason', NEW.`void_reason`, 'voided_at', NEW.`voided_at`, 'voided_by', NEW.`voided_by`));
  END IF;
END$$

-- stock_moves (추가만)
CREATE TRIGGER stock_moves_bi BEFORE INSERT ON stock_moves FOR EACH ROW BEGIN
  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id, NEW.moved_at = NOW();
  IF NEW.move_date IS NULL THEN SET NEW.move_date = CURDATE(); END IF;
END$$
CREATE TRIGGER stock_moves_bu BEFORE UPDATE ON stock_moves FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[stock_moves] 기록은 수정할 수 없습니다. 반대 기록을 추가해 바로잡으세요.'$$
CREATE TRIGGER stock_moves_bd BEFORE DELETE ON stock_moves FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[stock_moves] 기록은 삭제할 수 없습니다.'$$
CREATE TRIGGER stock_moves_ai AFTER INSERT ON stock_moves FOR EACH ROW
  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('stock_moves', NEW.id, 'INSERT', @app_user_id, JSON_OBJECT('id', NEW.`id`, 'moved_at', NEW.`moved_at`, 'move_date', NEW.`move_date`, 'item_id', NEW.`item_id`, 'lot_id', NEW.`lot_id`, 'qty', NEW.`qty`, 'move_type', NEW.`move_type`, 'partner_id', NEW.`partner_id`, 'ref_type', NEW.`ref_type`, 'ref_id', NEW.`ref_id`, 'reverses_id', NEW.`reverses_id`, 'reason', NEW.`reason`, 'created_at', NEW.`created_at`, 'created_by', NEW.`created_by`))$$

-- audit_log (추가만)
CREATE TRIGGER audit_log_bu BEFORE UPDATE ON audit_log FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[audit_log] 수정 이력은 수정할 수 없습니다.'$$
CREATE TRIGGER audit_log_bd BEFORE DELETE ON audit_log FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[audit_log] 수정 이력은 삭제할 수 없습니다.'$$

-- import_rows (추가만)
CREATE TRIGGER import_rows_bu BEFORE UPDATE ON import_rows FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[import_rows] 가져오기 기록은 수정할 수 없습니다.'$$
CREATE TRIGGER import_rows_bd BEFORE DELETE ON import_rows FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '[import_rows] 가져오기 기록은 삭제할 수 없습니다.'$$

-- app_users: 삭제 대신 active = 0
CREATE TRIGGER app_users_bd BEFORE DELETE ON app_users FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '사용자는 삭제할 수 없습니다. active = 0 으로 중지하세요.'$$
DELIMITER ;
