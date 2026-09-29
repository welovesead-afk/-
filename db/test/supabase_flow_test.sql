-- 로컬 검증 시나리오 (Supabase SQL). 실행: db/test/run_supabase_test.sh
\set ON_ERROR_STOP 1
\pset footer off

-- 사용자 준비(관리자 권한)
insert into auth.users values ('00000000-0000-0000-0000-000000000001','owner@test'),
                              ('00000000-0000-0000-0000-000000000002','staff@test');
insert into profiles (id, name, role) values
  ('00000000-0000-0000-0000-000000000001','대표','owner'),
  ('00000000-0000-0000-0000-000000000002','직원A','staff');

-- ===== 대표로 로그인 =====
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

insert into partners (code, name, biz_no, is_supplier, category) values
  ('P-0001','기장해초생상자영업인','160-86-01232',true,'원물생산자'),
  ('P-0002','금호산업 주식회사','615-81-90282',true,'포장재');

insert into items (code, name, item_type, unit, spec, shelf_life_months, origin, safety_stock) values
  ('RM-01','자연건조미역(기장산)','RAW','kg',null,36,'부산 기장군',20),
  ('RM-SCRAP','미역 자투리(20cm 이하)','RAW','kg',null,36,'부산 기장군',0);
insert into items (code, name, item_type, pack_kind, unit, spec, size, safety_stock) values
  ('PK-W-01','150g 무지포장지','PACK','포장지','ea',null,'24*34',500),
  ('PK-B-22','기장미역 150g IN box','PACK','박스','ea',null,null,100);
insert into items (code, name, item_type, unit, spec, net_weight_g, shelf_life_months, safety_stock) values
  ('SP-02','기장미역150g (무지)','SEMI','ea','150g',150,36,50),
  ('SP-03','기장미역150g(박스)','SEMI','ea','150g',150,36,30);

insert into item_units (item_id, unit, factor)
select id, '묶음', 10 from items where code = 'RM-01';

insert into bom (parent_item_id, child_item_id, qty_per, step, sort)
select p.id, c.id, v.q, v.step, v.s
  from (values ('SP-02','RM-01',0.150,'내포장',1), ('SP-02','PK-W-01',1,'내포장',2),
               ('SP-03','SP-02',1,'외포장',1),     ('SP-03','PK-B-22',1,'외포장',2)) v(p,c,q,step,s)
  join items p on p.code = v.p join items c on c.code = v.c;

insert into production_standards (item_id, step, std_yield_pct, std_sec_per_ea, bulk_unit_kg, sample_count, source)
select id, '내포장', 97.5, 208, 10, 1, '생산동향 기록표 2026-07-21' from items where code = 'SP-02';

-- 기초재고(대표)
select register_move((select id from items where code='PK-W-01'), 1000, '기초', date '2026-09-01', null, null, '기초재고') ->> 'moves' as opening_pack;
select register_move((select id from items where code='PK-B-22'), 40, '기초', date '2026-09-01', null, null, '기초재고') ->> 'moves' as opening_box;

-- ===== 직원으로 로그인 =====
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';

-- 입고 2건: 건조일 다른 원물 (묶음 단위 입력 → kg 환산)
select register_receipt((select id from items where code='RM-01'), 1, date '2026-09-10', '묶음', null,
                        (select id from partners where code='P-0001'), date '2026-04-20') as receipt1;
select register_receipt((select id from items where code='RM-01'), 5, date '2026-09-20', 'kg', null,
                        (select id from partners where code='P-0001'), date '2026-05-02') as receipt2;

-- 생산: 150g 무지 65개, 단계 중량 입력(자투리 0.3kg 포함) → 선입선출로 건조일 빠른 로트부터 차감
select jsonb_pretty(register_production((select id from items where code='SP-02'), 65, date '2026-09-25', null,
  '[{"step_name":"절단·소분","input_kg":10,"output_kg":9.75,"loss_kg":0.05,"scrap_kg":0.2,"loss_reason":"절단 자투리"}]'::jsonb,
  0, 1, '[{"start":"08:30","end":"12:10"}]'::jsonb)) as production1;

-- 생산: 박스 30개 (BOM 자동, 수율 단계 입력 없음)
select register_production((select id from items where code='SP-03'), 30, date '2026-09-26') -> 'warnings' as production2_warnings;

-- 출고 5개
select register_move((select id from items where code='SP-03'), 5, '출고', date '2026-09-27') ->> 'moves' as shipped;

