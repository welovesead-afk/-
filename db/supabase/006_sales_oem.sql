-- =====================================================================
-- 판매(주문) · 기타주문 · 받는 사람 개인정보 분리 · OEM 별도 관리 · 장부 가져오기 기록
--
--  * 주문 구분 channel_type: 기업 / 개인 / 기타주문 / OEM납품
--      - 기업   : 컬리·아난티·파라다이스호텔 등 묶음 납품
--      - 개인   : 선관위·제낭조합·숨비해물처럼 사이트(기관)별 개인고객 개별 배송
--      - 기타주문: '전화 및 기타 주문' 장부 — 개인·기업이 섞여 있어 별도 관리
--      - OEM납품: 와이즐리 PB 등 고객사 전용품 납품
--  * 받는 사람 이름·연락처·주소는 sales_recipients 에 따로 저장 → 대표만 원문 조회,
--    직원은 v_sales_list 에서 이름 일부가 가려진 값만 봄
--  * OEM: items.oem_type = 'OEM매입'(다른 곳이 만들어 납품) / 'OEM납품'(씨드가 만들어 고객사에 납품)
-- =====================================================================

-- OEM 별도 관리
alter table items add column oem_type text check (oem_type in ('OEM매입','OEM납품'));
alter table items add column oem_partner_id bigint references partners(id);   -- 위탁 제조사 또는 납품 고객사
comment on column items.oem_type is 'OEM매입: 위탁 제조해 받아 오는 품목 / OEM납품: 씨드가 만들어 고객사에 납품하는 전용품';

-- 주문
create table sales_orders (
  id                  bigint generated always as identity primary key,
  order_no            text not null unique,              -- S-260929-01
  channel_type        text not null check (channel_type in ('기업','개인','기타주문','OEM납품')),
  channel_partner_id  bigint references partners(id),    -- 판매처(장부 탭): 컬리, 선관위, 전화 및 기타 ...
  order_date          date,
  ship_date           date,
  destination         text,                              -- 받는 곳(매장·창고·기관): 아난티코브 모비딕마켓, 평택상온
  delivery_method     text,                              -- 택배 / 직접수령 / 화물 ...
  writer              text,                              -- 장부 작성자
  note                text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);

-- 받는 사람(개인정보) — 대표만 조회
create table sales_recipients (
  order_id        bigint primary key references sales_orders(id),
  recipient_name  text,                                  -- 받는 사람(직함 포함 가능)
  recipient_org   text,                                  -- 소속
  phone           text,
  address         text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id)
);
comment on table sales_recipients is '주문 받는 사람 개인정보. 대표만 원문 조회(RLS), 직원은 v_sales_list 의 가린 값';

-- 주문 품목
create table sales_lines (
  id              bigint generated always as identity primary key,
  order_id        bigint not null references sales_orders(id),
  line_no         int not null,
  item_id         bigint references items(id),           -- 품목 대응이 확정되기 전에는 비어 있을 수 있음
  item_text       text not null,                         -- 장부 원래 표기
  qty             numeric(14,3) not null check (qty > 0),
  unit            text,
  unit_price      numeric(14,2),
  supply_amount   numeric(14,0),
  vat             numeric(14,0),
  tax_type        text not null default '미정' check (tax_type in ('과세','면세','미정')),
  shipping_fee    numeric(14,0),
  total           numeric(14,0),
  shipped         boolean not null default false,        -- 재고 출고 처리됨
  note            text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid() references profiles(id),
  updated_at timestamptz, updated_by uuid references profiles(id),
  is_void boolean not null default false, void_reason text, voided_at timestamptz, voided_by uuid references profiles(id),
  unique (order_id, line_no)
);

-- 장부 가져오기 기록 (같은 줄 두 번 가져오기 방지, 원본 위치 보존)
create table import_rows (
  id            bigint generated always as identity primary key,
  source_key    text not null,                           -- 예: 2026-02/매출/컬리
  row_no        int not null,
  kind          text not null check (kind in ('sales','raw','pack','supplies')),
  raw           jsonb not null,
  target_table  text,
  target_id     bigint,
  imported_at   timestamptz not null default now(),
  imported_by   uuid default auth.uid(),
  unique (source_key, row_no)
);

