#!/usr/bin/env python3
"""구글드라이브 월별 장부(xlsx 사본)를 한 형식으로 읽기 — 원본 파일은 읽기만 합니다.

대상 (월별 파일, 탭 = 거래처)
  sales   : 매출(출고) 내역   — 탭 예: '01 컬리', '16 전화 및 기타 주문'
  pack    : 부자재 매입 내역  — 탭 예: '01 제일지기', '05 카톤박스'
  raw     : 원자재 매입 내역  — 탭 예: '01 엘씨푸드', '07 미역'

사용: python3 parse_ledgers.py <출력.csv> <xlsx 파일 ...>
"""
import csv
import datetime as dt
import re
import sys

import openpyxl

# 머리글 글자 → 표준 열 이름 (공백 제거 후 비교)
HEADER = [
    ('order_date', ['발주일자']),
    ('ship_date', ['출고일자', '출고일']),
    ('in_date', ['입고일자']),
    ('settle_date', ['정산일자']),
    ('counterpart', ['발주처']),
    ('item_text', ['품목', '제품명/구성', '제품명']),
    ('qty', ['수량', '수량(ea)', '중량']),
    ('unit', ['단위']),
    ('box_qty', ['박스수량']),
    ('unit_price', ['단가', '단가(원)', '단가(kg)']),
    ('supply_amount', ['공급가액', '공급가', '금액']),
    ('vat', ['부가세', '세액']),
    ('total', ['합계', '합계금액']),
    ('shipping_fee', ['배송비']),
    ('expiry', ['소비기한']),
    ('delivery', ['배송유무']),
    ('writer', ['작성자']),
    ('destination', ['입고처', '납품처', '납품기관']),
    ('recipient', ['수취인']),
    ('affiliation', ['소속']),
    ('note', ['비고']),
]
FIELDS = ['source_file', 'kind', 'month', 'sheet', 'partner_tab', 'row'] + [h for h, _ in HEADER]


def norm(v):
    return re.sub(r'\s+', '', str(v)) if v is not None else ''


def kind_of(title):
    t = norm(title)
    if '매출' in t:
        return 'sales'
    if '부자재' in t:
        return 'pack'
    if '원자재' in t or '원재료' in t:
        return 'raw'
    if '비품' in t:
        return 'supplies'
    return 'unknown'


def as_date(v):
    if isinstance(v, dt.datetime):
        return v.date().isoformat()
    if isinstance(v, dt.date):
        return v.isoformat()
    return None if v in (None, '') else str(v)


def parse(path, month):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    out = []
    for ws in wb.worksheets:
        rows = list(ws.iter_rows(values_only=True))
        if not rows:
            continue
        title = next((c for c in rows[0] if c not in (None, '■')), '') if rows else ''
        kind = kind_of(title)
        # 머리글 행: '품목' 또는 '제품명' 이 있는 첫 행
        hi = next((i for i, r in enumerate(rows[:10]) if any(norm(c) in ('품목', '제품명/구성', '제품명') for c in r)), None)
        if hi is None:
            continue
        cols = {}
        for ci, c in enumerate(rows[hi]):
            n = norm(c)
            for key, names in HEADER:
                if n in names and key not in cols:
                    cols[key] = ci
        last_col = max(cols.values())
        carry = {}
        for ri in range(hi + 1, len(rows)):
            r = rows[ri]
            get = lambda k: r[cols[k]] if k in cols and cols[k] < len(r) else None
            item = get('item_text')
            if item in (None, '') or norm(item) in ('품목', '제품명/구성', '제품명'):
                continue  # 빈 줄·중간에 반복된 머리글
            rec = {k: get(k) for k, _ in HEADER}
            # '발주처' 가 있는 탭(전화·기타 주문)은 한 주문의 여러 줄 → 위 줄 날짜·발주처 이어받기
            if 'counterpart' in cols:
                for k in ('order_date', 'ship_date', 'counterpart', 'delivery'):
                    if rec[k] in (None, ''):
                        rec[k] = carry.get(k)
                    else:
                        carry[k] = rec[k]
            for k in ('order_date', 'ship_date', 'in_date', 'settle_date', 'expiry'):
                rec[k] = as_date(rec[k])
            rec.update(source_file=path.split('/')[-1], kind=kind, month=month, sheet=ws.title.strip(),
                       partner_tab=re.sub(r'^\s*\d+\s*', '', ws.title).strip(), row=ri + 1)
            out.append(rec)
    return out


def main():
    dest, files = sys.argv[1], sys.argv[2:]
    allrows = []
    for f in files:
        m = re.search(r'-0?(\d)_', f)
        allrows += parse(f, int(m.group(1)) if m else None)
    with open(dest, 'w', newline='', encoding='utf-8-sig') as fp:
        w = csv.DictWriter(fp, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(allrows)
    print(f'{len(allrows)} rows -> {dest}')


if __name__ == '__main__':
    main()
