// 시안용 데모 데이터
// 품목·BOM 구성은 「총 제품 분류」 시트, 표준 수율·초/개는 「생산 동향 기록표」(2026-07-21, 1회 실측 임시값) 기준.
// 제품 사진은 「Product Catalogue」 PDF에서 추출(web/img/products).
// 안전재고·입고/생산 이력·수량은 화면 확인용 예시 값입니다(실제 값 아님).

export const ITEMS = [
  // 원재료
  { code: 'RM-01', name: '자연건조미역(기장산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '부산 기장군', safety_stock: 30, supplier: 'P-0001' },
  { code: 'RM-04', name: '자연건조다시마(기장산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '부산 기장군', safety_stock: 40, supplier: 'P-0002' },
  { code: 'RM-08', name: '자연건조자른미역(완도산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '전남 완도군', safety_stock: 13, supplier: 'P-0003' },
  { code: 'RM-10', name: '톳', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '전남 완도군', safety_stock: 20, supplier: 'P-0003' },
  { code: 'RM-SCRAP', name: '미역 자투리(20cm 이하)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '부산 기장군', safety_stock: 0 },
  // 부재료
  { code: 'BY-04', name: '다시마 맛 간장 120ml', item_type: 'SUB', unit: 'ea', safety_stock: 50, supplier: 'P-0006' },
  { code: 'BY-02', name: '최순희 참기름 100ml', item_type: 'SUB', unit: 'ea', safety_stock: 20, supplier: 'P-0007' },
  // 포장재
  { code: 'PK-W-01', name: '150g 무지포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '24*34', safety_stock: 500, supplier: 'P-0004' },
  { code: 'PK-W-02', name: '200g 무지포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '22*56', safety_stock: 300, supplier: 'P-0004' },
  { code: 'PK-W-07', name: '조각미역 포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '16*17', safety_stock: 500, supplier: 'P-0004' },
  { code: 'PK-W-09', name: '톳 포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '16*17', safety_stock: 500, supplier: 'P-0004' },
  { code: 'PK-W-11', name: '청정해역에서 자란 기장미역 20g포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '12*25', safety_stock: 1000, supplier: 'P-0004' },
  { code: 'PK-W-12', name: '청정해역에서 자란 기장다시마 120g포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '24*34', safety_stock: 200 },
  { code: 'PK-B-01', name: '2종 OUT', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 100, supplier: 'P-0005' },
  { code: 'PK-B-02', name: '2종 (철팁끈)', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 200, supplier: 'P-0005' },
  { code: 'PK-B-22', name: '기장미역 150g IN box', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 200, supplier: 'P-0005' },
  { code: 'PK-B-23', name: '기장다시마 150g In box', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 150, supplier: 'P-0005' },
  { code: 'PK-P-01', name: '씨드 단면 리플렛', item_type: 'PACK', pack_kind: '인쇄물', unit: 'ea', safety_stock: 300 },
  { code: 'PK-P-13', name: '톳50g(전면) 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 300 },
  // 반제품
  { code: 'SP-02', name: '기장미역150g (무지)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 60 },
  { code: 'SP-03', name: '기장미역150g (박스)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 20 },
  { code: 'SP-05', name: '기장미역200g (무지)', item_type: 'SEMI', unit: 'ea', spec: '200g', net_weight_g: 200, shelf_life_months: 36, safety_stock: 0 },
  { code: 'SP-08', name: '기장다시마150g (무지)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 40 },
  { code: 'SP-09', name: '기장다시마150g (박스)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 20 },
  // 완제품
  { code: 'FG-01', name: '청정해역에서 자란 기장미역 20g', item_type: 'FG', unit: 'ea', spec: '20g', net_weight_g: 20, shelf_life_months: 36, safety_stock: 100, img: 'miyeok-20g' },
  { code: 'FG-05', name: '청정해역에서 자란 기장다시마 120g', item_type: 'FG', unit: 'ea', spec: '120g', net_weight_g: 120, shelf_life_months: 36, safety_stock: 0, img: 'dasima-120g' },
  { code: 'FG-13', name: '조각미역 30g', item_type: 'FG', unit: 'ea', spec: '30g', net_weight_g: 30, shelf_life_months: 36, safety_stock: 50, img: 'cut-miyeok-30g' },
  { code: 'FG-15', name: '톳 50g', item_type: 'FG', unit: 'ea', spec: '50g', net_weight_g: 50, shelf_life_months: 36, safety_stock: 100, img: 'tot-50g' },
  { code: 'SET-02', name: '씨드2종세트A (미역, 다시마)', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 10, img: 'set-2' },
];

export const ITEM_UNITS = [
  { item: 'RM-01', unit: '벌크(10kg)', factor: 10 },
  { item: 'RM-04', unit: '벌크(20kg)', factor: 20 },
  { item: 'RM-08', unit: '벌크(13kg)', factor: 13 },
  { item: 'RM-10', unit: '벌크(20kg)', factor: 20 },
];

export const PARTNERS = [
  { code: 'P-0001', name: '기장해초생상자영업인', alias: '유은아', category: '원물생산자' },
  { code: 'P-0002', name: '김영태 (기장다시마)', alias: '김영태', category: '원물생산자', needs_review: true },
  { code: 'P-0003', name: '엘씨푸드', category: '원재료' },
  { code: 'P-0004', name: '금호산업 주식회사', alias: '금호산업', category: '포장재' },
  { code: 'P-0005', name: '제일지기', category: '포장재', needs_review: true },
  { code: 'P-0006', name: '해오름바이오', category: '위탁제조', needs_review: true },
  { code: 'P-0007', name: '(주)승인식품', alias: '승인식품', category: '위탁제조' },
];

// [상위, 하위, 1개당 소요량, 공정]
export const BOM = [
  ['SP-02', 'RM-01', 0.150, '내포장'], ['SP-02', 'PK-W-01', 1, '내포장'],
  ['SP-03', 'SP-02', 1, '외포장'], ['SP-03', 'PK-B-22', 1, '외포장'],
  ['SP-05', 'RM-01', 0.200, '내포장'], ['SP-05', 'PK-W-02', 1, '내포장'],
  ['SP-08', 'RM-04', 0.150, '내포장'], ['SP-08', 'PK-W-01', 1, '내포장'],
  ['SP-09', 'SP-08', 1, '외포장'], ['SP-09', 'PK-B-23', 1, '외포장'],
  ['FG-01', 'RM-01', 0.020, '내포장'], ['FG-01', 'PK-W-11', 1, '내포장'],
  ['FG-05', 'RM-04', 0.120, '내포장'], ['FG-05', 'PK-W-12', 1, '내포장'],
  ['FG-13', 'RM-08', 0.030, '내포장'], ['FG-13', 'PK-W-07', 1, '내포장'],
  ['FG-15', 'RM-10', 0.050, '내포장'], ['FG-15', 'PK-W-09', 1, '내포장'], ['FG-15', 'PK-P-13', 1, '내포장'],
  ['SET-02', 'SP-03', 1, '외포장'], ['SET-02', 'SP-09', 1, '외포장'], ['SET-02', 'PK-B-01', 1, '외포장'],
  ['SET-02', 'PK-B-02', 2, '외포장'], ['SET-02', 'PK-P-01', 1, '외포장'],
];

// 생산 동향 기록표(1인 실측, 임시값)
export const STANDARDS = {
  'SP-02': { yield: 97.5, sec: 208, bulk: 10 },
  'SP-05': { yield: 86.0, sec: 209, bulk: 10 },
  'SP-08': { yield: 93.8, sec: 202, bulk: 20 },
  'FG-01': { yield: 88.0, sec: 43.6, bulk: 10 },
  'FG-05': { yield: 88.2, sec: 131, bulk: 20 },
  'FG-13': { yield: 98.1, sec: 31, bulk: 13 },
  'FG-15': { yield: 96.3, sec: 36, bulk: 20 },
};

export const USERS = [
  { id: 'u1', name: '대표', role: 'owner' },
  { id: 'u2', name: '직원A', role: 'staff' },
];