create index on sales_orders (ship_date);
create index on sales_orders (channel_partner_id);
create index on sales_lines (order_id);
create index on sales_lines (item_id);

-- 수정이력·삭제금지 트리거 (002와 같은 규칙)
do $$
declare t text;
begin
  foreach t in array array['sales_orders','sales_recipients','sales_lines']
  loop
    execute format('create trigger %1$s_touch before update on %1$I for each row execute function trg_touch()', t);
    execute format('create trigger %1$s_audit after insert or update on %1$I for each row execute function trg_audit()', t);
    execute format('create trigger %1$s_nodelete before delete on %1$I for each row execute function trg_block_delete()', t);
  end loop;
  execute 'create trigger import_rows_nodelete before delete on import_rows for each row execute function trg_block_delete()';
  execute 'create trigger import_rows_noupdate before update on import_rows for each row execute function trg_block_update()';
end $$;

-- 출고 처리된 품목 줄은 수량·품목 직접 수정 금지
create or replace function trg_lock_sales_line() returns trigger
language plpgsql as $$
begin
  if old.shipped and (new.item_id, new.qty) is distinct from (old.item_id, old.qty) then
    raise exception '출고 처리된 품목·수량은 직접 수정할 수 없습니다. 주문을 취소 후 다시 등록하세요.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger sales_lines_lock before update on sales_lines for each row execute function trg_lock_sales_line();

-- ---------------------------------------------------------------------
-- 이름 가리기: 마지막 낱말(이름)만 첫 글자 + ○  예) '중앙선관위 사무총장 허철훈' → '중앙선관위 사무총장 허○○'
-- ---------------------------------------------------------------------
create or replace function mask_name(p text) returns text
language sql immutable as $$
  select case
    when p is null or btrim(p) = '' then p
    else regexp_replace(btrim(p), '(\S)(\S*)$', '') ||
         left(substring(btrim(p) from '(\S+)$'), 1) ||
         repeat('○', greatest(char_length(substring(btrim(p) from '(\S+)$')) - 1, 1))
  end
$$;
create or replace function mask_phone(p text) returns text
language sql immutable as $$
  select case when p is null then null else regexp_replace(p, '(\d{2,3})[- ]?\d{3,4}[- ]?(\d{4})', '\1-****-\2') end
$$;

