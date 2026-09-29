-- 판매·기타주문·개인정보·OEM 검증 (supabase_flow_test.sql 다음에 실행)
\set ON_ERROR_STOP 1
\pset footer off
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';   -- 대표

insert into partners (code, name, is_customer, category) values
  ('C-0001','주식회사 아난티',true,'B2B'), ('C-0002','중앙선거관리위원회',true,'B2G'),
  ('C-0003','전화 및 기타 주문',true,'기타'), ('C-0004','주식회사 와이즐리컴퍼니',true,'OEM');
insert into items (code, name, item_type, unit, oem_type, oem_partner_id)
select 'OEM-WZ-01','와이즐리 자른미역 200g','FG','ea','OEM납품', id from partners where code = 'C-0004';
update items set oem_type = 'OEM매입' where code = 'PK-B-22';  -- 테스트용 표시

-- 기업 주문: 박스 3개 출고
select register_sale('{"channel_type":"기업","order_date":"2026-09-28","ship_date":"2026-09-28","destination":"아난티코브 모비딕마켓","writer":"정지영"}'::jsonb
         || jsonb_build_object('channel_partner_id', (select id from partners where code='C-0001')),
       jsonb_build_array(jsonb_build_object('item_id', (select id from items where code='SP-03'), 'item_text','기장미역150g 박스',
                                            'qty',3,'unit','EA','unit_price',10000,'supply_amount',30000,'vat',0,'tax_type','면세','total',30000))) ->> 'order_no' as b2b;

-- 개인(기관) 주문: 받는 사람 개인정보
select register_sale(jsonb_build_object('channel_type','개인','channel_partner_id',(select id from partners where code='C-0002'),
                                        'order_date','2026-09-28','ship_date','2026-09-29','delivery_method','택배'),
       jsonb_build_array(jsonb_build_object('item_id',(select id from items where code='SP-03'),'qty',1,'unit_price',34000,'total',34000)),
       '{"recipient_name":"중앙선관위 사무총장 허철훈","recipient_org":"중앙선관위","phone":"010-1234-5678","address":"경기도 과천시 홍촌말로 44"}'::jsonb) -> 'warnings' as b2g_warn;

-- 기타주문: 품목 미확정 줄 포함
select register_sale(jsonb_build_object('channel_type','기타주문','channel_partner_id',(select id from partners where code='C-0003'),
                                        'order_date','2026-09-29','ship_date','2026-09-29'),
       '[{"item_text":"한끼용 기장미역20G","qty":30},{"item_text":"부산바다선물세트","qty":1}]'::jsonb,
       '{"recipient_name":"여가거가"}'::jsonb) -> 'warnings' as etc_warn;

\echo '--- 대표가 보는 주문 목록'
select order_no, channel_type, channel_name, recipient_name, phone, address, line_count, amount_total, unmapped_lines from v_sales_list order by order_no;

set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';   -- 직원
\echo '--- 직원이 보는 주문 목록 (이름·전화·주소 가림)'
select order_no, channel_type, recipient_name, phone, address from v_sales_list order by order_no;
do $$ begin
  raise notice '직원 sales_recipients 직접 조회 행수: % (0이어야 함)', (select count(*) from sales_recipients);
  begin insert into sales_orders (order_no, channel_type) values ('X','기업'); raise exception 'FAIL';
  exception when insufficient_privilege then raise notice 'OK 직원 주문 직접 입력 차단'; end;
end $$;

-- 미확정 줄 → 품목 확정 후 출고
select ship_sales_line((select id from sales_lines where item_text = '한끼용 기장미역20G'), (select id from items where code='FG-01' union all select id from items where code='SP-02' limit 1)) -> 'warnings' as ship_later;

\echo '--- 월별 판매 집계'
select month, channel_type, channel_name, orders, qty, amount, lines_without_amount from v_sales_monthly order by channel_type;
\echo '--- OEM 품목'
select code, name, oem_type, oem_partner from v_oem_items order by code;

set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
\echo '--- 기업 주문 취소 → 박스 재고 원복'
select stock_qty as sp03_before from v_item_stock where code = 'SP-03';
select void_sale((select id from sales_orders where channel_type = '기업'), '테스트 취소') as voided;
select stock_qty as sp03_after from v_item_stock where code = 'SP-03';
\echo '--- 이름 가리기'
select mask_name('중앙선관위 사무총장 허철훈') a, mask_name('여가거가') b, mask_name('김') c, mask_phone('010-1234-5678') d;
reset role;