\echo '--- 품목별 현재고'
select code, name, stock_qty, safety_stock, below_safety from v_item_stock order by code;
\echo '--- 로트별 재고'
select lot_no, code, stock_qty, dried_date, expiry_date, mixed_dried_dates from v_lot_stock order by lot_no;
\echo '--- 안전재고 미달'
select code, stock_qty, safety_stock, shortage_qty from v_safety_shortage;
\echo '--- 이번 달 수율'
select month, code, runs, input_kg, output_kg, yield_pct, std_yield_pct, yield_gap_pct, work_minutes from v_monthly_yield order by code;
\echo '--- 로트 추적(박스 생산로트 → 원물까지)'
select direction, depth, lot_no, item_code, dried_date, expiry_date, qty, event, event_date
  from lot_trace((select lot_no from lots where item_id = (select id from items where code='SP-03') limit 1));

-- ===== 금지 동작 확인 =====
\echo '--- 금지 동작 (모두 차단되어야 함)'
do $$ begin
  begin delete from items where code = 'RM-01'; raise exception 'FAIL: 삭제됨';
  exception when insufficient_privilege or raise_exception then raise notice 'OK 품목 삭제 차단: %', sqlerrm; end;
  begin insert into items (code,name,item_type,unit) values ('X','x','RAW','kg'); raise exception 'FAIL: 직원 품목추가';
  exception when insufficient_privilege then raise notice 'OK 직원 품목 추가 차단';
            when others then if sqlerrm like 'FAIL%' then raise; end if; raise notice 'OK 직원 품목 추가 차단: %', sqlerrm; end;
  begin insert into stock_moves (item_id, qty, move_type) values (1, 100, '입고'); raise exception 'FAIL: 원장 직접입력';
  exception when insufficient_privilege then raise notice 'OK 재고원장 직접 입력 차단'; end;
  begin update receipts set qty = 999; raise exception 'FAIL: 입고 수정';
  exception when insufficient_privilege then raise notice 'OK 입고 직접 수정 차단'; end;
  begin perform register_move(1, 1, '조정', current_date, null, null, '테스트'); raise exception 'FAIL: 직원 조정';
  exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; raise notice 'OK 직원 재고조정 차단: %', sqlerrm; end;
  begin perform count(*) from audit_log; raise notice 'audit_log 직원 조회 행수: %', (select count(*) from audit_log);
  end;
end $$;

-- 원물 입고 취소 시도: 이미 생산에 사용 → 차단
do $$ begin
  perform void_receipt((select id from receipts order by id limit 1), '수량 오기');
  raise exception 'FAIL: 사용된 로트 입고 취소됨';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'OK 사용된 입고 취소 차단: %', sqlerrm;
end $$;

-- ===== 대표: 출고분 때문에 박스 생산 취소 불가 확인 → 원래 흐름대로 취소는 역순
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  perform void_production((select id from production_logs where log_no like 'W-260926-%'), '테스트');
  raise exception 'FAIL';
exception when raise_exception then
  if sqlerrm = 'FAIL' then raise; end if;
  raise notice 'OK 출고된 생산로트 취소 차단: %', sqlerrm;
end $$;

-- 새 입고 → 바로 취소 (사용 전)
select register_receipt((select id from items where code='RM-01'), 2, date '2026-09-28', 'kg', null, null, date '2026-05-10') ->> 'receipt_no' as receipt3;
select void_receipt((select id from receipts order by id desc limit 1), '중복 입력') as void3;

\echo '--- 취소 후 RM-01 재고'
select stock_qty from v_item_stock where code = 'RM-01';
\echo '--- 수정 이력(대표 조회)'
select table_name, action, count(*) from audit_log group by 1, 2 order by 1, 2;
select table_name, row_id, action, changed_cols from audit_log where action in ('UPDATE','VOID') order by id limit 8;

\echo '--- 재고 부족 생산(경고) → 대표 취소 → 재고 원복'
select register_production((select id from items where code='SP-02'), 40, date '2026-09-28', null,
  '[{"step_name":"절단·소분","input_kg":6.2,"output_kg":6.0,"loss_kg":0.2}]'::jsonb) -> 'warnings' as short_warnings;
select stock_qty as rm01_after_short from v_item_stock where code = 'RM-01';
select void_production((select id from production_logs where log_no like 'W-260928-%'), '재고 부족 테스트 취소') as void_prod;
select code, stock_qty from v_item_stock where code in ('RM-01','SP-02','PK-W-01') order by code;

reset role;
\echo '--- 관리자 권한으로도 삭제 불가'
do $$ begin
  delete from stock_moves; raise exception 'FAIL';
exception when raise_exception then if sqlerrm = 'FAIL' then raise; end if; raise notice 'OK 관리자 원장 삭제 차단: %', sqlerrm; end $$;
