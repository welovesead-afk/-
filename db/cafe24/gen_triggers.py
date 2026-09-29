#!/usr/bin/env python3
"""카페24(MariaDB)용 트리거 SQL 생성기.

MariaDB 는 트리거를 동적으로 만들 수 없어서, 001·002 스키마를 적용한 로컬 DB의
컬럼 목록을 읽어 003_triggers.sql 을 만듭니다(수정 이력에 모든 컬럼을 JSON으로 기록).

사용: python3 gen_triggers.py --socket /var/tmp/mdb/sock --db sead_test > 003_triggers.sql
"""
import argparse
import subprocess

COMMON = ['partners', 'partner_aliases', 'items', 'item_aliases', 'item_units', 'item_suppliers',
          'bom', 'production_standards', 'lots', 'receipts', 'production_logs',
          'production_steps', 'production_inputs', 'lot_links',
          'sales_orders', 'sales_recipients', 'sales_lines']
PK = {'sales_recipients': 'order_id'}   # id 대신 다른 기본키를 쓰는 테이블
# 등록 후 직접 수정할 수 없는 컬럼(취소 후 재등록)
LOCKED = {
    'receipts': ['item_id', 'qty', 'unit', 'base_qty', 'lot_id', 'received_on', 'receipt_no'],
    'production_logs': ['product_item_id', 'output_qty', 'defect_qty', 'work_date', 'log_no'],
    'production_inputs': ['log_id', 'item_id', 'lot_id', 'planned_qty', 'actual_qty'],
    'lot_links': ['parent_lot_id', 'child_lot_id', 'production_log_id', 'qty_used'],
    'production_steps': ['log_id', 'step_no', 'input_kg', 'output_kg', 'loss_kg', 'scrap_kg'],
    'sales_orders': ['order_no'],
}
SKIP_DIFF = {'updated_at', 'updated_by'}
GENERATED = {'yield_pct', 'balance_kg'}


def columns(args, table):
    out = subprocess.run(
        ['mariadb', '-S', args.socket, '-u', args.user, '-N', '-B', '-e',
         f"select column_name from information_schema.columns where table_schema='{args.db}' "
         f"and table_name='{table}' order by ordinal_position"],
        check=True, capture_output=True, text=True).stdout.split()
    return out


def json_obj(prefix, cols):
    return 'JSON_OBJECT(' + ', '.join(f"'{c}', {prefix}.`{c}`" for c in cols) + ')'


