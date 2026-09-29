// 시안용 데모 데이터
// 완제품 목록·이름·사진은 「Product Catalogue」(46쪽), 품목·BOM 구성은 「총 제품 분류」 시트, 표준 수율·초/개는 「생산 동향 기록표」(2026-07-21, 1회 실측 임시값) 기준.
// 제품 사진은 「Product Catalogue」 PDF에서 추출(web/img/products).
// 안전재고·입고/생산 이력·수량은 화면 확인용 예시 값입니다(실제 값 아님).

export const ITEMS = [
  // 원재료
  { code: 'RM-01', name: '자연건조미역(기장산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '부산 기장군', safety_stock: 30, supplier: 'P-0001' },
  { code: 'RM-04', name: '자연건조다시마(기장산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '부산 기장군', safety_stock: 40, supplier: 'P-0002' },
  { code: 'RM-08', name: '자연건조자른미역(완도산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '전남 완도군', safety_stock: 13, supplier: 'P-0003' },
  { code: 'RM-09', name: '자연건조자른다시마(완도산)', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '전남 완도군', safety_stock: 10, supplier: 'P-0003' },
  { code: 'RM-11', name: '자른미역귀', item_type: 'RAW', unit: 'kg', shelf_life_months: 36, origin: '전남 완도군', safety_stock: 5, supplier: 'P-0003' },
  { code: 'RM-16', name: '디포리해물다시팩20g', item_type: 'RAW', unit: 'ea', shelf_life_months: 24, safety_stock: 50, supplier: 'P-0011' },
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
  { code: 'PK-W-08', name: '조각다시마 포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '16*17', safety_stock: 300, supplier: 'P-0004' },
  { code: 'PK-W-10', name: '조각미역귀 포장지', item_type: 'PACK', pack_kind: '포장지', unit: 'ea', size: '16*17', safety_stock: 300, supplier: 'P-0004' },
  { code: 'PK-B-03', name: '3종 OUT 上', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 100, supplier: 'P-0005' },
  { code: 'PK-B-04', name: '3종 OUT 下', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 100, needs_review: true, note: '제조사 한성쇼핑백/제일지기 뒤바뀜 확인' },
  { code: 'PK-B-05', name: '3종 OUT (쇼핑백)', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 100 },
  { code: 'PK-B-17', name: '조각해초세트 OUT박스', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 30, supplier: 'P-0005' },
  { code: 'PK-B-18', name: '조각해초세트 (손잡이)', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 30, supplier: 'P-0005' },
  { code: 'PK-B-19', name: '청정해역에서 자란 기장미역 200g 박스', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 50, supplier: 'P-0005' },
  { code: 'PK-B-20', name: '청정해역에서 자란 기장미역 띠지', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 50, supplier: 'P-0005' },
  { code: 'PK-B-21', name: '플라스틱 흰색 손잡이', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 100, supplier: 'P-0005' },
  { code: 'PK-B-40', name: '부산바다세트 OUT', item_type: 'PACK', pack_kind: '박스', unit: 'ea', safety_stock: 20, supplier: 'P-0005' },
  { code: 'PK-P-11', name: '기장다시마 300g (전면) 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 100 },
  { code: 'PK-P-12', name: '기장다시마 300g (후면) 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 100 },
  { code: 'PK-P-15', name: '조각미역귀50g 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 100 },
  { code: 'PK-P-18', name: '기장미역120g(소비기한) 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 100 },
  { code: 'PK-P-13', name: '톳50g(전면) 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 300 },
  // 반제품
  { code: 'SP-02', name: '기장미역150g (무지)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 60 },
  { code: 'SP-03', name: '기장미역150g (박스)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 20 },
  { code: 'SP-05', name: '기장미역200g (무지)', item_type: 'SEMI', unit: 'ea', spec: '200g', net_weight_g: 200, shelf_life_months: 36, safety_stock: 0 },
  { code: 'SP-08', name: '기장다시마150g (무지)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 40 },
  { code: 'SP-09', name: '기장다시마150g (박스)', item_type: 'SEMI', unit: 'ea', spec: '150g', net_weight_g: 150, shelf_life_months: 36, safety_stock: 20 },
  // 완제품 — 「Product Catalogue」 목록·이름 기준 (db/seed/finished_goods_catalog.csv), alias = 제품분류표 이름
  // 단품(기장산)
  { code: 'FG-01', name: '기장 건미역 20g', alias: '청정해역에서 자란 기장미역20g', item_type: 'FG', unit: 'ea', spec: '20g', net_weight_g: 20, shelf_life_months: 36, safety_stock: 100, img: 'miyeok-20g' },
  { code: 'FG-02', name: '기장 건미역 120g', alias: '기장미역120g(라벨)', item_type: 'FG', unit: 'ea', spec: '120g', net_weight_g: 120, shelf_life_months: 36, safety_stock: 30, img: 'miyeok-120g' },
  { code: 'FG-05', name: '기장 건다시마 120g', alias: '청정해역에서 자란 기장다시마 120g', item_type: 'FG', unit: 'ea', spec: '120g', net_weight_g: 120, shelf_life_months: 36, safety_stock: 0, img: 'dasima-120g' },
  { code: 'FG-06', name: 'SEA.D 기장 건다시마 300g', alias: '기장다시마 300g', item_type: 'FG', unit: 'ea', spec: '300g', net_weight_g: 300, shelf_life_months: 36, safety_stock: 0, img: 'dasima-300g' },
  // 단품(완도산)
  { code: 'FG-13', name: '자른 미역 30g', alias: '조각미역30g', item_type: 'FG', unit: 'ea', spec: '30g', net_weight_g: 30, shelf_life_months: 36, safety_stock: 50, img: 'cut-miyeok-30g' },
  { code: 'FG-14', name: '자른 다시마 50g', alias: '조각다시마50g', item_type: 'FG', unit: 'ea', spec: '50g', net_weight_g: 50, shelf_life_months: 36, safety_stock: 50, img: 'cut-dasima-50g' },
  { code: 'FG-15', name: '톳 50g', item_type: 'FG', unit: 'ea', spec: '50g', net_weight_g: 50, shelf_life_months: 36, safety_stock: 100, img: 'tot-50g' },
  { code: 'FG-16', name: '자른 미역귀 50g', alias: '조각미역귀50g', item_type: 'FG', unit: 'ea', spec: '50g', net_weight_g: 50, shelf_life_months: 36, safety_stock: 30, img: 'miyeokgwi-50g' },
  // 가공
  { code: 'FG-17', name: 'SEA.D 해물 육수팩 160g (20g×8)', alias: '디포리 해물다시팩 160g(파우치)', item_type: 'FG', unit: 'ea', spec: '160g', safety_stock: 30, img: 'broth-pack-160g' },
  { code: 'NEW-01', name: 'SEA.D 기장 미역 페스토 120g', item_type: 'FG', unit: 'ea', spec: '120g', safety_stock: 0, img: 'miyeok-pesto', needs_review: true, note: '신규 — 제조 방식 확인' },
  { code: 'NEW-02', name: 'SEA.D 다시마 피클', item_type: 'FG', unit: 'ea', spec: '150g/250g 확인', safety_stock: 0, img: 'dasima-pickle', needs_review: true, note: '카탈로그 150g·250g 불일치' },
  { code: 'NEW-03', name: 'SEA.D 기장 미역 아이올리 150g', item_type: 'FG', unit: 'ea', spec: '150g', safety_stock: 0, img: 'miyeok-aioli', needs_review: true },
  { code: 'NEW-04', name: 'SEA.D 간편 미역수프', item_type: 'FG', unit: 'ea', safety_stock: 0, img: 'miyeok-soup', needs_review: true, note: '규격 확인' },
  { code: 'NEW-05', name: 'SEA.D 다시마 우리밀 국수 (건면)', item_type: 'FG', unit: 'ea', safety_stock: 0, needs_review: true },
  { code: 'NEW-06', name: 'SEA.D 다시마 우리밀 국수 (냉동 일반면)', item_type: 'FG', unit: 'ea', safety_stock: 0, needs_review: true },
  { code: 'NEW-07', name: 'SEA.D 다시마 우리밀 국수 (냉동 납작면)', item_type: 'FG', unit: 'ea', safety_stock: 0, needs_review: true },
  // 선물세트
  { code: 'SET-01', name: '기장 미역 200g 선물세트', alias: '청정해역에서 자란 기장미역200g', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, img: 'set-miyeok-200g' },
  { code: 'SET-02', name: 'SEA.D 2종 선물세트 A (미역·다시마)', alias: '씨드2종세트A(미역,다시마)', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 10, img: 'set-2' },
  { code: 'SET-06', name: 'SEA.D 3종 선물세트 A (미역·다시마·미역)', alias: '씨드3종세트A(미역,다시마,미역)', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, img: 'set-3' },
  { code: 'SET-13', name: 'SEA.D 기장 프리미엄 해조류 선물세트 A', alias: '씨드 기장해조류 종합선물세트A', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, img: 'set-premium', note: '구성 BOM 확인 전' },
  { code: 'SET-18', name: '출산 축하 미역 선물세트', alias: '출산 축하미역세트', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, img: 'set-birth', note: '구성 BOM 확인 전' },
  { code: 'SET-19', name: '생일 미역 선물세트', alias: '하트미역 세트', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, img: 'set-birthday', note: '구성 BOM 확인 전' },
  { code: 'SET-21', name: '갑화량곡 선물세트', alias: '갑화량곡세트', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, img: 'set-gaphwa', note: '구성 BOM 확인 전' },
  { code: 'SET-24', name: '부산 바다 선물세트', alias: '부산바다세트', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 5, img: 'set-busan-sea' },
  { code: 'SET-25', name: '자른 미역 선물세트', alias: '조각해초세트', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 5, img: 'set-cut-seaweed', needs_review: true, note: '조각해초세트와 같은 제품인지 확인' },
  { code: 'SET-22', name: '기장미역 장곽 500g', item_type: 'FG', is_set: true, unit: 'ea', safety_stock: 0, note: '카탈로그에 없음 — 장부 판매 중' },
  // OEM (별도 관리) — OEM매입: 위탁 제조해 받아 옴 / OEM납품: 씨드가 만들어 고객사에 납품
  { code: 'FG-07', name: '하트 미역 20g', alias: '하트미역20g(기장산)', item_type: 'FG', unit: 'ea', spec: '20g', oem_type: 'OEM매입', oem_partner: 'P-0008', safety_stock: 200, supplier: 'P-0008', img: 'heart-miyeok-20g' },
  { code: 'FG-10', name: '건해초샐러드 7g', alias: '간편해초샐러드', item_type: 'FG', unit: 'ea', spec: '7g', oem_type: 'OEM매입', oem_partner: 'P-0009', safety_stock: 100, supplier: 'P-0009', img: 'seaweed-salad-7g' },
  { code: 'FG-19', name: "O'PEPPER × SEA.D 씨위드 페퍼", alias: '해조류 후추1.5g *12개입', item_type: 'FG', unit: 'ea', spec: '1.5g×12', oem_type: 'OEM매입', oem_partner: 'P-0010', safety_stock: 20, supplier: 'P-0010', img: 'seaweed-pepper' },
  { code: 'SET-17', name: '프리미엄 김 선물세트 (곱창돌김세트)', alias: '지주식 곱창돌김 세트', item_type: 'FG', is_set: true, unit: 'ea', oem_type: 'OEM납품', oem_partner: 'C-0006', safety_stock: 0, img: 'set-gim' },
  { code: 'OEM-WZ-01', name: '와이즐리 자른미역 200g', item_type: 'FG', unit: 'ea', spec: '200g', net_weight_g: 200, shelf_life_months: 36, oem_type: 'OEM납품', oem_partner: 'C-0005', safety_stock: 0 },
  { code: 'PK-P-16', name: '와이즐리 자른미역 200g 라벨', item_type: 'PACK', pack_kind: '라벨', unit: 'ea', safety_stock: 100 },
];

export const ITEM_UNITS = [
  { item: 'RM-01', unit: '벌크(10kg)', factor: 10 },
  { item: 'RM-04', unit: '벌크(20kg)', factor: 20 },
  { item: 'RM-08', unit: '벌크(13kg)', factor: 13 },
  { item: 'RM-10', unit: '벌크(20kg)', factor: 20 },
  { item: 'RM-09', unit: '벌크(20kg)', factor: 20 },
  { item: 'RM-11', unit: '벌크(10kg)', factor: 10 },
  { item: 'RM-16', unit: '벌크(300ea)', factor: 300 },
];

export const PARTNERS = [
  { code: 'P-0001', name: '기장해초생상자영업인', alias: '유은아', category: '원물생산자' },
  { code: 'P-0002', name: '김영태 (기장다시마)', alias: '김영태', category: '원물생산자', needs_review: true },
  { code: 'P-0003', name: '엘씨푸드', category: '원재료' },
  { code: 'P-0004', name: '금호산업 주식회사', alias: '금호산업', category: '포장재' },
  { code: 'P-0005', name: '제일지기', category: '포장재', needs_review: true },
  { code: 'P-0006', name: '해오름바이오', category: '위탁제조', needs_review: true },
  { code: 'P-0007', name: '(주)승인식품', alias: '승인식품', category: '위탁제조' },
  { code: 'P-0008', name: '주식회사 기장사람들', alias: '기장사람들', category: '위탁제조' },
  { code: 'P-0009', name: '(주)삼일물산', alias: '삼일물산', category: '위탁제조' },
  { code: 'P-0010', name: '오페퍼', category: '위탁제조', needs_review: true },
  { code: 'P-0011', name: '빅마마씨푸드주식회사', alias: '빅마마씨푸드', category: '위탁제조' },
  // 판매처(장부 탭)
  { code: 'C-0001', name: '주식회사 컬리', channel: '기업' },
  { code: 'C-0002', name: '주식회사 아난티', channel: '기업' },
  { code: 'C-0003', name: '중앙·경기·경북·강원 선관위', channel: '개인' },
  { code: 'C-0004', name: '전화 및 기타 주문', channel: '기타주문' },
  { code: 'C-0005', name: '주식회사 와이즐리컴퍼니', channel: 'OEM납품' },
  { code: 'C-0006', name: '생명물식품', channel: 'OEM납품', needs_review: true },
];

// 판매 예시(시안용 — 받는 사람은 가상의 이름)
export const SALES = [
  { ch: 'C-0001', type: '기업', day: 3, dest: '평택상온', lines: [['FG-13', 120, 1050], ['FG-05', 40, 4100]] },
  { ch: 'C-0002', type: '기업', day: 5, dest: '아난티코브 모비딕마켓', lines: [['FG-07', 50, 1050]] },
  { ch: 'C-0003', type: '개인', day: 6, rec: { name: '경기도선관위 총무과장 김가상', org: '경기도선관위', phone: '010-2222-3333', address: '경기도 수원시 팔달구 가상로 1' }, lines: [['SET-02', 1, 34000]] },
  { ch: 'C-0003', type: '개인', day: 6, rec: { name: '중앙선관위 주무관 이가상', org: '중앙선관위', phone: '010-4444-5555', address: '경기도 과천시 가상로 2' }, lines: [['SET-02', 1, 34000]] },
  { ch: 'C-0004', type: '기타주문', day: 7, rec: { name: '여가거가' }, delivery: '택배', lines: [['FG-01', 30, null], ['FG-07', 10, null]] },
  { ch: 'C-0004', type: '기타주문', day: 9, rec: { name: '박가상', phone: '010-6666-7777', address: '부산광역시 기장군 가상길 3' }, delivery: '직접수령', lines: [['SET-02', 3, 39000]] },
  { ch: 'C-0005', type: 'OEM납품', day: 10, lines: [['OEM-WZ-01', 60, null]] },
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
  ['FG-02', 'RM-01', 0.120, '내포장'], ['FG-02', 'PK-W-01', 1, '내포장'], ['FG-02', 'PK-P-18', 1, '외포장'],
  ['FG-06', 'RM-04', 0.300, '내포장'], ['FG-06', 'PK-W-02', 1, '내포장'], ['FG-06', 'PK-P-11', 1, '외포장'], ['FG-06', 'PK-P-12', 1, '외포장'],
  ['FG-14', 'RM-09', 0.050, '내포장'], ['FG-14', 'PK-W-08', 1, '내포장'],
  ['FG-16', 'RM-11', 0.050, '내포장'], ['FG-16', 'PK-W-10', 1, '내포장'], ['FG-16', 'PK-P-15', 1, '내포장'],
  ['FG-17', 'RM-16', 8, '내포장'], ['FG-17', 'PK-W-01', 1, '내포장'],
  ['SET-01', 'SP-05', 1, '외포장'], ['SET-01', 'PK-B-19', 1, '외포장'], ['SET-01', 'PK-B-20', 1, '외포장'], ['SET-01', 'PK-B-21', 1, '외포장'],
  ['SET-06', 'SP-03', 2, '외포장'], ['SET-06', 'SP-09', 1, '외포장'], ['SET-06', 'PK-B-03', 1, '외포장'], ['SET-06', 'PK-B-04', 1, '외포장'],
  ['SET-06', 'PK-B-05', 1, '외포장'], ['SET-06', 'PK-P-01', 1, '외포장'],
  ['SET-24', 'FG-01', 2, '외포장'], ['SET-24', 'FG-05', 1, '외포장'], ['SET-24', 'BY-04', 1, '외포장'], ['SET-24', 'PK-B-40', 1, '외포장'], ['SET-24', 'PK-P-01', 1, '외포장'],
  ['SET-25', 'FG-13', 1, '외포장'], ['SET-25', 'FG-14', 1, '외포장'], ['SET-25', 'FG-15', 1, '외포장'], ['SET-25', 'FG-16', 1, '외포장'],
  ['SET-25', 'PK-B-17', 1, '외포장'], ['SET-25', 'PK-B-18', 1, '외포장'], ['SET-25', 'PK-P-01', 1, '외포장'],
  ['OEM-WZ-01', 'RM-08', 0.200, '내포장'], ['OEM-WZ-01', 'PK-P-16', 1, '외포장'],
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
  'FG-02': { yield: 92.3, sec: 150, bulk: 1.3 },
  'FG-06': { yield: 94.5, sec: 457, bulk: 20 },
  'FG-14': { yield: 99.5, sec: 39, bulk: 20 },
};

export const USERS = [
  { id: 'u1', name: '대표', role: 'owner' },
  { id: 'u2', name: '직원A', role: 'staff' },
];
