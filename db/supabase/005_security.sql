-- =====================================================================
-- 권한(RLS)
--  * 로그인한 활성 사용자만 조회
--  * 기준정보(품목·BOM·거래처 등) 추가·수정: 대표(owner)
--  * 입고·생산·재고이동: 화면에서 직접 쓰기 불가 → 업무 처리 함수(003)로만
--  * 수정 이력: 대표만 조회
--  * 삭제: 누구도 불가(트리거 + 권한 회수)
-- =====================================================================

create or replace function is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active)
$$;
create or replace function is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(app_role() = 'owner', false)
$$;

do $$
declare t text;
begin
  foreach t in array array['profiles','partners','partner_aliases','items','item_aliases','item_units','item_suppliers',
                           'bom','production_standards','lots','receipts','production_logs','production_steps',
                           'production_inputs','lot_links','stock_moves','audit_log','doc_counters']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('revoke delete, truncate on %I from anon, authenticated', t);
    execute format('revoke all on %I from anon', t);
  end loop;

  -- 조회: 활성 사용자
  foreach t in array array['partners','partner_aliases','items','item_aliases','item_units','item_suppliers',
                           'bom','production_standards','lots','receipts','production_logs','production_steps',
                           'production_inputs','lot_links','stock_moves']
  loop
    execute format('create policy %1$s_read on %1$I for select to authenticated using (is_active_user())', t);
  end loop;

  -- 기준정보 쓰기: 대표
  foreach t in array array['partners','partner_aliases','items','item_aliases','item_units','item_suppliers',
                           'bom','production_standards']
  loop
    execute format('create policy %1$s_owner_ins on %1$I for insert to authenticated with check (is_owner())', t);
    execute format('create policy %1$s_owner_upd on %1$I for update to authenticated using (is_owner()) with check (is_owner())', t);
  end loop;
end $$;

-- 거래 테이블은 직접 쓰기 권한 없음(함수만 사용)
revoke insert, update on lots, receipts, production_logs, production_steps, production_inputs,
       lot_links, stock_moves, audit_log, doc_counters from authenticated;

-- 사용자 목록
create policy profiles_self_read on profiles for select to authenticated
  using (id = auth.uid() or is_owner());
create policy profiles_owner_write on profiles for update to authenticated
  using (is_owner()) with check (is_owner());
create policy profiles_owner_insert on profiles for insert to authenticated with check (is_owner());

-- 수정 이력: 대표만
create policy audit_owner_read on audit_log for select to authenticated using (is_owner());

-- 함수 실행 권한: 로그인 사용자만
revoke execute on all functions in schema public from public, anon;
grant execute on function register_receipt(bigint, numeric, date, text, text, bigint, date, date, numeric, numeric, text) to authenticated;
grant execute on function register_production(bigint, numeric, date, jsonb, jsonb, numeric, int, jsonb, text, text, text) to authenticated;
grant execute on function register_move(bigint, numeric, text, date, bigint, bigint, text, boolean, text, date) to authenticated;
grant execute on function void_receipt(bigint, text) to authenticated;
grant execute on function void_production(bigint, text) to authenticated;
grant execute on function lot_trace(text) to authenticated;
grant execute on function lot_balance(bigint) to authenticated;
grant execute on function app_role() to authenticated;
grant execute on function is_active_user() to authenticated;
grant execute on function is_owner() to authenticated;
grant execute on function work_minutes(jsonb) to authenticated;

grant select on v_item_stock, v_lot_stock, v_safety_shortage, v_monthly_yield,
                v_production_list, v_receipt_list to authenticated;

-- 내부 도우미는 화면에서 직접 호출 불가
revoke execute on function next_no(text, date), reverse_moves(text, bigint, text),
       allocate_fefo(bigint, numeric), to_base_qty(bigint, numeric, text),
       require_user(), can_void(uuid, timestamptz) from authenticated;
