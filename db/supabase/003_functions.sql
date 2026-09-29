-- =====================================================================
-- 업무 처리 함수 (화면은 이 함수만 호출 → 한 번에 저장/차감/로트연결)
--   register_receipt     입고 등록 → 로트 생성 + 재고 증가
--   register_production  생산일지 → BOM 기준 투입 자동 차감(건조일 빠른 로트부터) + 산출 로트 + 재고 증가
--   register_move        출고·조정·폐기·기초재고
--   void_receipt / void_production  취소(반대 기록으로 재고 원복)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 공통 도우미
-- ---------------------------------------------------------------------
create or replace function app_role() returns text
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid() and active
$$;

create or replace function require_user() returns text
language plpgsql stable security definer set search_path = public as $$
declare v_role text := app_role();
begin
  if v_role is null then
    raise exception '로그인이 필요하거나 사용이 중지된 계정입니다.' using errcode = '42501';
  end if;
  return v_role;
end $$;

-- 문서번호: PREFIX-YYMMDD-NN
create or replace function next_no(p_prefix text, p_day date) returns text
language plpgsql security definer set search_path = public as $$
declare v_no int;
begin
  insert into doc_counters as c (prefix, day, last_no) values (p_prefix, p_day, 1)
  on conflict (prefix, day) do update set last_no = c.last_no + 1
  returning last_no into v_no;
  return p_prefix || '-' || to_char(p_day, 'YYMMDD') || '-' || lpad(v_no::text, 2, '0');
end $$;

-- 입력 단위 → 기본단위 환산
create or replace function to_base_qty(p_item_id bigint, p_qty numeric, p_unit text) returns numeric
language plpgsql stable security definer set search_path = public as $$
declare v_base text; v_factor numeric;
begin
  select unit into v_base from items where id = p_item_id;
  if v_base is null then raise exception '품목(id=%)이 없습니다.', p_item_id; end if;
  if p_unit is null or p_unit = v_base then return p_qty; end if;
  select factor into v_factor from item_units where item_id = p_item_id and unit = p_unit and not is_void;
  if v_factor is null then
    raise exception '단위 "%"를 기본단위 "%"로 환산할 수 없습니다. 품목 단위환산(item_units)을 등록하세요.', p_unit, v_base;
  end if;
  return p_qty * v_factor;
end $$;

create or replace function lot_balance(p_lot_id bigint) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(sum(qty), 0) from stock_moves where lot_id = p_lot_id
$$;

-- 점심(11:30~12:30) 제외 작업시간(분)
create or replace function work_minutes(p_segments jsonb) returns int
language plpgsql immutable as $$
declare s jsonb; v_total int := 0; v_s time; v_e time; v_overlap int;
begin
  if p_segments is null or jsonb_typeof(p_segments) <> 'array' then return null; end if;
  for s in select * from jsonb_array_elements(p_segments) loop
    v_s := (s ->> 'start')::time; v_e := (s ->> 'end')::time;
    if v_s is null or v_e is null or v_e <= v_s then continue; end if;
    v_overlap := greatest(0, extract(epoch from (least(v_e, time '12:30') - greatest(v_s, time '11:30')))::int / 60);
    v_total := v_total + extract(epoch from (v_e - v_s))::int / 60 - v_overlap;
  end loop;
  return v_total;
end $$;

-- 선입선출 배분: 소비기한(없으면 건조일·입고일) 빠른 로트부터
-- 반환: (lot_id, qty) 목록. 재고가 모자라면 마지막 줄 lot_id = null
create or replace function allocate_fefo(p_item_id bigint, p_qty numeric)
returns table (lot_id bigint, qty numeric)
language plpgsql stable security definer set search_path = public as $$
declare r record; v_left numeric := p_qty; v_take numeric;
begin
  for r in
    select l.id, b.bal
      from lots l
      join lateral (select coalesce(sum(m.qty), 0) bal from stock_moves m where m.lot_id = l.id) b on true
     where l.item_id = p_item_id and not l.is_void and b.bal > 0
     order by coalesce(l.expiry_date, l.dried_date, l.made_on) nulls last, l.id
  loop
    exit when v_left <= 0;
    v_take := least(r.bal, v_left);
    lot_id := r.id; qty := v_take; return next;
    v_left := v_left - v_take;
  end loop;
  if v_left > 0 then
    lot_id := null; qty := v_left; return next;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 입고 등록
