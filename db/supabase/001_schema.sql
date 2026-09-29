-- =====================================================================
-- SEA.D 업무통합 시스템 1단계 — Supabase(PostgreSQL) 테이블
-- 기준정보(품목·BOM·거래처) + 입고·재고이동·로트·생산일지 + 수정이력
--
-- 원칙
--  * 삭제 금지: 모든 테이블 DELETE 차단(트리거). 취소는 is_void + void_reason
--  * 재고는 stock_moves 합계로만 계산. stock_moves 는 추가만 가능(수정·삭제 불가)
--  * 모든 추가·수정·취소는 audit_log 에 자동 기록(누가·언제·전/후 값)
--  * 수량은 품목 기본단위(items.unit) 기준. 다른 단위 입력은 item_units 로 환산
-- =====================================================================

-- ---------------------------------------------------------------------
-- 사용자
-- ---------------------------------------------------------------------
create table profiles (
  id          uuid primary key references auth.users(id),
  name        text not null,
  role        text not null default 'staff' check (role in ('owner','staff')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
comment on table profiles is '사용자(로그인 계정과 1:1). role: owner=대표, staff=직원';

-- 공통 컬럼 규칙: created_at/created_by/updated_at/updated_by/is_void/void_reason/voided_at/voided_by

-- ---------------------------------------------------------------------
-- 거래처
-- ---------------------------------------------------------------------
create table partners (
  id            bigint generated always as identity primary key,
  code          text not null unique,                 -- 예: P-0001
  name          text not null,                        -- 정식 상호(세금계산서 표기)
  biz_no        text unique,                          -- 사업자등록번호 000-00-00000
  ceo_name      text,
  tax_code      text,                                 -- 세무사랑 거래처코드
  is_supplier   boolean not null default false,       -- 매입처
  is_customer   boolean not null default false,       -- 매출처
  category      text check (category in ('원물생산자','원재료','부재료','포장재','위탁제조','온라인채널','오프라인','B2B','B2G','도매','OEM','물류','경비·서비스','기타')),
  contact_name  text,
  phone         text,
  email         text,
  address       text,
  needs_review  boolean not null default false,       -- 확인필요 표시
  note          text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  check (biz_no is null or biz_no ~ '^\d{3}-\d{2}-\d{5}$')
);
comment on table partners is '거래처(매입처·매출처). 사업자번호가 같으면 같은 거래처';

create table partner_aliases (
  id          bigint generated always as identity primary key,
  partner_id  bigint not null references partners(id),
  alias       text not null unique,                   -- 다른 파일에서 쓰는 이름(예: 유은아, 동서PL)
  source      text,                                   -- 어느 자료에서 왔는지
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

-- ---------------------------------------------------------------------
-- 품목
-- ---------------------------------------------------------------------
create table items (
  id                 bigint generated always as identity primary key,
  code               text not null unique,            -- RM-01, BY-01, SP-01, FG-01, SET-01, PK-B-01 ...
  name               text not null,
  item_type          text not null check (item_type in ('RAW','SUB','PACK','SEMI','FG')),
                                                      -- 원재료 / 부재료(가공원재료) / 포장재 / 반제품 / 완제품
  pack_kind          text check (pack_kind in ('박스','카톤','포장지','인쇄물','라벨','기타')),
  is_set             boolean not null default false,  -- 완제품 중 선물세트
  unit               text not null,                   -- 기본단위: kg, g, ea, 매, 롤, 속 ...
  spec               text,                            -- 규격 문구: 150g, 20g×3 ...
  size               text,                            -- 치수: 470x90x380, 24*34
  model              text,                            -- 카톤 모델명 등
  net_weight_g       numeric(12,3),                   -- 개당 순중량(g) — 수율 계산용
  safety_stock       numeric(14,3) not null default 0,
  shelf_life_months  int,                             -- 소비기한 개월(미역·다시마 36, 원물 건조일 기준)
  origin             text,                            -- 원산지
  storage            text,                            -- 보관위치
  procure_type       text check (procure_type in ('자사생산','OEM위탁','도매상품','완제품납품','매입')),
  sale_type          text,                            -- 세트구성 / 단품 / 완제품납품 ...
  status             text not null default '판매중' check (status in ('판매중','준비','단종','사용')),
  hs_code            text,
  retail_price       numeric(12,0),                   -- 소비자가
  box_qty            int,                             -- 박스(카톤) 입수
  needs_review       boolean not null default false,
  note               text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);
comment on table items is '품목. item_type: RAW 원재료, SUB 부재료(참기름·간장 등), PACK 포장재, SEMI 반제품, FG 완제품';

create table item_aliases (
  id        bigint generated always as identity primary key,
  item_id   bigint not null references items(id),
  alias     text not null unique,
  source    text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

create table item_units (                             -- 단위 환산: 1 unit = factor × 기본단위
  id        bigint generated always as identity primary key,
  item_id   bigint not null references items(id),
  unit      text not null,                            -- 예: 롤, 묶음, 박스
  factor    numeric(14,4) not null check (factor > 0),-- 예: 하트미역 1롤 = 4000 ea, 건미역 1묶음 = 10 kg
  note      text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  unique (item_id, unit)
);

create table item_suppliers (                         -- 품목별 공급처(여러 곳 가능)
  id          bigint generated always as identity primary key,
  item_id     bigint not null references items(id),
  partner_id  bigint not null references partners(id),
  unit_price  numeric(14,2),                          -- 매입단가(기본단위당)
  is_primary  boolean not null default false,
  note        text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  unique (item_id, partner_id)
);

create table bom (                                    -- 구성: 상위 1개당 하위 소요량
  id              bigint generated always as identity primary key,
  parent_item_id  bigint not null references items(id),
  child_item_id   bigint not null references items(id),
  qty_per         numeric(14,4) not null check (qty_per > 0),  -- 하위 품목 기본단위 기준
  step            text check (step in ('내포장','외포장')),
  loss_rate       numeric(6,3) not null default 0 check (loss_rate >= 0 and loss_rate < 100), -- % (원재료 로스 반영)
  alt_group       text,                               -- 같은 값끼리 대체 가능(예: 대멸/소멸)
  sort            int not null default 0,
  note            text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  check (parent_item_id <> child_item_id),
  unique (parent_item_id, child_item_id)
);

create table production_standards (                   -- 표준 수율·작업시간 (5회 평균으로 확정 예정)
  id              bigint generated always as identity primary key,
  item_id         bigint not null references items(id),
  step            text not null default '내포장',
  std_yield_pct   numeric(6,2),
  std_sec_per_ea  numeric(10,2),
  bulk_unit_kg    numeric(10,3),                      -- 벌크 입고 단위(미역 10, 다시마 20)
  sample_count    int not null default 0,
  is_provisional  boolean not null default true,      -- 임시값(1회 실측)
  source          text,
  note            text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  unique (item_id, step)
);

-- ---------------------------------------------------------------------
-- 로트 · 입고 · 생산 · 재고이동
-- ---------------------------------------------------------------------
create table lots (
  id                  bigint generated always as identity primary key,
  lot_no              text not null unique,           -- RM-260929-01 / IP-SP-02-260929-01 / FP-FG-01-260929-01
  item_id             bigint not null references items(id),
  source              text not null check (source in ('입고','생산','기초','조정')),
  dried_date          date,                           -- 원물 건조일(소비기한 기산일) — 생산로트는 투입 로트 중 가장 이른 날 상속
  expiry_date         date,                           -- 소비기한(비우면 건조일 + 소비기한개월 자동)
  made_on             date,                           -- 입고일 또는 생산일
  receipt_id          bigint,                         -- 입고로트: receipts.id
  production_log_id   bigint,                         -- 생산로트: production_logs.id
  mixed_dried_dates   boolean not null default false, -- 건조일이 다른 로트가 섞여 투입됨(경고)
  note                text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

create table receipts (
  id            bigint generated always as identity primary key,
  receipt_no    text not null unique,                 -- R-260929-01
  received_on   date not null,
  item_id       bigint not null references items(id),
  partner_id    bigint references partners(id),
  qty           numeric(14,3) not null check (qty > 0),  -- 입력 단위 수량
  unit          text not null,                        -- 입력 단위
  base_qty      numeric(14,3) not null check (base_qty > 0), -- 기본단위 환산 수량
  bulk_count    numeric(10,2),                        -- 묶음/장 수
  unit_price    numeric(14,2),
  lot_id        bigint not null references lots(id),
  note          text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

create table production_logs (
  id               bigint generated always as identity primary key,
  log_no           text not null unique,              -- W-260929-01
  work_date        date not null,
  product_item_id  bigint not null references items(id),
  output_qty       numeric(14,3) not null check (output_qty > 0), -- 양품 산출 수량(기본단위)
  defect_qty       numeric(14,3) not null default 0 check (defect_qty >= 0),
  output_lot_id    bigint references lots(id),
  workers          int check (workers > 0),
  segments         jsonb,                             -- 작업구간 [{"start":"08:30","end":"11:30"}, ...]
  work_minutes     int,                               -- 점심(11:30~12:30) 제외 자동 계산
  issues           text,                              -- 작업중 애로사항
  suggestion       text,                              -- 개선제안
  note             text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

alter table lots add constraint lots_receipt_fk foreign key (receipt_id) references receipts(id);
alter table lots add constraint lots_production_fk foreign key (production_log_id) references production_logs(id);

create table production_steps (                       -- 단계별 중량 실적 → 수율 자동 계산
  id           bigint generated always as identity primary key,
  log_id       bigint not null references production_logs(id),
  step_no      int not null default 1,
  step_name    text not null,                         -- 절단·소분 / 내포장 / 외포장
  input_kg     numeric(12,3) not null check (input_kg >= 0),
  output_kg    numeric(12,3) not null check (output_kg >= 0),
  loss_kg      numeric(12,3) not null default 0 check (loss_kg >= 0),
  scrap_kg     numeric(12,3) not null default 0 check (scrap_kg >= 0), -- 재사용 자투리(20cm 이하 → 20g)
  loss_reason  text check (loss_reason in ('절단 자투리','파손','이물 선별','계량차','불량','기타')),
  yield_pct    numeric(7,2) generated always as (case when input_kg > 0 then round(output_kg / input_kg * 100, 2) end) stored,
  balance_kg   numeric(12,3) generated always as (input_kg - output_kg - loss_kg - scrap_kg) stored, -- 물질수지 차이
  note         text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  unique (log_id, step_no)
);

create table production_inputs (                      -- 투입 내역(로트별)
  id           bigint generated always as identity primary key,
  log_id       bigint not null references production_logs(id),
  item_id      bigint not null references items(id),
  lot_id       bigint references lots(id),            -- 재고 없는 상태로 투입하면 null(경고)
  planned_qty  numeric(14,3),                         -- BOM 기준
  actual_qty   numeric(14,3) not null check (actual_qty >= 0),
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

create table lot_links (                              -- 로트 계보: 투입 로트 → 생산 로트
  id                 bigint generated always as identity primary key,
  parent_lot_id      bigint not null references lots(id),
  child_lot_id       bigint not null references lots(id),
  production_log_id  bigint not null references production_logs(id),
  qty_used           numeric(14,3) not null,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

create table stock_moves (                            -- 재고 원장: 추가만 가능
  id          bigint generated always as identity primary key,
  moved_at    timestamptz not null default now(),
  move_date   date not null default current_date,
  item_id     bigint not null references items(id),
  lot_id      bigint references lots(id),
  qty         numeric(14,3) not null check (qty <> 0),  -- + 증가 / - 감소 (기본단위)
  move_type   text not null check (move_type in ('기초','입고','생산투입','생산산출','출고','조정','폐기','취소')),
  partner_id  bigint references partners(id),          -- 출고처 등
  ref_type    text,                                    -- receipts / production_logs / ...
  ref_id      bigint,
  reverses_id bigint references stock_moves(id),       -- 취소로 되돌린 원래 이동
  reason      text,
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid() references profiles(id)
);

create table audit_log (                              -- 수정 이력: 추가만 가능
  id          bigint generated always as identity primary key,
  table_name  text not null,
  row_id      text not null,
  action      text not null check (action in ('INSERT','UPDATE','VOID')),
  changed_by  uuid,
  changed_at  timestamptz not null default now(),
  old_data    jsonb,
  new_data    jsonb,
  changed_cols text[]
);

create table doc_counters (                           -- 문서번호 발급용
  prefix  text not null,
  day     date not null,
  last_no int not null default 0,
  primary key (prefix, day)
);

-- 조회용 색인
create index on stock_moves (item_id);
create index on stock_moves (lot_id);
create index on stock_moves (move_date);
create index on lots (item_id);
create index on receipts (received_on);
create index on production_logs (work_date);
create index on production_logs (product_item_id);
create index on production_inputs (log_id);
create index on lot_links (parent_lot_id);
create index on lot_links (child_lot_id);
create index on bom (parent_item_id);
create index on audit_log (table_name, row_id);
