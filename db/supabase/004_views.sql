-- =====================================================================
-- 조회용 뷰 (대표 화면·재고 조회)
-- security_invoker: 조회하는 사람의 권한(RLS)으로 동작
-- =====================================================================

-- 품목별 현재고
create or replace view v_item_stock with (security_invoker = true) as
select i.id as item_id, i.code, i.name, i.item_type, i.pack_kind, i.is_set, i.unit, i.spec,
       i.safety_stock,
       coalesce(sum(m.qty), 0)                                   as stock_qty,
       coalesce(sum(m.qty), 0) < i.safety_stock                  as below_safety,
       greatest(i.safety_stock - coalesce(sum(m.qty), 0), 0)     as shortage_qty,
       max(m.moved_at)                                           as last_moved_at
  from items i
  left join stock_moves m on m.item_id = i.id
 where not i.is_void
 group by i.id;

-- 로트별 현재고 (0 초과만) + 잔여 소비기한
create or replace view v_lot_stock with (security_invoker = true) as
select l.id as lot_id, l.lot_no, l.item_id, i.code, i.name, i.unit, l.source,
       l.dried_date, l.expiry_date, l.made_on, l.mixed_dried_dates,
       b.qty as stock_qty,
       case when l.expiry_date is not null then (l.expiry_date - current_date) end as days_to_expiry
  from lots l
  join items i on i.id = l.item_id
  join lateral (select coalesce(sum(m.qty), 0) qty from stock_moves m where m.lot_id = l.id) b on true
 where not l.is_void and b.qty <> 0;

-- 안전재고 미달 목록
create or replace view v_safety_shortage with (security_invoker = true) as
select * from v_item_stock
 where safety_stock > 0 and below_safety
 order by shortage_qty desc;

-- 월별 제품별 수율 (중량 가중 평균 = 산출kg 합 / 투입kg 합)
create or replace view v_monthly_yield with (security_invoker = true) as
select date_trunc('month', p.work_date)::date                        as month,
       p.product_item_id                                             as item_id,
       i.code, i.name,
       count(distinct p.id)                                          as runs,
       sum(p.output_qty)                                             as output_qty,
       sum(p.defect_qty)                                             as defect_qty,
       sum(s.input_kg)                                               as input_kg,
       sum(s.output_kg)                                              as output_kg,
       sum(s.loss_kg)                                                as loss_kg,
       sum(s.scrap_kg)                                               as scrap_kg,
       round(sum(s.output_kg) / nullif(sum(s.input_kg), 0) * 100, 2) as yield_pct,
       max(ps.std_yield_pct)                                         as std_yield_pct,
       round(sum(s.output_kg) / nullif(sum(s.input_kg), 0) * 100, 2) - max(ps.std_yield_pct) as yield_gap_pct,
       sum(p.work_minutes)                                           as work_minutes
  from production_logs p
  join items i on i.id = p.product_item_id
  left join production_steps s on s.log_id = p.id and not s.is_void
  left join production_standards ps on ps.item_id = p.product_item_id and ps.step = '내포장' and not ps.is_void
 where not p.is_void
 group by 1, 2, 3, 4;

-- 생산일지 목록(화면용)
create or replace view v_production_list with (security_invoker = true) as
select p.id, p.log_no, p.work_date, p.product_item_id, i.code, i.name, i.unit,
       p.output_qty, p.defect_qty, l.lot_no, l.dried_date, l.expiry_date,
       (select round(sum(output_kg) / nullif(sum(input_kg), 0) * 100, 2)
          from production_steps s where s.log_id = p.id and not s.is_void) as yield_pct,
       p.work_minutes, p.workers, p.is_void, p.void_reason, p.created_at, pr.name as created_by_name
  from production_logs p
  join items i on i.id = p.product_item_id
  left join lots l on l.id = p.output_lot_id
  left join profiles pr on pr.id = p.created_by;

-- 입고 목록(화면용)
create or replace view v_receipt_list with (security_invoker = true) as
select r.id, r.receipt_no, r.received_on, r.item_id, i.code, i.name, r.qty, r.unit, r.base_qty, i.unit as base_unit,
       pt.name as partner_name, l.lot_no, l.dried_date, l.expiry_date,
       r.is_void, r.void_reason, r.created_at, pr.name as created_by_name
  from receipts r
  join items i on i.id = r.item_id
  join lots l on l.id = r.lot_id
  left join partners pt on pt.id = r.partner_id
  left join profiles pr on pr.id = r.created_by;

-- 로트 추적: 입력 로트의 원재료 방향(backward) + 사용처 방향(forward) + 출고
create or replace function lot_trace(p_lot_no text)
returns table (direction text, depth int, lot_no text, item_code text, item_name text,
               dried_date date, expiry_date date, qty numeric, event text, event_date date, partner text)
language sql stable security invoker set search_path = public as $$
  with recursive
  start as (select id from lots where lot_no = p_lot_no),
  back as (
    select k.parent_lot_id as lot_id, 1 as depth, k.qty_used from lot_links k, start where k.child_lot_id = start.id and not k.is_void
    union all
    select k.parent_lot_id, b.depth + 1, k.qty_used from lot_links k join back b on k.child_lot_id = b.lot_id where not k.is_void and b.depth < 10
  ),
  fwd as (
    select k.child_lot_id as lot_id, 1 as depth, k.qty_used from lot_links k, start where k.parent_lot_id = start.id and not k.is_void
    union all
    select k.child_lot_id, f.depth + 1, k.qty_used from lot_links k join fwd f on k.parent_lot_id = f.lot_id where not k.is_void and f.depth < 10
  ),
  alllots as (
    select '원재료방향'::text dir, depth, lot_id, qty_used from back
    union all select '기준', 0, id, null from start
    union all select '사용처방향', depth, lot_id, qty_used from fwd
  )
  select a.dir, a.depth, l.lot_no, i.code, i.name, l.dried_date, l.expiry_date, a.qty_used,
         l.source, l.made_on, null::text
    from alllots a join lots l on l.id = a.lot_id join items i on i.id = l.item_id
  union all
  select '출고', a.depth, l.lot_no, i.code, i.name, l.dried_date, l.expiry_date, -m.qty,
         m.move_type, m.move_date, p.name
    from alllots a join lots l on l.id = a.lot_id join items i on i.id = l.item_id
    join stock_moves m on m.lot_id = l.id and m.move_type = '출고'
    left join partners p on p.id = m.partner_id
  order by 1, 2
$$;