-- ---------------------------------------------------------------------
create or replace function register_receipt(
  p_item_id      bigint,
  p_qty          numeric,
  p_received_on  date    default current_date,
  p_unit         text    default null,      -- 비우면 품목 기본단위
  p_lot_no       text    default null,      -- 비우면 자동(RM-YYMMDD-NN). 기존 로트번호면 그 로트에 추가
  p_partner_id   bigint  default null,
  p_dried_date   date    default null,      -- 원물 건조일(소비기한 기산)
  p_expiry_date  date    default null,
  p_bulk_count   numeric default null,
  p_unit_price   numeric default null,
  p_note         text    default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_item items%rowtype;
  v_unit text; v_base numeric; v_lot lots%rowtype; v_receipt_id bigint; v_receipt_no text;
  v_prefix text; v_warn text[] := '{}';
begin
  perform require_user();
  select * into v_item from items where id = p_item_id and not is_void;
  if not found then raise exception '품목을 찾을 수 없습니다.'; end if;
  if p_qty is null or p_qty <= 0 then raise exception '수량은 0보다 커야 합니다.'; end if;

  v_unit := coalesce(nullif(btrim(p_unit), ''), v_item.unit);
  v_base := to_base_qty(p_item_id, p_qty, v_unit);

  if nullif(btrim(p_lot_no), '') is not null then
    select * into v_lot from lots where lot_no = btrim(p_lot_no);
    if found then
      if v_lot.item_id <> p_item_id then raise exception '로트 %는 다른 품목의 로트입니다.', p_lot_no; end if;
      if v_lot.is_void then raise exception '로트 %는 취소된 로트입니다.', p_lot_no; end if;
      v_warn := v_warn || format('기존 로트 %s에 수량을 추가했습니다.', v_lot.lot_no);
    end if;
  end if;

  if v_lot.id is null then
    v_prefix := case v_item.item_type when 'RAW' then 'RM' when 'SUB' then 'BY' when 'PACK' then 'PK' else 'GR' end;
    insert into lots (lot_no, item_id, source, dried_date, expiry_date, made_on)
    values (coalesce(nullif(btrim(p_lot_no), ''), next_no(v_prefix, p_received_on)),
            p_item_id, '입고', p_dried_date, p_expiry_date, p_received_on)
    returning * into v_lot;
  end if;

  if v_item.item_type = 'RAW' and v_lot.dried_date is null then
    v_warn := v_warn || '원재료 건조일이 비어 있어 소비기한을 계산하지 못했습니다.';
  end if;

  v_receipt_no := next_no('R', p_received_on);
  insert into receipts (receipt_no, received_on, item_id, partner_id, qty, unit, base_qty, bulk_count, unit_price, lot_id, note)
  values (v_receipt_no, p_received_on, p_item_id, p_partner_id, p_qty, v_unit, v_base, p_bulk_count, p_unit_price, v_lot.id, p_note)
  returning id into v_receipt_id;

  update lots set receipt_id = coalesce(receipt_id, v_receipt_id) where id = v_lot.id and receipt_id is null;

  insert into stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id)
  values (p_received_on, p_item_id, v_lot.id, v_base, '입고', p_partner_id, 'receipts', v_receipt_id);

  return jsonb_build_object('receipt_id', v_receipt_id, 'receipt_no', v_receipt_no,
                            'lot_id', v_lot.id, 'lot_no', v_lot.lot_no, 'base_qty', v_base,
                            'warnings', to_jsonb(v_warn));
end $$;

