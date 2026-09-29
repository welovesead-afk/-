SET NAMES utf8mb4;
-- =====================================================================
-- 조회용 뷰 — Supabase 버전과 같은 이름·같은 컬럼
-- =====================================================================

CREATE OR REPLACE VIEW v_item_stock AS
SELECT i.id AS item_id, i.code, i.name, i.item_type, i.pack_kind, i.is_set, i.unit, i.spec,
       i.safety_stock,
       COALESCE(s.qty, 0)                                   AS stock_qty,
       COALESCE(s.qty, 0) < i.safety_stock                  AS below_safety,
       GREATEST(i.safety_stock - COALESCE(s.qty, 0), 0)     AS shortage_qty,
       s.last_moved_at
  FROM items i
  LEFT JOIN (SELECT item_id, SUM(qty) qty, MAX(moved_at) last_moved_at FROM stock_moves GROUP BY item_id) s
         ON s.item_id = i.id
 WHERE i.is_void = 0;

CREATE OR REPLACE VIEW v_lot_stock AS
SELECT l.id AS lot_id, l.lot_no, l.item_id, i.code, i.name, i.unit, l.source,
       l.dried_date, l.expiry_date, l.made_on, l.mixed_dried_dates,
       b.qty AS stock_qty,
       CASE WHEN l.expiry_date IS NOT NULL THEN DATEDIFF(l.expiry_date, CURDATE()) END AS days_to_expiry
  FROM lots l
  JOIN items i ON i.id = l.item_id
  JOIN (SELECT lot_id, SUM(qty) qty FROM stock_moves WHERE lot_id IS NOT NULL GROUP BY lot_id) b ON b.lot_id = l.id
 WHERE l.is_void = 0 AND b.qty <> 0;

CREATE OR REPLACE VIEW v_safety_shortage AS
SELECT * FROM v_item_stock
 WHERE safety_stock > 0 AND below_safety = 1;

CREATE OR REPLACE VIEW v_monthly_yield AS
SELECT DATE_FORMAT(p.work_date, '%Y-%m-01')                        AS month,
       p.product_item_id                                            AS item_id,
       i.code, i.name,
       COUNT(DISTINCT p.id)                                         AS runs,
       SUM(p.output_qty)                                            AS output_qty,
       SUM(p.defect_qty)                                            AS defect_qty,
       SUM(s.input_kg)                                              AS input_kg,
       SUM(s.output_kg)                                             AS output_kg,
       SUM(s.loss_kg)                                               AS loss_kg,
       SUM(s.scrap_kg)                                              AS scrap_kg,
       ROUND(SUM(s.output_kg) / NULLIF(SUM(s.input_kg), 0) * 100, 2) AS yield_pct,
       MAX(ps.std_yield_pct)                                        AS std_yield_pct,
       ROUND(SUM(s.output_kg) / NULLIF(SUM(s.input_kg), 0) * 100, 2) - MAX(ps.std_yield_pct) AS yield_gap_pct,
       SUM(p.work_minutes)                                          AS work_minutes
  FROM production_logs p
  JOIN items i ON i.id = p.product_item_id
  LEFT JOIN (SELECT log_id, SUM(input_kg) input_kg, SUM(output_kg) output_kg, SUM(loss_kg) loss_kg, SUM(scrap_kg) scrap_kg
               FROM production_steps WHERE is_void = 0 GROUP BY log_id) s ON s.log_id = p.id
  LEFT JOIN production_standards ps ON ps.item_id = p.product_item_id AND ps.step = '내포장' AND ps.is_void = 0
 WHERE p.is_void = 0
 GROUP BY 1, 2, 3, 4;

CREATE OR REPLACE VIEW v_production_list AS
SELECT p.id, p.log_no, p.work_date, p.product_item_id, i.code, i.name, i.unit,
       p.output_qty, p.defect_qty, l.lot_no, l.dried_date, l.expiry_date,
       (SELECT ROUND(SUM(output_kg) / NULLIF(SUM(input_kg), 0) * 100, 2)
          FROM production_steps s WHERE s.log_id = p.id AND s.is_void = 0) AS yield_pct,
       p.work_minutes, p.workers, p.is_void, p.void_reason, p.created_at, u.name AS created_by_name
  FROM production_logs p
  JOIN items i ON i.id = p.product_item_id
  LEFT JOIN lots l ON l.id = p.output_lot_id
  LEFT JOIN app_users u ON u.id = p.created_by;

CREATE OR REPLACE VIEW v_receipt_list AS
SELECT r.id, r.receipt_no, r.received_on, r.item_id, i.code, i.name, r.qty, r.unit, r.base_qty, i.unit AS base_unit,
       pt.name AS partner_name, l.lot_no, l.dried_date, l.expiry_date,
       r.is_void, r.void_reason, r.created_at, u.name AS created_by_name
  FROM receipts r
  JOIN items i ON i.id = r.item_id
  JOIN lots l ON l.id = r.lot_id
  LEFT JOIN partners pt ON pt.id = r.partner_id
  LEFT JOIN app_users u ON u.id = r.created_by;