-- ---------------------------------------------------------------------
-- 판매 등록: 주문 + 품목 + (받는 사람) + 출고일이 있으면 재고 출고(선입선출)
--   p_order  : {"channel_type":"기업","channel_partner_id":1,"order_date":"2026-01-02","ship_date":"2026-01-02",
--               "destination":"아난티코브 모비딕마켓","delivery_method":"택배","writer":"정지영","note":null}
--   p_lines  : [{"item_id":5,"item_text":"하트미역_20g","qty":50,"unit":"EA","unit_price":1050,"supply_amount":52500,
--               "vat":0,"tax_type":"면세","shipping_fee":null,"total":52500,"note":null}, ...]
--   p_recipient: {"recipient_name":"...","recipient_org":"...","phone":"...","address":"..."} 또는 null
-- ---------------------------------------------------------------------
create or replace function register_sale(p_order jsonb, p_lines jsonb, p_recipient jsonb default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id bigint; v_no text; v_day date; v_ship date; s jsonb; v_line_id bigint; v_n int := 0;
  a record; v_item bigint; v_qty numeric; v_warn text[] := '{}'; v_unmapped int := 0;
begin
  perform require_user();
  if p_lines is null or jsonb_array_length(p_lines) = 0 then raise exception '주문 품목이 없습니다.'; end if;
  v_ship := nullif(p_order ->> 'ship_date', '')::date;
  v_day := coalesce(v_ship, nullif(p_order ->> 'order_date', '')::date, current_date);
  v_no := next_no('S', v_day);
  insert into sales_orders (order_no, channel_type, channel_partner_id, order_date, ship_date, destination, delivery_method, writer, note)
  values (v_no, p_order ->> 'channel_type', nullif(p_order ->> 'channel_partner_id', '')::bigint,
          nullif(p_order ->> 'order_date', '')::date, v_ship, p_order ->> 'destination', p_order ->> 'delivery_method',
          p_order ->> 'writer', p_order ->> 'note')
  returning id into v_id;

  if p_recipient is not null and coalesce(p_recipient ->> 'recipient_name', p_recipient ->> 'recipient_org',
                                          p_recipient ->> 'phone', p_recipient ->> 'address') is not null then
    insert into sales_recipients (order_id, recipient_name, recipient_org, phone, address)
    values (v_id, p_recipient ->> 'recipient_name', p_recipient ->> 'recipient_org', p_recipient ->> 'phone', p_recipient ->> 'address');
  end if;

  for s in select * from jsonb_array_elements(p_lines) loop
    v_n := v_n + 1;
    v_item := nullif(s ->> 'item_id', '')::bigint;
    v_qty := (s ->> 'qty')::numeric;
    insert into sales_lines (order_id, line_no, item_id, item_text, qty, unit, unit_price, supply_amount, vat, tax_type,
                             shipping_fee, total, note)
    values (v_id, v_n, v_item, coalesce(s ->> 'item_text', (select name from items where id = v_item)), v_qty, s ->> 'unit',
            nullif(s ->> 'unit_price', '')::numeric, nullif(s ->> 'supply_amount', '')::numeric, nullif(s ->> 'vat', '')::numeric,
            coalesce(nullif(s ->> 'tax_type', ''), '미정'), nullif(s ->> 'shipping_fee', '')::numeric,
            nullif(s ->> 'total', '')::numeric, s ->> 'note')
    returning id into v_line_id;

    if v_item is null then
      v_unmapped := v_unmapped + 1;
    elsif v_ship is not null then
      for a in select * from allocate_fefo(v_item, v_qty) loop
        insert into stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id)
        values (v_ship, v_item, a.lot_id, -a.qty, '출고', nullif(p_order ->> 'channel_partner_id', '')::bigint, 'sales_lines', v_line_id);
        if a.lot_id is null then
          v_warn := v_warn || format('%s 재고 부족: %s 을(를) 로트 없이 출고했습니다.', (select name from items where id = v_item), a.qty);
        end if;
      end loop;
      update sales_lines set shipped = true where id = v_line_id;
    end if;
  end loop;

  if v_unmapped > 0 then
    v_warn := v_warn || format('품목이 확정되지 않은 줄 %s개는 재고 출고를 하지 않았습니다(품목 확정 후 출고).', v_unmapped);
  end if;
  return jsonb_build_object('order_id', v_id, 'order_no', v_no, 'lines', v_n, 'warnings', to_jsonb(v_warn));
end $$;

-- 품목이 나중에 확정된 줄 출고 처리
create or replace function ship_sales_line(p_line_id bigint, p_item_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v sales_lines%rowtype; o sales_orders%rowtype; a record; v_warn text[] := '{}';
begin
  perform require_user();
  select * into v from sales_lines where id = p_line_id for update;
  if not found or v.is_void then raise exception '주문 품목 줄이 없거나 취소되었습니다.'; end if;
  if v.shipped then raise exception '이미 출고 처리된 줄입니다.'; end if;
  select * into o from sales_orders where id = v.order_id;
  update sales_lines set item_id = p_item_id where id = v.id;
  for a in select * from allocate_fefo(p_item_id, v.qty) loop
    insert into stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id)
    values (coalesce(o.ship_date, current_date), p_item_id, a.lot_id, -a.qty, '출고', o.channel_partner_id, 'sales_lines', v.id);
    if a.lot_id is null then v_warn := v_warn || format('재고 부족: %s 을(를) 로트 없이 출고했습니다.', a.qty); end if;
  end loop;
  update sales_lines set shipped = true where id = v.id;
  return jsonb_build_object('line_id', v.id, 'warnings', to_jsonb(v_warn));
end $$;