-- ---------------------------------------------------------------------
-- 생산일지 등록
--   p_inputs : null 이면 BOM × 산출수량으로 자동. 직접 지정 시
--              [{"item_id":1,"qty":10.2,"lot_id":null}, ...]  (lot_id 없으면 선입선출 배분)
--   p_steps  : [{"step_name":"절단·소분","input_kg":10,"output_kg":8.8,"loss_kg":0.7,"scrap_kg":0.5,"loss_reason":"절단 자투리"}]
--              null 이면 kg 단위 원재료 투입량과 제품 순중량으로 1단계 자동 생성
-- ---------------------------------------------------------------------
create or replace function register_production(
  p_product_id  bigint,
  p_output_qty  numeric,
  p_work_date   date    default current_date,
  p_inputs      jsonb   default null,
  p_steps       jsonb   default null,
  p_defect_qty  numeric default 0,
  p_workers     int     default null,
  p_segments    jsonb   default null,
  p_issues      text    default null,
  p_suggestion  text    default null,
  p_note        text    default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_prod items%rowtype;
  v_log_id bigint; v_log_no text; v_lot_id bigint; v_lot_no text;
  v_warn text[] := '{}';
  r record; a record; s jsonb;
  v_need numeric; v_planned numeric; v_item_id bigint;
  v_min_dried date; v_min_expiry date; v_dried_cnt int;
  v_raw_kg numeric := 0; v_out_kg numeric;
  v_scrap_kg numeric := 0; v_scrap_item bigint; v_scrap_lot bigint;
  v_step_no int := 0;
  v_first boolean;
begin
  perform require_user();
  select * into v_prod from items where id = p_product_id and not is_void;
  if not found then raise exception '생산 제품을 찾을 수 없습니다.'; end if;
  if v_prod.item_type not in ('SEMI','FG') then raise exception '반제품·완제품만 생산 등록할 수 있습니다.'; end if;
  if p_output_qty is null or p_output_qty <= 0 then raise exception '산출 수량은 0보다 커야 합니다.'; end if;

  v_log_no := next_no('W', p_work_date);
  insert into production_logs (log_no, work_date, product_item_id, output_qty, defect_qty, workers,
                               segments, work_minutes, issues, suggestion, note)
  values (v_log_no, p_work_date, p_product_id, p_output_qty, coalesce(p_defect_qty, 0), p_workers,
          p_segments, work_minutes(p_segments), p_issues, p_suggestion, p_note)
  returning id into v_log_id;

  -- 1) 투입 목록 만들기
  create temp table if not exists _need (item_id bigint, planned numeric, qty numeric, lot_id bigint) on commit drop;
  truncate _need;

  if p_inputs is null or jsonb_array_length(p_inputs) = 0 then
    for r in
      select distinct on (coalesce(b.alt_group, b.id::text)) b.child_item_id, b.qty_per, b.loss_rate
        from bom b
       where b.parent_item_id = p_product_id and not b.is_void
       order by coalesce(b.alt_group, b.id::text), b.sort, b.id
    loop
      v_need := round(r.qty_per * p_output_qty * (1 + r.loss_rate / 100.0), 3);
      insert into _need values (r.child_item_id, v_need, v_need, null);
    end loop;
    if not found then
      v_warn := v_warn || '이 제품의 BOM(구성)이 없어 투입 차감을 하지 않았습니다.';
    end if;
    -- 단계 중량을 입력했고 kg 원재료가 1종이면, 실제 투입 kg(1단계)으로 차감
    if p_steps is not null and jsonb_array_length(p_steps) > 0
       and (p_steps -> 0 ->> 'input_kg') is not null
       and (select count(*) from _need n join items i on i.id = n.item_id where i.item_type = 'RAW' and i.unit = 'kg') = 1 then
      update _need n set qty = (p_steps -> 0 ->> 'input_kg')::numeric
        from items i where i.id = n.item_id and i.item_type = 'RAW' and i.unit = 'kg';
    end if;
  else
    for s in select * from jsonb_array_elements(p_inputs) loop
      v_item_id := (s ->> 'item_id')::bigint;
      select round(b.qty_per * p_output_qty * (1 + b.loss_rate / 100.0), 3) into v_planned
        from bom b where b.parent_item_id = p_product_id and b.child_item_id = v_item_id and not b.is_void;
      insert into _need values (v_item_id, v_planned, (s ->> 'qty')::numeric, nullif(s ->> 'lot_id', '')::bigint);
    end loop;
  end if;

  -- 2) 생산 로트 먼저 발급(투입 연결용)
  v_lot_no := next_no(case when v_prod.item_type = 'SEMI' then 'IP-' else 'FP-' end || v_prod.code, p_work_date);
  insert into lots (lot_no, item_id, source, made_on, production_log_id)
  values (v_lot_no, p_product_id, '생산', p_work_date, v_log_id)
  returning id into v_lot_id;

  -- 3) 투입 차감(로트 지정 또는 선입선출)
  for r in select * from _need where qty > 0 loop
    v_first := true;
    for a in
      select r.lot_id as lot_id, r.qty as qty where r.lot_id is not null
      union all
      select f.lot_id, f.qty from allocate_fefo(r.item_id, r.qty) f where r.lot_id is null
    loop
      insert into production_inputs (log_id, item_id, lot_id, planned_qty, actual_qty)
      values (v_log_id, r.item_id, a.lot_id, case when v_first then r.planned end, a.qty);
      v_first := false;
      insert into stock_moves (move_date, item_id, lot_id, qty, move_type, ref_type, ref_id)
      values (p_work_date, r.item_id, a.lot_id, -a.qty, '생산투입', 'production_logs', v_log_id);
      if a.lot_id is null then
        v_warn := v_warn || format('%s 재고 부족: %s %s 을(를) 로트 없이 차감했습니다.',
                   (select name from items where id = r.item_id), a.qty, (select unit from items where id = r.item_id));
      else
        insert into lot_links (parent_lot_id, child_lot_id, production_log_id, qty_used)
        values (a.lot_id, v_lot_id, v_log_id, a.qty);
        if lot_balance(a.lot_id) < 0 then
          v_warn := v_warn || format('로트 %s 재고가 음수가 되었습니다.', (select lot_no from lots where id = a.lot_id));
        end if;
      end if;
      if (select item_type = 'RAW' and unit = 'kg' from items where id = r.item_id) then
        v_raw_kg := v_raw_kg + a.qty;
      end if;
    end loop;
  end loop;

  -- 4) 생산 로트 건조일·소비기한 상속(가장 이른 값)
  select min(l.dried_date), min(l.expiry_date), count(distinct l.dried_date)
    into v_min_dried, v_min_expiry, v_dried_cnt
    from lot_links k join lots l on l.id = k.parent_lot_id
   where k.child_lot_id = v_lot_id;
  update lots set dried_date = v_min_dried,
                  expiry_date = case when v_prod.shelf_life_months is null then v_min_expiry end,
                  mixed_dried_dates = coalesce(v_dried_cnt, 0) > 1
   where id = v_lot_id;
  if coalesce(v_dried_cnt, 0) > 1 then
    v_warn := v_warn || '건조일이 다른 원재료 로트가 섞였습니다. 가장 이른 건조일로 소비기한을 계산했습니다.';
  end if;

  update production_logs set output_lot_id = v_lot_id where id = v_log_id;

  -- 5) 산출 재고 증가
  insert into stock_moves (move_date, item_id, lot_id, qty, move_type, ref_type, ref_id)
  values (p_work_date, p_product_id, v_lot_id, p_output_qty, '생산산출', 'production_logs', v_log_id);

  -- 6) 단계별 중량(수율)
  if p_steps is not null and jsonb_array_length(p_steps) > 0 then
    for s in select * from jsonb_array_elements(p_steps) loop
      v_step_no := v_step_no + 1;
      insert into production_steps (log_id, step_no, step_name, input_kg, output_kg, loss_kg, scrap_kg, loss_reason, note)
      values (v_log_id, v_step_no, coalesce(s ->> 'step_name', '내포장'),
              (s ->> 'input_kg')::numeric, (s ->> 'output_kg')::numeric,
              coalesce((s ->> 'loss_kg')::numeric, 0), coalesce((s ->> 'scrap_kg')::numeric, 0),
              nullif(s ->> 'loss_reason', ''), s ->> 'note');
      v_scrap_kg := v_scrap_kg + coalesce((s ->> 'scrap_kg')::numeric, 0);
    end loop;
  elsif v_raw_kg > 0 and v_prod.net_weight_g is not null then
    v_out_kg := round(p_output_qty * v_prod.net_weight_g / 1000.0, 3);
    insert into production_steps (log_id, step_no, step_name, input_kg, output_kg, note)
    values (v_log_id, 1, '내포장', v_raw_kg, v_out_kg, '투입량·순중량으로 자동 계산');
  end if;

  if exists (select 1 from production_steps where log_id = v_log_id and input_kg > 0
               and abs(balance_kg) > greatest(0.05, input_kg * 0.02)) then
    v_warn := v_warn || '투입 − 산출 − 손실 − 자투리 차이가 2%를 넘습니다. 중량을 확인하세요.';
  end if;

  -- 7) 재사용 자투리 → RM-SCRAP 재고(건조일 상속)
  if v_scrap_kg > 0 then
    select id into v_scrap_item from items where code = 'RM-SCRAP' and not is_void;
    if v_scrap_item is null then
      v_warn := v_warn || '자투리 품목(RM-SCRAP)이 없어 자투리 재고를 올리지 못했습니다.';
    else
      insert into lots (lot_no, item_id, source, dried_date, made_on, production_log_id, note)
      values (next_no('SC', p_work_date), v_scrap_item, '생산', v_min_dried, p_work_date, v_log_id, v_log_no || ' 자투리')
      returning id into v_scrap_lot;
      insert into lot_links (parent_lot_id, child_lot_id, production_log_id, qty_used)
      select k.parent_lot_id, v_scrap_lot, v_log_id, 0 from lot_links k where k.child_lot_id = v_lot_id;
      insert into stock_moves (move_date, item_id, lot_id, qty, move_type, ref_type, ref_id, reason)
      values (p_work_date, v_scrap_item, v_scrap_lot, v_scrap_kg, '생산산출', 'production_logs', v_log_id, '재사용 자투리');
    end if;
  end if;

  return jsonb_build_object('log_id', v_log_id, 'log_no', v_log_no, 'lot_id', v_lot_id, 'lot_no', v_lot_no,
                            'inputs', (select coalesce(jsonb_agg(jsonb_build_object(
                                          'item', i.name, 'qty', pi.actual_qty, 'unit', i.unit,
                                          'lot_no', l.lot_no) order by pi.id), '[]')
                                         from production_inputs pi join items i on i.id = pi.item_id
                                         left join lots l on l.id = pi.lot_id where pi.log_id = v_log_id),
                            'yield_pct', (select round(sum(output_kg) / nullif(sum(input_kg), 0) * 100, 2)
                                            from production_steps where log_id = v_log_id),
                            'warnings', to_jsonb(v_warn));
