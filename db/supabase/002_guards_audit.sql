-- =====================================================================
-- 삭제 금지 · 원장 수정 금지 · 수정 이력 · 소비기한 자동계산
-- =====================================================================

-- 삭제 차단 (모든 테이블)
create or replace function trg_block_delete() returns trigger
language plpgsql as $$
begin
  raise exception '[%] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.', tg_table_name
    using errcode = 'P0001';
end $$;

-- 원장(stock_moves, audit_log, lot_links 연결값) 수정 차단
create or replace function trg_block_update() returns trigger
language plpgsql as $$
begin
  raise exception '[%] 기록은 수정할 수 없습니다. 반대 기록을 추가해 바로잡으세요.', tg_table_name
    using errcode = 'P0001';
end $$;

-- 수정 시각·수정자, 취소 규칙
create or replace function trg_touch() returns trigger
language plpgsql as $$
begin
  new.created_at := old.created_at;          -- 작성 정보는 바꿀 수 없음
  new.created_by := old.created_by;
  new.updated_at := now();
  new.updated_by := auth.uid();
  if old.is_void and not new.is_void then
    raise exception '취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.' using errcode = 'P0001';
  end if;
  if new.is_void and not old.is_void then
    if coalesce(btrim(new.void_reason), '') = '' then
      raise exception '취소 사유(void_reason)를 입력하세요.' using errcode = 'P0001';
    end if;
    new.voided_at := now();
    new.voided_by := auth.uid();
  end if;
  return new;
end $$;

-- 수정 이력 기록
create or replace function trg_audit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
  v_new jsonb := to_jsonb(new);
  v_cols text[];
  v_action text := tg_op;
begin
  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into v_cols
      from jsonb_object_keys(v_new) k
     where v_new -> k is distinct from v_old -> k
       and k not in ('updated_at','updated_by');
    if v_cols is null then return new; end if;              -- 실제 변경 없음
    if (v_new ->> 'is_void')::boolean and not coalesce((v_old ->> 'is_void')::boolean, false) then
      v_action := 'VOID';
    end if;
  end if;
  insert into audit_log (table_name, row_id, action, changed_by, old_data, new_data, changed_cols)
  values (tg_table_name, coalesce(v_new ->> 'id', v_new ->> 'lot_no'), v_action, auth.uid(), v_old, v_new, v_cols);
  return new;
end $$;

-- 로트 소비기한: 비어 있으면 건조일 + 품목 소비기한개월
create or replace function trg_lot_expiry() returns trigger
language plpgsql as $$
declare v_months int;
begin
  if new.expiry_date is null and new.dried_date is not null then
    select shelf_life_months into v_months from items where id = new.item_id;
    if v_months is not null then
      new.expiry_date := (new.dried_date + make_interval(months => v_months))::date;
    end if;
  end if;
  return new;
end $$;

-- 트리거 연결
do $$
declare t text;
begin
  -- 공통 컬럼이 있는 테이블: 수정시각 + 이력 + 삭제금지
  foreach t in array array['partners','partner_aliases','items','item_aliases','item_units','item_suppliers',
                           'bom','production_standards','lots','receipts','production_logs',
                           'production_steps','production_inputs','lot_links']
  loop
    execute format('create trigger %1$s_touch before update on %1$I for each row execute function trg_touch()', t);
    execute format('create trigger %1$s_audit after insert or update on %1$I for each row execute function trg_audit()', t);
    execute format('create trigger %1$s_nodelete before delete on %1$I for each row execute function trg_block_delete()', t);
  end loop;

  -- 원장: 추가만
  foreach t in array array['stock_moves','audit_log']
  loop
    execute format('create trigger %1$s_noupdate before update on %1$I for each row execute function trg_block_update()', t);
    execute format('create trigger %1$s_nodelete before delete on %1$I for each row execute function trg_block_delete()', t);
  end loop;
  execute 'create trigger stock_moves_audit after insert on stock_moves for each row execute function trg_audit()';

  -- TRUNCATE 도 차단
  foreach t in array array['partners','items','bom','lots','receipts','production_logs','stock_moves','audit_log']
  loop
    execute format('create trigger %1$s_notruncate before truncate on %1$I for each statement execute function trg_block_delete()', t);
  end loop;
end $$;

create trigger lots_expiry before insert or update of dried_date, expiry_date on lots
  for each row execute function trg_lot_expiry();

-- 거래(입고·생산) 핵심 값은 등록 후 직접 수정 금지 → 취소 후 재등록
create or replace function trg_lock_txn() returns trigger
language plpgsql as $$
declare
  v_skip text[] := array['updated_at','updated_by','is_void','void_reason','voided_at','voided_by'];
begin
  if tg_table_name = 'receipts' then
    if (to_jsonb(new) - v_skip - 'note' - 'unit_price' - 'partner_id' - 'bulk_count')
       is distinct from (to_jsonb(old) - v_skip - 'note' - 'unit_price' - 'partner_id' - 'bulk_count') then
      raise exception '입고 수량·품목·로트·입고일은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.' using errcode = 'P0001';
    end if;
  elsif tg_table_name = 'production_logs' then
    if old.output_lot_id is null then
      old.output_lot_id := new.output_lot_id;       -- 최초 로트 연결은 허용
    end if;
    if (to_jsonb(new) - v_skip - 'note' - 'issues' - 'suggestion' - 'workers' - 'segments' - 'work_minutes')
       is distinct from (to_jsonb(old) - v_skip - 'note' - 'issues' - 'suggestion' - 'workers' - 'segments' - 'work_minutes') then
      raise exception '생산 제품·수량·로트·작업일은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.' using errcode = 'P0001';
    end if;
  else  -- production_inputs, lot_links
    if (to_jsonb(new) - v_skip) is distinct from (to_jsonb(old) - v_skip) then
      raise exception '[%] 투입·로트연결 값은 직접 수정할 수 없습니다.', tg_table_name using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;

create trigger receipts_lock before update on receipts for each row execute function trg_lock_txn();
create trigger production_logs_lock before update on production_logs for each row execute function trg_lock_txn();
create trigger production_inputs_lock before update on production_inputs for each row execute function trg_lock_txn();
create trigger lot_links_lock before update on lot_links for each row execute function trg_lock_txn();
