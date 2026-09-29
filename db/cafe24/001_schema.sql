-- =====================================================================
-- SEA.D 업무통합 시스템 1단계 — 카페24(MariaDB 10.x / MySQL 8) 테이블
-- Supabase 버전(db/supabase/001_schema.sql)과 테이블·컬럼 이름이 같습니다.
-- 차이점
--  * 로그인: Supabase Auth 대신 app_users(비밀번호 해시) — PHP가 세션 확인 후
--    접속마다  SET @app_user_id = <사용자 id>;  를 실행하고, 트리거가 이 값을 작성자로 기록
--  * 사용자 id 는 uuid 대신 정수
-- 원칙(동일): 삭제 금지, 재고는 stock_moves 합계, 모든 변경은 audit_log 기록
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE app_users (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  login_id       VARCHAR(50)  NOT NULL UNIQUE,
  name           VARCHAR(50)  NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,                -- PHP password_hash()
  role           VARCHAR(10)  NOT NULL DEFAULT 'staff' CHECK (role IN ('owner','staff')),
  active         TINYINT(1)   NOT NULL DEFAULT 1,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='사용자. role: owner=대표, staff=직원';

-- ---------------------------------------------------------------------
-- 거래처
-- ---------------------------------------------------------------------
CREATE TABLE partners (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(20)  NOT NULL UNIQUE,
  name          VARCHAR(200) NOT NULL,
  biz_no        VARCHAR(12)  UNIQUE,
  ceo_name      VARCHAR(100),
  tax_code      VARCHAR(20),
  is_supplier   TINYINT(1) NOT NULL DEFAULT 0,
  is_customer   TINYINT(1) NOT NULL DEFAULT 0,
  category      VARCHAR(20) CHECK (category IN ('원물생산자','원재료','부재료','포장재','위탁제조','온라인채널','오프라인','B2B','B2G','도매','OEM','물류','경비·서비스','기타')),
  contact_name  VARCHAR(100),
  phone         VARCHAR(50),
  email         VARCHAR(200),
  address       VARCHAR(300),
  needs_review  TINYINT(1) NOT NULL DEFAULT 0,
  note          TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  CHECK (biz_no IS NULL OR biz_no REGEXP '^[0-9]{3}-[0-9]{2}-[0-9]{5}$'),
  FOREIGN KEY (created_by) REFERENCES app_users(id), FOREIGN KEY (updated_by) REFERENCES app_users(id), FOREIGN KEY (voided_by) REFERENCES app_users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='거래처(매입처·매출처)';

CREATE TABLE partner_aliases (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  partner_id  BIGINT NOT NULL,
  alias       VARCHAR(200) NOT NULL UNIQUE,
  source      VARCHAR(200),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  FOREIGN KEY (partner_id) REFERENCES partners(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 품목
-- ---------------------------------------------------------------------
CREATE TABLE items (
  id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
  code               VARCHAR(30)  NOT NULL UNIQUE,
  name               VARCHAR(200) NOT NULL,
  item_type          VARCHAR(4)   NOT NULL CHECK (item_type IN ('RAW','SUB','PACK','SEMI','FG')),
  pack_kind          VARCHAR(10)  CHECK (pack_kind IN ('박스','카톤','포장지','인쇄물','라벨','기타')),
  is_set             TINYINT(1)   NOT NULL DEFAULT 0,
  unit               VARCHAR(10)  NOT NULL,
  spec               VARCHAR(100),
  size               VARCHAR(100),
  model              VARCHAR(50),
  net_weight_g       DECIMAL(12,3),
  safety_stock       DECIMAL(14,3) NOT NULL DEFAULT 0,
  shelf_life_months  INT,
  origin             VARCHAR(100),
  storage            VARCHAR(100),
  procure_type       VARCHAR(10) CHECK (procure_type IN ('자사생산','OEM위탁','도매상품','완제품납품','매입')),
  sale_type          VARCHAR(50),
  status             VARCHAR(10) NOT NULL DEFAULT '판매중' CHECK (status IN ('판매중','준비','단종','사용')),
  hs_code            VARCHAR(20),
  retail_price       DECIMAL(12,0),
  box_qty            INT,
  needs_review       TINYINT(1) NOT NULL DEFAULT 0,
  note               TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='품목. RAW 원재료, SUB 부재료, PACK 포장재, SEMI 반제품, FG 완제품';

CREATE TABLE item_aliases (
  id        BIGINT AUTO_INCREMENT PRIMARY KEY,
  item_id   BIGINT NOT NULL,
  alias     VARCHAR(200) NOT NULL UNIQUE,
  source    VARCHAR(200),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE item_units (
  id        BIGINT AUTO_INCREMENT PRIMARY KEY,
  item_id   BIGINT NOT NULL,
  unit      VARCHAR(10) NOT NULL,
  factor    DECIMAL(14,4) NOT NULL CHECK (factor > 0),
  note      TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  UNIQUE (item_id, unit),
  FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE item_suppliers (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  item_id     BIGINT NOT NULL,
  partner_id  BIGINT NOT NULL,
  unit_price  DECIMAL(14,2),
  is_primary  TINYINT(1) NOT NULL DEFAULT 0,
  note        TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  UNIQUE (item_id, partner_id),
  FOREIGN KEY (item_id) REFERENCES items(id), FOREIGN KEY (partner_id) REFERENCES partners(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bom (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  parent_item_id  BIGINT NOT NULL,
  child_item_id   BIGINT NOT NULL,
  qty_per         DECIMAL(14,4) NOT NULL CHECK (qty_per > 0),
  step            VARCHAR(10) CHECK (step IN ('내포장','외포장')),
  loss_rate       DECIMAL(6,3) NOT NULL DEFAULT 0 CHECK (loss_rate >= 0 AND loss_rate < 100),
  alt_group       VARCHAR(30),
  sort            INT NOT NULL DEFAULT 0,
  note            TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  CHECK (parent_item_id <> child_item_id),
  UNIQUE (parent_item_id, child_item_id),
  FOREIGN KEY (parent_item_id) REFERENCES items(id), FOREIGN KEY (child_item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE production_standards (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  item_id         BIGINT NOT NULL,
  step            VARCHAR(20) NOT NULL DEFAULT '내포장',
  std_yield_pct   DECIMAL(6,2),
  std_sec_per_ea  DECIMAL(10,2),
  bulk_unit_kg    DECIMAL(10,3),
  sample_count    INT NOT NULL DEFAULT 0,
  is_provisional  TINYINT(1) NOT NULL DEFAULT 1,
  source          VARCHAR(200),
  note            TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  UNIQUE (item_id, step),
  FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 로트 · 입고 · 생산 · 재고이동
-- ---------------------------------------------------------------------
CREATE TABLE lots (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  lot_no              VARCHAR(40) NOT NULL UNIQUE,
  item_id             BIGINT NOT NULL,
  source              VARCHAR(4) NOT NULL CHECK (source IN ('입고','생산','기초','조정')),
  dried_date          DATE,
  expiry_date         DATE,
  made_on             DATE,
  receipt_id          BIGINT,
  production_log_id   BIGINT,
  mixed_dried_dates   TINYINT(1) NOT NULL DEFAULT 0,
  note                TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  KEY (item_id),
  FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE receipts (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  receipt_no    VARCHAR(20) NOT NULL UNIQUE,
  received_on   DATE NOT NULL,
  item_id       BIGINT NOT NULL,
  partner_id    BIGINT,
  qty           DECIMAL(14,3) NOT NULL CHECK (qty > 0),
  unit          VARCHAR(10) NOT NULL,
  base_qty      DECIMAL(14,3) NOT NULL CHECK (base_qty > 0),
  bulk_count    DECIMAL(10,2),
  unit_price    DECIMAL(14,2),
  lot_id        BIGINT NOT NULL,
  note          TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  KEY (received_on),
  FOREIGN KEY (item_id) REFERENCES items(id), FOREIGN KEY (partner_id) REFERENCES partners(id),
  FOREIGN KEY (lot_id) REFERENCES lots(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE production_logs (
  id               BIGINT AUTO_INCREMENT PRIMARY KEY,
  log_no           VARCHAR(20) NOT NULL UNIQUE,
  work_date        DATE NOT NULL,
  product_item_id  BIGINT NOT NULL,
  output_qty       DECIMAL(14,3) NOT NULL CHECK (output_qty > 0),
  defect_qty       DECIMAL(14,3) NOT NULL DEFAULT 0 CHECK (defect_qty >= 0),
  output_lot_id    BIGINT,
  workers          INT CHECK (workers > 0),
  segments         JSON,
  work_minutes     INT,
  issues           TEXT,
  suggestion       TEXT,
  note             TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  KEY (work_date), KEY (product_item_id),
  FOREIGN KEY (product_item_id) REFERENCES items(id), FOREIGN KEY (output_lot_id) REFERENCES lots(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE lots ADD CONSTRAINT lots_receipt_fk FOREIGN KEY (receipt_id) REFERENCES receipts(id);
ALTER TABLE lots ADD CONSTRAINT lots_production_fk FOREIGN KEY (production_log_id) REFERENCES production_logs(id);

CREATE TABLE production_steps (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  log_id       BIGINT NOT NULL,
  step_no      INT NOT NULL DEFAULT 1,
  step_name    VARCHAR(20) NOT NULL,
  input_kg     DECIMAL(12,3) NOT NULL CHECK (input_kg >= 0),
  output_kg    DECIMAL(12,3) NOT NULL CHECK (output_kg >= 0),
  loss_kg      DECIMAL(12,3) NOT NULL DEFAULT 0 CHECK (loss_kg >= 0),
  scrap_kg     DECIMAL(12,3) NOT NULL DEFAULT 0 CHECK (scrap_kg >= 0),
  loss_reason  VARCHAR(20) CHECK (loss_reason IN ('절단 자투리','파손','이물 선별','계량차','불량','기타')),
  yield_pct    DECIMAL(7,2) AS (CASE WHEN input_kg > 0 THEN ROUND(output_kg / input_kg * 100, 2) END) STORED,
  balance_kg   DECIMAL(12,3) AS (input_kg - output_kg - loss_kg - scrap_kg) STORED,
  note         TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  UNIQUE (log_id, step_no),
  FOREIGN KEY (log_id) REFERENCES production_logs(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE production_inputs (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  log_id       BIGINT NOT NULL,
  item_id      BIGINT NOT NULL,
  lot_id       BIGINT,
  planned_qty  DECIMAL(14,3),
  actual_qty   DECIMAL(14,3) NOT NULL CHECK (actual_qty >= 0),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  KEY (log_id),
  FOREIGN KEY (log_id) REFERENCES production_logs(id), FOREIGN KEY (item_id) REFERENCES items(id),
  FOREIGN KEY (lot_id) REFERENCES lots(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE lot_links (
  id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
  parent_lot_id      BIGINT NOT NULL,
  child_lot_id       BIGINT NOT NULL,
  production_log_id  BIGINT NOT NULL,
  qty_used           DECIMAL(14,3) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  KEY (parent_lot_id), KEY (child_lot_id),
  FOREIGN KEY (parent_lot_id) REFERENCES lots(id), FOREIGN KEY (child_lot_id) REFERENCES lots(id),
  FOREIGN KEY (production_log_id) REFERENCES production_logs(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stock_moves (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  moved_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  move_date   DATE NOT NULL,
  item_id     BIGINT NOT NULL,
  lot_id      BIGINT,
  qty         DECIMAL(14,3) NOT NULL CHECK (qty <> 0),
  move_type   VARCHAR(10) NOT NULL CHECK (move_type IN ('기초','입고','생산투입','생산산출','출고','조정','폐기','취소')),
  partner_id  BIGINT,
  ref_type    VARCHAR(30),
  ref_id      BIGINT,
  reverses_id BIGINT,
  reason      TEXT,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by  INT,
  KEY (item_id), KEY (lot_id), KEY (move_date), KEY (ref_type, ref_id),
  FOREIGN KEY (item_id) REFERENCES items(id), FOREIGN KEY (lot_id) REFERENCES lots(id),
  FOREIGN KEY (partner_id) REFERENCES partners(id), FOREIGN KEY (reverses_id) REFERENCES stock_moves(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='재고 원장: 추가만 가능';

CREATE TABLE audit_log (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  table_name    VARCHAR(50) NOT NULL,
  row_id        VARCHAR(50) NOT NULL,
  action        VARCHAR(10) NOT NULL CHECK (action IN ('INSERT','UPDATE','VOID')),
  changed_by    INT,
  changed_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  old_data      JSON,
  new_data      JSON,
  KEY (table_name, row_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='수정 이력: 추가만 가능';

CREATE TABLE doc_counters (
  prefix   VARCHAR(40) NOT NULL,
  day      DATE NOT NULL,
  last_no  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (prefix, day)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