end $$;

-- ---------------------------------------------------------------------
-- 출고·조정·폐기·기초재고
--   p_qty 는 양수로 입력. 출고·폐기는 감소, 기초는 증가, 조정은 p_increase 로 방향 지정
-- ---------------------------------------------------------------------
create or replace function register_move(
  p_item_id    bigint,
  p_qty        numeric,
  p_move_type  text,                       -- 출고 / 조정 / 폐기 / 기초
  p_move_date  date    default current_date,
  p_lot_id     bigint  default null,       -- 비우면 선입선출(감소) 또는 새 로트(기초)
  p_partner_id bigint  default null,
  p_reason     text    default null,
  p_increase   boolean default false,      -- 조정 시 증가 여부
  p_unit       text    default null,
  p_dried_date date    default null        -- 기초재고 로트 건조일
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_role text := require_user();
  v_base numeric; v_sign int; v_lot bigint; a record; v_warn text[] := '{}'; v_moves int := 0;
begin
  if p_move_type not in ('출고','조정','폐기','기초') then raise exception '구분은 출고·조정·폐기·기초 중 하나입니다.'; end if;
  if p_move_type in ('조정','기초') and v_role <> 'owner' then raise exception '재고 조정·기초재고는 대표만 등록할 수 있습니다.'; end if;
  if p_move_type in ('조정','폐기') and coalesce(btrim(p_reason), '') = '' then raise exception '사유를 입력하세요.'; end if;
  if p_qty is null or p_qty <= 0 then raise exception '수량은 0보다 커야 합니다.'; end if;

  v_base := to_base_qty(p_item_id, p_qty, p_unit);
  v_sign := case when p_move_type = '기초' or (p_move_type = '조정' and p_increase) then 1 else -1 end;

  if v_sign > 0 then
    v_lot := p_lot_id;
    if v_lot is null then
      insert into lots (lot_no, item_id, source, dried_date, made_on, note)
      values (next_no('OP', p_move_date), p_item_id, case when p_move_type = '기초' then '기초' else '조정' end,
              p_dried_date, p_move_date, p_reason)
      returning id into v_lot;
    end if;
    insert into stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, reason)
    values (p_move_date, p_item_id, v_lot, v_base, p_move_type, p_partner_id, p_reason);
    v_moves := 1;
  else
    for a in
      select p_lot_id as lot_id, v_base as qty where p_lot_id is not null
      union all
      select f.lot_id, f.qty from allocate_fefo(p_item_id, v_base) f where p_lot_id is null
    loop
      insert into stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, reason)
      values (p_move_date, p_item_id, a.lot_id, -a.qty, p_move_type, p_partner_id, p_reason);
      v_moves := v_moves + 1;
      if a.lot_id is null then v_warn := v_warn || format('재고 부족: %s 을(를) 로트 없이 차감했습니다.', a.qty); end if;
    end loop;
  end if;
  return jsonb_build_object('moves', v_moves, 'base_qty', v_base * v_sign, 'warnings', to_jsonb(v_warn));