create or replace function void_sale(p_order_id bigint, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o sales_orders%rowtype; l record;
begin
  perform require_user();
  select * into o from sales_orders where id = p_order_id for update;
  if not found or o.is_void then raise exception '취소할 주문이 없거나 이미 취소되었습니다.'; end if;
  if not can_void(o.created_by, o.created_at) then raise exception '직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception '취소 사유를 입력하세요.'; end if;
  for l in select id from sales_lines where order_id = o.id loop
    perform reverse_moves('sales_lines', l.id, p_reason);
  end loop;
  update sales_lines set is_void = true, void_reason = p_reason where order_id = o.id;
  update sales_recipients set is_void = true, void_reason = p_reason where order_id = o.id;
  update sales_orders set is_void = true, void_reason = p_reason where id = o.id;
  return jsonb_build_object('order_no', o.order_no, 'voided', true);
end $$;

-- ---------------------------------------------------------------------
-- 조회: 주문 목록 (대표 = 원문, 직원 = 가린 값)
--   RLS 를 거치지 않는 뷰이므로 활성 사용자만 행이 보이도록 직접 거름
-- ---------------------------------------------------------------------
create or replace view v_sales_list as
select o.id, o.order_no, o.channel_type, p.name as channel_name, o.order_date, o.ship_date, o.destination,
       o.delivery_method, o.writer, o.note, o.is_void, o.void_reason,
       case when is_owner() then r.recipient_name else mask_name(r.recipient_name) end as recipient_name,
       r.recipient_org,
       case when is_owner() then r.phone else mask_phone(r.phone) end as phone,
       case when is_owner() then r.address else case when r.address is null then null else split_part(r.address, ' ', 1) || ' …' end end as address,
       (select count(*) from sales_lines l where l.order_id = o.id and not l.is_void)                      as line_count,
       (select sum(l.qty) from sales_lines l where l.order_id = o.id and not l.is_void)                     as qty_total,
       (select sum(coalesce(l.total, l.supply_amount)) from sales_lines l where l.order_id = o.id and not l.is_void) as amount_total,
       (select count(*) from sales_lines l where l.order_id = o.id and not l.is_void and l.item_id is null) as unmapped_lines
  from sales_orders o
  left join partners p on p.id = o.channel_partner_id
  left join sales_recipients r on r.order_id = o.id and not r.is_void
 where is_active_user();

-- 월별 판매 집계(구분·판매처별)
create or replace view v_sales_monthly with (security_invoker = true) as
select date_trunc('month', coalesce(o.ship_date, o.order_date))::date as month,
       o.channel_type, p.name as channel_name,
       count(distinct o.id) as orders, sum(l.qty) as qty,
       sum(coalesce(l.total, l.supply_amount)) as amount,
       count(*) filter (where l.total is null and l.supply_amount is null) as lines_without_amount
  from sales_orders o
  join sales_lines l on l.order_id = o.id and not l.is_void
  left join partners p on p.id = o.channel_partner_id
 where not o.is_void
 group by 1, 2, 3;

-- OEM 품목 목록(별도 관리)
create or replace view v_oem_items with (security_invoker = true) as
select i.id as item_id, i.code, i.name, i.oem_type, p.name as oem_partner, i.unit, s.stock_qty, i.safety_stock, s.below_safety
  from items i
  left join partners p on p.id = i.oem_partner_id
  left join v_item_stock s on s.item_id = i.id
 where i.oem_type is not null and not i.is_void;

-- ---------------------------------------------------------------------
-- 권한
-- ---------------------------------------------------------------------
alter table sales_orders enable row level security;
alter table sales_recipients enable row level security;
alter table sales_lines enable row level security;
alter table import_rows enable row level security;
revoke all on sales_orders, sales_recipients, sales_lines, import_rows from anon;
revoke delete, truncate, insert, update on sales_orders, sales_recipients, sales_lines, import_rows from authenticated;

create policy sales_orders_read on sales_orders for select to authenticated using (is_active_user());
create policy sales_lines_read on sales_lines for select to authenticated using (is_active_user());
create policy sales_recipients_owner on sales_recipients for select to authenticated using (is_owner());   -- 원문은 대표만
create policy import_rows_owner on import_rows for select to authenticated using (is_owner());

revoke all on v_sales_list from anon;
grant select on v_sales_list, v_sales_monthly, v_oem_items to authenticated;
revoke execute on function register_sale(jsonb, jsonb, jsonb), ship_sales_line(bigint, bigint), void_sale(bigint, text),
       mask_name(text), mask_phone(text) from public, anon;
grant execute on function register_sale(jsonb, jsonb, jsonb), ship_sales_line(bigint, bigint), void_sale(bigint, text) to authenticated;