def signal(msg):
    return f"SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '{msg}'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--socket', default='/var/tmp/mdb/sock')
    ap.add_argument('--user', default='root')
    ap.add_argument('--db', default='sead_test')
    args = ap.parse_args()

    o = []
    w = o.append
    w('-- =====================================================================')
    w('-- 자동 생성 파일 (gen_triggers.py) — 직접 고치지 말고 생성기를 다시 실행하세요')
    w('-- 삭제 금지 · 원장 수정 금지 · 수정 시각/작성자 · 취소 규칙 · 수정 이력')
    w('-- 작성자 = 세션 변수 @app_user_id (PHP가 로그인 확인 후 설정)')
    w('-- =====================================================================')
    w('DELIMITER $$')

    for t in COMMON:
        cols = columns(args, t)
        diff_cols = [c for c in cols if c not in SKIP_DIFF]
        w(f'\n-- {t}')
        w(f'CREATE TRIGGER {t}_bi BEFORE INSERT ON {t} FOR EACH ROW BEGIN')
        w('  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id;')
        w('  SET NEW.updated_at = NULL, NEW.updated_by = NULL, NEW.is_void = 0, NEW.voided_at = NULL, NEW.voided_by = NULL;')
        if t == 'lots':
            w('  IF NEW.expiry_date IS NULL AND NEW.dried_date IS NOT NULL THEN')
            w('    SET NEW.expiry_date = (SELECT DATE_ADD(NEW.dried_date, INTERVAL shelf_life_months MONTH) FROM items WHERE id = NEW.item_id);')
            w('  END IF;')
        w('END$$')

        w(f'CREATE TRIGGER {t}_bu BEFORE UPDATE ON {t} FOR EACH ROW BEGIN')
        w('  SET NEW.created_at = OLD.created_at, NEW.created_by = OLD.created_by;')
        w('  SET NEW.updated_at = NOW(), NEW.updated_by = @app_user_id;')
        w(f"  IF OLD.is_void = 1 AND NEW.is_void = 0 THEN {signal('취소된 기록은 되살릴 수 없습니다. 새로 등록하세요.')}; END IF;")
        w('  IF NEW.is_void = 1 AND OLD.is_void = 0 THEN')
        w(f"    IF COALESCE(TRIM(NEW.void_reason), '') = '' THEN {signal('취소 사유(void_reason)를 입력하세요.')}; END IF;")
        w('    SET NEW.voided_at = NOW(), NEW.voided_by = @app_user_id;')
        w('  ELSEIF NEW.is_void = OLD.is_void THEN')
        w('    SET NEW.voided_at = OLD.voided_at, NEW.voided_by = OLD.voided_by;')
        w('  END IF;')
        if t in LOCKED:
            cond = ' OR '.join(f'NOT (NEW.`{c}` <=> OLD.`{c}`)' for c in LOCKED[t])
            if t == 'production_logs':
                cond += ' OR (OLD.output_lot_id IS NOT NULL AND NOT (NEW.output_lot_id <=> OLD.output_lot_id))'
            w(f'  IF {cond} THEN')
            w(f"    {signal('[' + t + '] 핵심 값은 직접 수정할 수 없습니다. 취소 후 다시 등록하세요.')};")
            w('  END IF;')
        if t == 'sales_lines':
            w("  IF OLD.shipped = 1 AND (NOT (NEW.item_id <=> OLD.item_id) OR NOT (NEW.qty <=> OLD.qty)) THEN")
            w(f"    {signal('출고 처리된 품목·수량은 직접 수정할 수 없습니다. 주문을 취소 후 다시 등록하세요.')};")
            w('  END IF;')
        if t == 'lots':
            w('  IF NOT (NEW.dried_date <=> OLD.dried_date) AND NEW.dried_date IS NOT NULL AND NEW.expiry_date <=> OLD.expiry_date THEN')
            w('    SET NEW.expiry_date = (SELECT DATE_ADD(NEW.dried_date, INTERVAL shelf_life_months MONTH) FROM items WHERE id = NEW.item_id);')
            w('  END IF;')
        w('END$$')

        w(f"CREATE TRIGGER {t}_bd BEFORE DELETE ON {t} FOR EACH ROW {signal('[' + t + '] 기록은 삭제할 수 없습니다. 취소(is_void)로 처리하세요.')}$$")

        w(f'CREATE TRIGGER {t}_ai AFTER INSERT ON {t} FOR EACH ROW')
        w(f"  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('{t}', NEW.{PK.get(t, 'id')}, 'INSERT', @app_user_id, {json_obj('NEW', cols)})$$")

        w(f'CREATE TRIGGER {t}_au AFTER UPDATE ON {t} FOR EACH ROW BEGIN')
        w(f'  IF NOT ({json_obj("NEW", diff_cols)} <=> {json_obj("OLD", diff_cols)}) THEN')
        w(f"    INSERT INTO audit_log (table_name, row_id, action, changed_by, old_data, new_data)")
        w(f"    VALUES ('{t}', NEW.{PK.get(t, 'id')}, IF(NEW.is_void = 1 AND OLD.is_void = 0, 'VOID', 'UPDATE'), @app_user_id,")
        w(f'            {json_obj("OLD", cols)},')
        w(f'            {json_obj("NEW", cols)});')
        w('  END IF;')
        w('END$$')

    # 재고 원장
    sm = columns(args, 'stock_moves')
    w('\n-- stock_moves (추가만)')
    w('CREATE TRIGGER stock_moves_bi BEFORE INSERT ON stock_moves FOR EACH ROW BEGIN')
    w('  SET NEW.created_at = NOW(), NEW.created_by = @app_user_id, NEW.moved_at = NOW();')
    w('  IF NEW.move_date IS NULL THEN SET NEW.move_date = CURDATE(); END IF;')
    w('END$$')
    w(f"CREATE TRIGGER stock_moves_bu BEFORE UPDATE ON stock_moves FOR EACH ROW {signal('[stock_moves] 기록은 수정할 수 없습니다. 반대 기록을 추가해 바로잡으세요.')}$$")
    w(f"CREATE TRIGGER stock_moves_bd BEFORE DELETE ON stock_moves FOR EACH ROW {signal('[stock_moves] 기록은 삭제할 수 없습니다.')}$$")
    w('CREATE TRIGGER stock_moves_ai AFTER INSERT ON stock_moves FOR EACH ROW')
    w(f"  INSERT INTO audit_log (table_name, row_id, action, changed_by, new_data) VALUES ('stock_moves', NEW.id, 'INSERT', @app_user_id, {json_obj('NEW', sm)})$$")

    w('\n-- audit_log (추가만)')
    w(f"CREATE TRIGGER audit_log_bu BEFORE UPDATE ON audit_log FOR EACH ROW {signal('[audit_log] 수정 이력은 수정할 수 없습니다.')}$$")
    w(f"CREATE TRIGGER audit_log_bd BEFORE DELETE ON audit_log FOR EACH ROW {signal('[audit_log] 수정 이력은 삭제할 수 없습니다.')}$$")

    w('\n-- import_rows (추가만)')
    w(f"CREATE TRIGGER import_rows_bu BEFORE UPDATE ON import_rows FOR EACH ROW {signal('[import_rows] 가져오기 기록은 수정할 수 없습니다.')}$$")
    w(f"CREATE TRIGGER import_rows_bd BEFORE DELETE ON import_rows FOR EACH ROW {signal('[import_rows] 가져오기 기록은 삭제할 수 없습니다.')}$$")

    w('\n-- app_users: 삭제 대신 active = 0')
    w(f"CREATE TRIGGER app_users_bd BEFORE DELETE ON app_users FOR EACH ROW {signal('사용자는 삭제할 수 없습니다. active = 0 으로 중지하세요.')}$$")
    w('DELIMITER ;')
    print('SET NAMES utf8mb4;'); print('\n'.join(o))


if __name__ == '__main__':
    main()