end $$;

-- ---------------------------------------------------------------------
-- 취소 (직원은 당일 본인 기록만, 대표는 모두)
-- ---------------------------------------------------------------------
create or replace function can_void(p_created_by uuid, p_created_at timestamptz) returns boolean
language sql stable security definer set search_path = public as $$
  select app_role() = 'owner'
      or (p_created_by = auth.uid() and (p_created_at at time zone 'Asia/Seoul')::date = (now() at time zone 'Asia/Seoul')::date)
$$;

create or replace function reverse_moves(p_ref_type text, p_ref_id bigint, p_reason text) returns int
language plpgsql security definer set search_path = public as $$
declare v_cnt int;
begin
  insert into stock_moves (move_date, item_id, lot_id, qty, move_type, partner_id, ref_type, ref_id, reverses_id, reason)
  select current_date, m.item_id, m.lot_id, -m.qty, '취소', m.partner_id, m.ref_type, m.ref_id, m.id, p_reason
    from stock_moves m
   where m.ref_type = p_ref_type and m.ref_id = p_ref_id and m.move_type <> '취소'
     and not exists (select 1 from stock_moves x where x.reverses_id = m.id);
  get diagnostics v_cnt = row_count;
  return v_cnt;
end $$;

create or replace function void_receipt(p_receipt_id bigint, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v receipts%rowtype;
begin
  perform require_user();
  select * into v from receipts where id = p_receipt_id for update;
  if not found or v.is_void then raise exception '취소할 입고가 없거나 이미 취소되었습니다.'; end if;
  if not can_void(v.created_by, v.created_at) then raise exception '직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception '취소 사유를 입력하세요.'; end if;
  if lot_balance(v.lot_id) < v.base_qty then
    raise exception '이 입고 로트는 이미 생산·출고에 사용되었습니다. 사용 기록을 먼저 취소하세요.';
  end if;
  perform reverse_moves('receipts', v.id, p_reason);
  update receipts set is_void = true, void_reason = p_reason where id = v.id;
  update lots set is_void = true, void_reason = p_reason
   where id = v.lot_id and lot_balance(id) = 0
     and not exists (select 1 from receipts r where r.lot_id = v.lot_id and not r.is_void);
  return jsonb_build_object('receipt_no', v.receipt_no, 'voided', true);
end $$;

create or replace function void_production(p_log_id bigint, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v production_logs%rowtype;
begin
  perform require_user();
  select * into v from production_logs where id = p_log_id for update;
  if not found or v.is_void then raise exception '취소할 생산일지가 없거나 이미 취소되었습니다.'; end if;
  if not can_void(v.created_by, v.created_at) then raise exception '직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception '취소 사유를 입력하세요.'; end if;
  if exists (select 1 from lots l where l.production_log_id = v.id and lot_balance(l.id) <
               (select coalesce(sum(m.qty), 0) from stock_moves m
                 where m.lot_id = l.id and m.ref_type = 'production_logs' and m.ref_id = v.id and m.qty > 0)) then
    raise exception '이 생산 로트는 이미 다음 공정·출고에 사용되었습니다. 사용 기록을 먼저 취소하세요.';
  end if;
  perform reverse_moves('production_logs', v.id, p_reason);
  update production_logs  set is_void = true, void_reason = p_reason where id = v.id;
  update production_inputs set is_void = true, void_reason = p_reason where log_id = v.id;
  update production_steps set is_void = true, void_reason = p_reason where log_id = v.id;
  update lot_links        set is_void = true, void_reason = p_reason where production_log_id = v.id;
  update lots             set is_void = true, void_reason = p_reason where production_log_id = v.id;
  return jsonb_build_object('log_no', v.log_no, 'voided', true);
end $$;
