-- =====================================================================
-- 판매(주문) · 기타주문 · 받는 사람 개인정보 분리 · OEM 별도 관리 · 장부 가져오기 기록
-- Supabase 버전 db/supabase/006_sales_oem.sql 과 같은 테이블·컬럼
--  * 받는 사람 원문(sales_recipients)은 PHP API에서 대표에게만 제공, 직원은 v_sales_list 의 가린 값
-- =====================================================================
SET NAMES utf8mb4;

ALTER TABLE items
  ADD COLUMN oem_type VARCHAR(10) CHECK (oem_type IN ('OEM매입','OEM납품')),
  ADD COLUMN oem_partner_id BIGINT,
  ADD CONSTRAINT items_oem_partner_fk FOREIGN KEY (oem_partner_id) REFERENCES partners(id);

CREATE TABLE sales_orders (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_no            VARCHAR(20) NOT NULL UNIQUE,
  channel_type        VARCHAR(10) NOT NULL CHECK (channel_type IN ('기업','개인','기타주문','OEM납품')),
  channel_partner_id  BIGINT,
  order_date          DATE,
  ship_date           DATE,
  destination         VARCHAR(200),
  delivery_method     VARCHAR(50),
  writer              VARCHAR(50),
  note                TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  KEY (ship_date), KEY (channel_partner_id),
  FOREIGN KEY (channel_partner_id) REFERENCES partners(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='판매 주문. 기업/개인/기타주문/OEM납품';

CREATE TABLE sales_recipients (
  order_id        BIGINT PRIMARY KEY,
  recipient_name  VARCHAR(200),
  recipient_org   VARCHAR(200),
  phone           VARCHAR(50),
  address         VARCHAR(300),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  FOREIGN KEY (order_id) REFERENCES sales_orders(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='받는 사람 개인정보 — 대표만 원문';

CREATE TABLE sales_lines (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_id        BIGINT NOT NULL,
  line_no         INT NOT NULL,
  item_id         BIGINT,
  item_text       VARCHAR(300) NOT NULL,
  qty             DECIMAL(14,3) NOT NULL CHECK (qty > 0),
  unit            VARCHAR(10),
  unit_price      DECIMAL(14,2),
  supply_amount   DECIMAL(14,0),
  vat             DECIMAL(14,0),
  tax_type        VARCHAR(4) NOT NULL DEFAULT '미정' CHECK (tax_type IN ('과세','면세','미정')),
  shipping_fee    DECIMAL(14,0),
  total           DECIMAL(14,0),
  shipped         TINYINT(1) NOT NULL DEFAULT 0,
  note            TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INT,
  updated_at DATETIME, updated_by INT,
  is_void TINYINT(1) NOT NULL DEFAULT 0, void_reason TEXT, voided_at DATETIME, voided_by INT,
  UNIQUE (order_id, line_no), KEY (item_id),
  FOREIGN KEY (order_id) REFERENCES sales_orders(id), FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE import_rows (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_key    VARCHAR(200) NOT NULL,
  row_no        INT NOT NULL,
  kind          VARCHAR(10) NOT NULL CHECK (kind IN ('sales','raw','pack','supplies')),
  raw           JSON NOT NULL,
  target_table  VARCHAR(50),
  target_id     BIGINT,
  imported_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  imported_by   INT,
  UNIQUE (source_key, row_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='장부 가져오기 기록 — 같은 줄 두 번 가져오기 방지';
