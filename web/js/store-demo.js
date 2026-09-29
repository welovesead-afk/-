// 데모 저장소: 브라우저 안에서 DB 업무 함수(register_receipt, register_production ...)와 같은 규칙으로 동작.
// 나중에 같은 이름의 Supabase / 카페24 연결부로 바꿔 끼웁니다.
import { ITEMS, ITEM_UNITS, PARTNERS, BOM, STANDARDS, USERS, SALES } from './demo-data.js';

const KEY = 'sead-demo-v4';
const round3 = (n) => Math.round(n * 1000) / 1000;
const ymd = (d) => d.toISOString().slice(0, 10);
const yymmdd = (s) => s.slice(2, 4) + s.slice(5, 7) + s.slice(8, 10);
const addMonths = (s, m) => { const d = new Date(s + 'T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + m); return ymd(d); };
export const today = () => { const d = new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return ymd(d); };

let S = null;
let currentUser = USERS[1];

function blank() {
  return { seq: 1, items: [], units: [], partners: [], bom: [], standards: [], lots: [], receipts: [], logs: [],
           steps: [], inputs: [], links: [], moves: [], audit: [], counters: {}, orders: [], orderLines: [], recipients: [] };
}
function id() { return S.seq++; }
function save() { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { /* 저장 불가 환경 */ } }
function audit(table, row, action, oldRow) {
  S.audit.push({ id: id(), table, row_id: row.id, action, by: currentUser.name, at: new Date().toISOString(),
                 old: oldRow ? { ...oldRow } : null, new: { ...row } });
}
function insert(table, row) { row.id = id(); row.created_by = currentUser.name; row.created_at = new Date().toISOString(); S[table].push(row); audit(table, row, 'INSERT'); return row; }
function nextNo(prefix, day) {
  const k = prefix + '|' + day; S.counters[k] = (S.counters[k] || 0) + 1;
  return `${prefix}-${yymmdd(day)}-${String(S.counters[k]).padStart(2, '0')}`;
}
const item = (idOrCode) => S.items.find((i) => i.id === idOrCode || i.code === idOrCode);
const lotBal = (lotId) => round3(S.moves.filter((m) => m.lot_id === lotId).reduce((a, m) => a + m.qty, 0));
const itemBal = (itemId) => round3(S.moves.filter((m) => m.item_id === itemId).reduce((a, m) => a + m.qty, 0));
function move(row) { row.id = id(); row.created_by = currentUser.name; row.created_at = new Date().toISOString(); S.moves.push(row); return row; }

function toBase(it, qty, unit) {
  if (!unit || unit === it.unit) return qty;
  const u = S.units.find((x) => x.item_id === it.id && x.unit === unit);
  if (!u) throw new Error(`단위 "${unit}"를 ${it.unit}로 환산할 수 없습니다.`);
  return qty * u.factor;
}

// 선입선출: 소비기한(없으면 건조일·입고일) 빠른 로트부터
export function fefo(itemId, qty) {
  const lots = S.lots.filter((l) => l.item_id === itemId && !l.is_void)
    .map((l) => ({ l, bal: lotBal(l.id) })).filter((x) => x.bal > 0)
    .sort((a, b) => ((a.l.expiry_date || a.l.dried_date || a.l.made_on || '9999') < (b.l.expiry_date || b.l.dried_date || b.l.made_on || '9999') ? -1 : 1) || a.l.id - b.l.id);
  const out = []; let left = round3(qty);
  for (const { l, bal } of lots) { if (left <= 0) break; const t = round3(Math.min(bal, left)); out.push({ lot: l, qty: t }); left = round3(left - t); }
  if (left > 0) out.push({ lot: null, qty: left });
  return out;
}

function workMinutes(segs) {
  if (!segs || !segs.length) return null;
  const toM = (t) => { const [h, m] = t.split(':').map(Number); return h * 60 + m; };
  return segs.reduce((a, s) => {
    if (!s.start || !s.end) return a; const st = toM(s.start), en = toM(s.end); if (en <= st) return a;
    const ov = Math.max(0, Math.min(en, 750) - Math.max(st, 690)); return a + (en - st) - ov;
  }, 0);
}

// ---------------------------------------------------------------- 업무 함수
export function registerReceipt({ item_id, qty, unit, received_on, lot_no, partner_id, dried_date, note }) {
  const it = item(item_id); if (!it) throw new Error('품목을 선택하세요.');
  if (!(qty > 0)) throw new Error('수량은 0보다 커야 합니다.');
  received_on = received_on || today();
  const warnings = []; const base = round3(toBase(it, qty, unit || it.unit));
  let lot = lot_no ? S.lots.find((l) => l.lot_no === lot_no.trim()) : null;
  if (lot) {
    if (lot.item_id !== it.id) throw new Error(`로트 ${lot.lot_no}는 다른 품목의 로트입니다.`);
    warnings.push(`기존 로트 ${lot.lot_no}에 수량을 추가했습니다.`);
  } else {
    const prefix = { RAW: 'RM', SUB: 'BY', PACK: 'PK' }[it.item_type] || 'GR';
    lot = insert('lots', { lot_no: (lot_no && lot_no.trim()) || nextNo(prefix, received_on), item_id: it.id, source: '입고',
                           dried_date: dried_date || null, made_on: received_on,
                           expiry_date: dried_date && it.shelf_life_months ? addMonths(dried_date, it.shelf_life_months) : null });
  }
  if (it.item_type === 'RAW' && !lot.dried_date) warnings.push('원재료 건조일이 비어 있어 소비기한을 계산하지 못했습니다.');
  const r = insert('receipts', { receipt_no: nextNo('R', received_on), received_on, item_id: it.id, partner_id: partner_id || null,
                                 qty, unit: unit || it.unit, base_qty: base, lot_id: lot.id, note: note || null, is_void: false });
  move({ move_date: received_on, item_id: it.id, lot_id: lot.id, qty: base, move_type: '입고', ref: ['receipts', r.id] });
  save();
  return { receipt_no: r.receipt_no, lot_no: lot.lot_no, base_qty: base, unit: it.unit, expiry_date: lot.expiry_date, warnings };
}

// 화면 미리보기: BOM × 수량 → 투입 예정(선입선출 로트, 재고 부족 표시)
export function previewProduction(productId, outputQty, rawInputKg) {
  const lines = bomOf(productId).map((b) => {
    const c = item(b.child_item_id);
    let need = round3(b.qty_per * outputQty);
    const isRawKg = c.item_type === 'RAW' && c.unit === 'kg';
    if (isRawKg && rawInputKg > 0) need = round3(rawInputKg);
    const alloc = outputQty > 0 ? fefo(c.id, need) : [];
    return { item: c, qty_per: b.qty_per, planned: round3(b.qty_per * outputQty), need, stock: itemBal(c.id), alloc,
             short: alloc.some((a) => !a.lot), isRawKg };
  });
  return lines;
}

export function registerProduction({ product_id, output_qty, work_date, steps, defect_qty, workers, segments, issues, note }) {
  const p = item(product_id); if (!p) throw new Error('생산할 제품을 선택하세요.');
  if (!['SEMI', 'FG'].includes(p.item_type)) throw new Error('반제품·완제품만 생산 등록할 수 있습니다.');
  if (!(output_qty > 0)) throw new Error('산출 수량은 0보다 커야 합니다.');
  work_date = work_date || today();
  const warnings = [];
  const log = insert('logs', { log_no: nextNo('W', work_date), work_date, product_item_id: p.id, output_qty, defect_qty: defect_qty || 0,
                               workers: workers || null, segments: segments || null, work_minutes: workMinutes(segments),
                               issues: issues || null, note: note || null, is_void: false });
  const lot = insert('lots', { lot_no: nextNo((p.item_type === 'SEMI' ? 'IP-' : 'FP-') + p.code, work_date), item_id: p.id,
                               source: '생산', made_on: work_date, production_log_id: log.id });
  const rawIn = steps && steps[0] && steps[0].input_kg > 0 ? steps[0].input_kg : null;
  const lines = previewProduction(p.id, output_qty, bomOf(p.id).filter((b) => { const c = item(b.child_item_id); return c.item_type === 'RAW' && c.unit === 'kg'; }).length === 1 ? rawIn : null);
  if (!lines.length) warnings.push('이 제품의 BOM(구성)이 없어 투입 차감을 하지 않았습니다.');
  let rawKg = 0;
  for (const ln of lines) {
    ln.alloc.forEach((a, i) => {
      insert('inputs', { log_id: log.id, item_id: ln.item.id, lot_id: a.lot ? a.lot.id : null, planned_qty: i === 0 ? ln.planned : null, actual_qty: a.qty });
      move({ move_date: work_date, item_id: ln.item.id, lot_id: a.lot ? a.lot.id : null, qty: -a.qty, move_type: '생산투입', ref: ['logs', log.id] });
      if (a.lot) insert('links', { parent_lot_id: a.lot.id, child_lot_id: lot.id, log_id: log.id, qty_used: a.qty });
      else warnings.push(`${ln.item.name} 재고 부족: ${a.qty} ${ln.item.unit} 을(를) 로트 없이 차감했습니다.`);
      if (ln.isRawKg) rawKg += a.qty;
    });
  }
  const parents = S.links.filter((k) => k.child_lot_id === lot.id).map((k) => S.lots.find((l) => l.id === k.parent_lot_id));
  const dried = parents.map((l) => l.dried_date).filter(Boolean).sort();
  lot.dried_date = dried[0] || null;
  lot.mixed_dried_dates = new Set(dried).size > 1;
  lot.expiry_date = lot.dried_date && p.shelf_life_months ? addMonths(lot.dried_date, p.shelf_life_months)
    : (parents.map((l) => l.expiry_date).filter(Boolean).sort()[0] || null);
  if (lot.mixed_dried_dates) warnings.push('건조일이 다른 원재료 로트가 섞였습니다. 가장 이른 건조일로 소비기한을 계산했습니다.');
  log.output_lot_id = lot.id;
  move({ move_date: work_date, item_id: p.id, lot_id: lot.id, qty: output_qty, move_type: '생산산출', ref: ['logs', log.id] });

  let scrap = 0;
  if (steps && steps.length) {
    steps.forEach((s, i) => {
      insert('steps', { log_id: log.id, step_no: i + 1, step_name: s.step_name || '내포장', input_kg: +s.input_kg, output_kg: +s.output_kg,
                        loss_kg: +(s.loss_kg || 0), scrap_kg: +(s.scrap_kg || 0), loss_reason: s.loss_reason || null, is_void: false });
      scrap += +(s.scrap_kg || 0);
    });
  } else if (rawKg > 0 && p.net_weight_g) {
    insert('steps', { log_id: log.id, step_no: 1, step_name: '내포장', input_kg: round3(rawKg), output_kg: round3(output_qty * p.net_weight_g / 1000),
                      loss_kg: 0, scrap_kg: 0, note: '투입량·순중량으로 자동 계산', is_void: false });
  }
  const st = S.steps.filter((s) => s.log_id === log.id);
  if (st.some((s) => s.input_kg > 0 && Math.abs(s.input_kg - s.output_kg - s.loss_kg - s.scrap_kg) > Math.max(0.05, s.input_kg * 0.02))) {
    warnings.push('투입 − 산출 − 손실 − 자투리 차이가 2%를 넘습니다. 중량을 확인하세요.');
  }
  if (scrap > 0) {
    const sc = item('RM-SCRAP');
    const sl = insert('lots', { lot_no: nextNo('SC', work_date), item_id: sc.id, source: '생산', dried_date: lot.dried_date, made_on: work_date,
                                expiry_date: lot.dried_date ? addMonths(lot.dried_date, 36) : null, production_log_id: log.id });
    move({ move_date: work_date, item_id: sc.id, lot_id: sl.id, qty: round3(scrap), move_type: '생산산출', ref: ['logs', log.id], reason: '재사용 자투리' });
  }
  save();
  const inK = st.reduce((a, s) => a + s.input_kg, 0), outK = st.reduce((a, s) => a + s.output_kg, 0);
  return { log_no: log.log_no, lot_no: lot.lot_no, dried_date: lot.dried_date, expiry_date: lot.expiry_date,
           yield_pct: inK > 0 ? Math.round(outK / inK * 10000) / 100 : null, std_yield: STANDARDS[p.code]?.yield ?? null,
           inputs: S.inputs.filter((x) => x.log_id === log.id).map((x) => ({ item: item(x.item_id).name, qty: x.actual_qty, unit: item(x.item_id).unit,
             lot_no: S.lots.find((l) => l.id === x.lot_id)?.lot_no || null })), warnings };
}

function canVoid(row) {
  return currentUser.role === 'owner' || (row.created_by === currentUser.name && row.created_at.slice(0, 10) === new Date().toISOString().slice(0, 10));
}
function reverse(ref, reason) {
  S.moves.filter((m) => m.ref && m.ref[0] === ref[0] && m.ref[1] === ref[1] && m.move_type !== '취소' && !S.moves.some((x) => x.reverses_id === m.id))
    .forEach((m) => move({ move_date: today(), item_id: m.item_id, lot_id: m.lot_id, qty: -m.qty, move_type: '취소', ref, reverses_id: m.id, reason }));
}
function voidRow(table, row, reason) { const old = { ...row }; row.is_void = true; row.void_reason = reason; row.voided_by = currentUser.name; row.voided_at = new Date().toISOString(); audit(table, row, 'VOID', old); }

export function voidReceipt(receiptId, reason) {
  const r = S.receipts.find((x) => x.id === receiptId);
  if (!r || r.is_void) throw new Error('취소할 입고가 없거나 이미 취소되었습니다.');
  if (!canVoid(r)) throw new Error('직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.');
  if (!reason || !reason.trim()) throw new Error('취소 사유를 입력하세요.');
  if (lotBal(r.lot_id) < r.base_qty) throw new Error('이 입고 로트는 이미 생산·출고에 사용되었습니다. 사용 기록을 먼저 취소하세요.');
  reverse(['receipts', r.id], reason); voidRow('receipts', r, reason); save();
}
export function voidProduction(logId, reason) {
  const g = S.logs.find((x) => x.id === logId);
  if (!g || g.is_void) throw new Error('취소할 생산일지가 없거나 이미 취소되었습니다.');
  if (!canVoid(g)) throw new Error('직원은 당일 본인이 등록한 기록만 취소할 수 있습니다.');
  if (!reason || !reason.trim()) throw new Error('취소 사유를 입력하세요.');
  const outLots = S.lots.filter((l) => l.production_log_id === g.id);
  const used = outLots.some((l) => lotBal(l.id) < S.moves.filter((m) => m.lot_id === l.id && m.ref && m.ref[0] === 'logs' && m.ref[1] === g.id && m.qty > 0).reduce((a, m) => a + m.qty, 0));
  if (used) throw new Error('이 생산 로트는 이미 다음 공정·출고에 사용되었습니다. 사용 기록을 먼저 취소하세요.');
  reverse(['logs', g.id], reason); voidRow('logs', g, reason);
  S.steps.filter((s) => s.log_id === g.id).forEach((s) => { s.is_void = true; });
  outLots.forEach((l) => { l.is_void = true; });
  save();
}
export function registerShipment(itemId, qty, date) {
  fefo(itemId, qty).forEach((a) => move({ move_date: date || today(), item_id: itemId, lot_id: a.lot ? a.lot.id : null, qty: -a.qty, move_type: '출고' }));
  save();
}

// 판매 등록: 주문 + 품목 + 받는 사람(개인정보) + 출고일이 있으면 선입선출 출고
export function registerSale({ channel_type, channel_partner_id, order_date, ship_date, destination, delivery_method, lines, recipient }) {
  if (!lines || !lines.length) throw new Error('주문 품목이 없습니다.');
  const day = ship_date || order_date || today(); const warnings = [];
  const o = insert('orders', { order_no: nextNo('S', day), channel_type, channel_partner_id, order_date, ship_date, destination: destination || null,
                               delivery_method: delivery_method || null, is_void: false });
  if (recipient && (recipient.name || recipient.phone || recipient.address)) S.recipients.push({ order_id: o.id, ...recipient });
  lines.forEach((l, i) => {
    const ln = insert('orderLines', { order_id: o.id, line_no: i + 1, item_id: l.item_id || null, item_text: l.item_text || item(l.item_id)?.name,
                                      qty: l.qty, unit_price: l.unit_price ?? null, total: l.unit_price != null ? l.unit_price * l.qty : null, shipped: false, is_void: false });
    if (l.item_id && ship_date) {
      fefo(l.item_id, l.qty).forEach((a) => {
        move({ move_date: ship_date, item_id: l.item_id, lot_id: a.lot ? a.lot.id : null, qty: -a.qty, move_type: '출고', ref: ['orderLines', ln.id] });
        if (!a.lot) warnings.push(`${item(l.item_id).name} 재고 부족: ${a.qty} 을(를) 로트 없이 출고했습니다.`);
      });
      ln.shipped = true;
    }
  });
  save();
  return { order_no: o.order_no, warnings };
}
const maskName = (p) => { if (!p) return p; const t = p.trim(); const w = t.split(/\s+/).pop(); return t.slice(0, t.length - w.length) + w[0] + '○'.repeat(Math.max(w.length - 1, 1)); };
const maskPhone = (p) => p && p.replace(/(\d{2,3})[- ]?\d{3,4}[- ]?(\d{4})/, '$1-****-$2');
// 주문 목록: 대표 = 원문, 직원 = 가린 값 (DB 의 v_sales_list 와 같은 규칙)
export function salesList(channelType) {
  const owner = currentUser.role === 'owner';
  return [...S.orders].reverse().filter((o) => !channelType || o.channel_type === channelType).map((o) => {
    const r = S.recipients.find((x) => x.order_id === o.id) || {};
    const lines = S.orderLines.filter((l) => l.order_id === o.id && !l.is_void);
    return { ...o, channel: S.partners.find((p) => p.id === o.channel_partner_id)?.name,
             recipient_name: owner ? r.name : maskName(r.name), recipient_org: r.org, phone: owner ? r.phone : maskPhone(r.phone),
             address: owner ? r.address : (r.address ? r.address.split(' ')[0] + ' …' : null),
             lines: lines.map((l) => ({ ...l, item: item(l.item_id) })),
             amount: lines.some((l) => l.total != null) ? lines.reduce((a, l) => a + (l.total || 0), 0) : null };
  });
}
export function salesSummary(month) {
  const out = {};
  S.orders.filter((o) => !o.is_void && (o.ship_date || o.order_date || '').slice(0, 7) === month).forEach((o) => {
    const k = o.channel_type; const r = out[k] || (out[k] = { orders: 0, qty: 0, amount: 0, noAmount: 0 });
    r.orders++; S.orderLines.filter((l) => l.order_id === o.id && !l.is_void).forEach((l) => { r.qty += l.qty; if (l.total != null) r.amount += l.total; else r.noAmount++; });
  });
  return out;
}

// ---------------------------------------------------------------- 조회
export const listItems = (types) => S.items.filter((i) => !types || types.includes(i.item_type));
export const listPartners = () => S.partners;
export const unitsOf = (itemId) => { const it = item(itemId); return [it.unit, ...S.units.filter((u) => u.item_id === itemId).map((u) => u.unit)]; };
export const unitFactor = (itemId, unit) => S.units.find((u) => u.item_id === itemId && u.unit === unit)?.factor || 1;
export const bomOf = (itemId) => S.bom.filter((b) => b.parent_item_id === itemId);
export const getItem = item;
export const standardOf = (code) => STANDARDS[code] || null;
export const primarySupplier = (itemId) => S.partners.find((p) => p.code === item(itemId).supplier) || null;
export const nextLotPreview = (itemId, day) => {
  const it = item(itemId); const prefix = { RAW: 'RM', SUB: 'BY', PACK: 'PK' }[it.item_type] || 'GR';
  const n = (S.counters[prefix + '|' + day] || 0) + 1; return `${prefix}-${yymmdd(day)}-${String(n).padStart(2, '0')}`;
};
export const user = () => currentUser;
export const setUser = (role) => { currentUser = USERS.find((u) => u.role === role) || currentUser; };

export function itemStock() {
  return S.items.map((i) => { const q = itemBal(i.id); return { ...i, stock_qty: q, below_safety: i.safety_stock > 0 && q < i.safety_stock,
    shortage_qty: Math.max(0, round3(i.safety_stock - q)) }; });
}
export function lotStock(itemId) {
  return S.lots.filter((l) => !l.is_void && (!itemId || l.item_id === itemId)).map((l) => ({ ...l, stock_qty: lotBal(l.id), item: item(l.item_id) }))
    .filter((l) => l.stock_qty !== 0);
}
export function monthlyYield(month) {
  const rows = {};
  S.logs.filter((g) => !g.is_void && g.work_date.slice(0, 7) === month).forEach((g) => {
    const it = item(g.product_item_id);
    const r = rows[it.id] || (rows[it.id] = { item: it, runs: 0, output_qty: 0, defect_qty: 0, input_kg: 0, output_kg: 0, loss_kg: 0, scrap_kg: 0, minutes: 0 });
    r.runs++; r.output_qty += g.output_qty; r.defect_qty += g.defect_qty; r.minutes += g.work_minutes || 0;
    S.steps.filter((s) => s.log_id === g.id && !s.is_void).forEach((s) => { r.input_kg += s.input_kg; r.output_kg += s.output_kg; r.loss_kg += s.loss_kg; r.scrap_kg += s.scrap_kg; });
  });
  return Object.values(rows).map((r) => ({ ...r, yield_pct: r.input_kg > 0 ? Math.round(r.output_kg / r.input_kg * 10000) / 100 : null,
    std_yield: STANDARDS[r.item.code]?.yield ?? null, sec_per_ea: r.output_qty > 0 && r.minutes ? Math.round(r.minutes * 60 / r.output_qty) : null }));
}
export function receiptList(limit = 20) {
  return [...S.receipts].reverse().slice(0, limit).map((r) => ({ ...r, item: item(r.item_id), lot: S.lots.find((l) => l.id === r.lot_id),
    partner: S.partners.find((p) => p.id === r.partner_id), can_void: !r.is_void && canVoid(r) }));
}
export function productionList(limit = 20) {
  return [...S.logs].reverse().slice(0, limit).map((g) => {
    const st = S.steps.filter((s) => s.log_id === g.id); const inK = st.reduce((a, s) => a + s.input_kg, 0); const outK = st.reduce((a, s) => a + s.output_kg, 0);
    return { ...g, item: item(g.product_item_id), lot: S.lots.find((l) => l.id === g.output_lot_id), yield_pct: inK > 0 ? Math.round(outK / inK * 10000) / 100 : null,
             can_void: !g.is_void && canVoid(g) };
  });
}
export const auditCount = () => S.audit.length;

// ---------------------------------------------------------------- 초기화·예시 이력
function seedMaster() {
  S = blank();
  ITEMS.forEach((i) => { S.items.push({ ...i, id: id(), is_set: !!i.is_set }); });
  ITEM_UNITS.forEach((u) => S.units.push({ id: id(), item_id: item(u.item).id, unit: u.unit, factor: u.factor }));
  PARTNERS.forEach((p) => S.partners.push({ ...p, id: id() }));
  S.items.forEach((i) => { if (i.oem_partner) i.oem_partner_id = S.partners.find((p) => p.code === i.oem_partner)?.id; });
  BOM.forEach(([p, c, q, st]) => S.bom.push({ id: id(), parent_item_id: item(p).id, child_item_id: item(c).id, qty_per: q, step: st }));
}
function seedHistory() {
  const t = today(); const month = t.slice(0, 8); const dayN = Math.max(Number(t.slice(8, 10)) - 1, 1);
  const d = (n) => month + String(Math.min(n, dayN)).padStart(2, '0');
  const prevMonth = addMonths(month + '01', -1);
  currentUser = USERS[0];
  const opening = { 'PK-W-01': 1200, 'PK-W-02': 400, 'PK-W-07': 1200, 'PK-W-09': 1100, 'PK-W-11': 2400, 'PK-W-12': 180, 'PK-B-01': 90,
                    'PK-B-02': 400, 'PK-B-22': 420, 'PK-B-23': 260, 'PK-P-01': 400, 'PK-P-13': 900, 'BY-04': 70, 'BY-02': 35,
                    'PK-W-08': 600, 'PK-W-10': 400, 'PK-B-03': 120, 'PK-B-04': 120, 'PK-B-05': 120, 'PK-B-17': 60, 'PK-B-18': 60,
                    'PK-B-19': 80, 'PK-B-20': 80, 'PK-B-21': 150, 'PK-B-40': 40, 'PK-P-11': 150, 'PK-P-12': 150, 'PK-P-15': 200, 'PK-P-18': 150 };
  Object.entries(opening).forEach(([code, q]) => {
    const it = item(code); const l = insert('lots', { lot_no: nextNo('OP', prevMonth), item_id: it.id, source: '기초', made_on: prevMonth });
    move({ move_date: prevMonth, item_id: it.id, lot_id: l.id, qty: q, move_type: '기초', reason: '기초재고(예시)' });
  });
  currentUser = USERS[1];
  const P = (code) => S.partners.find((p) => p.code === code).id;
  registerReceipt({ item_id: item('RM-01').id, qty: 5, unit: '벌크(10kg)', received_on: prevMonth, partner_id: P('P-0001'), dried_date: addMonths(prevMonth, -5) });
  registerReceipt({ item_id: item('RM-04').id, qty: 3, unit: '벌크(20kg)', received_on: prevMonth, partner_id: P('P-0002'), dried_date: addMonths(prevMonth, -4) });
  registerReceipt({ item_id: item('RM-08').id, qty: 2, unit: '벌크(13kg)', received_on: prevMonth, partner_id: P('P-0003'), dried_date: addMonths(prevMonth, -3) });
  registerReceipt({ item_id: item('RM-10').id, qty: 2, unit: '벌크(20kg)', received_on: prevMonth, partner_id: P('P-0003'), dried_date: addMonths(prevMonth, -3) });
  registerReceipt({ item_id: item('RM-01').id, qty: 2, unit: '벌크(10kg)', received_on: d(3), partner_id: P('P-0001'), dried_date: addMonths(month + '01', -4) });
  const prod = (code, qty, day, inKg, lossKg, scrapKg, reason, seg) => registerProduction({ product_id: item(code).id, output_qty: qty, work_date: d(day),
    steps: inKg ? [{ step_name: '절단·소분', input_kg: inKg, output_kg: round3(qty * item(code).net_weight_g / 1000), loss_kg: lossKg, scrap_kg: scrapKg, loss_reason: reason }] : null,
    workers: 1, segments: seg });
  prod('SP-02', 65, 2, 10, 0.15, 0.1, '절단 자투리', [{ start: '13:20', end: '17:05' }]);
  prod('FG-01', 440, 4, 10, 1.1, 0.1, '절단 자투리', [{ start: '08:30', end: '14:50' }]);
  prod('SP-08', 125, 5, 20, 1.0, 0.25, '절단 자투리', [{ start: '08:30', end: '16:30' }]);
  prod('FG-13', 425, 6, 13, 0.2, 0, '계량차', [{ start: '08:30', end: '13:10' }]);
  prod('SP-02', 60, 8, 9.4, 0.3, 0.1, '파손', [{ start: '08:30', end: '12:00' }]);
  prod('FG-15', 385, 9, 20, 0.7, 0, '이물 선별', [{ start: '08:30', end: '13:20' }]);
  prod('SP-03', 80, 10, null);
  prod('SP-09', 70, 10, null);
  prod('SET-02', 45, 11, null);
  registerShipment(item('SET-02').id, 30, d(12));
  registerShipment(item('FG-01').id, 280, d(12));
  registerReceipt({ item_id: item('RM-09').id, qty: 1, unit: '벌크(20kg)', received_on: prevMonth, partner_id: P('P-0003'), dried_date: addMonths(prevMonth, -3) });
  registerReceipt({ item_id: item('RM-11').id, qty: 1, unit: '벌크(10kg)', received_on: prevMonth, partner_id: P('P-0003'), dried_date: addMonths(prevMonth, -3) });
  registerReceipt({ item_id: item('RM-16').id, qty: 1, unit: '벌크(300ea)', received_on: prevMonth, partner_id: P('P-0011') });
  registerReceipt({ item_id: item('FG-19').id, qty: 40, received_on: prevMonth, partner_id: P('P-0010') });
  prod('FG-14', 180, 4, 9.2, 0.1, 0, '계량차', [{ start: '13:00', end: '15:10' }]);
  prod('FG-16', 90, 5, 4.7, 0.15, 0, '이물 선별', [{ start: '13:00', end: '14:20' }]);
  prod('FG-17', 30, 5, null);
  prod('FG-02', 20, 6, 2.6, 0.2, 0, '절단 자투리', [{ start: '14:00', end: '14:50' }]);
  prod('SET-25', 25, 11, null);
  prod('SET-24', 12, 11, null);
  registerReceipt({ item_id: item('RM-08').id, qty: 1, unit: '벌크(13kg)', received_on: d(8), partner_id: P('P-0003'), dried_date: addMonths(month + '01', -2) });
  prod('FG-05', 130, 3, 17.6, 1.4, 0.3, '절단 자투리', [{ start: '08:30', end: '13:30' }]);
  registerReceipt({ item_id: item('FG-07').id, qty: 400, received_on: d(2), partner_id: P('P-0008') });
  registerReceipt({ item_id: item('FG-10').id, qty: 150, received_on: d(2), partner_id: P('P-0009') });
  registerReceipt({ item_id: item('PK-P-16').id, qty: 200, received_on: prevMonth });
  prod('OEM-WZ-01', 60, 9, 12.3, 0.2, 0, '계량차', [{ start: '13:00', end: '15:00' }]);
  SALES.forEach((x) => registerSale({ channel_type: x.type, channel_partner_id: S.partners.find((p) => p.code === x.ch).id, order_date: d(x.day - 1), ship_date: d(x.day),
    destination: x.dest, delivery_method: x.delivery, recipient: x.rec, lines: x.lines.map(([c, q, pr]) => ({ item_id: item(c).id, qty: q, unit_price: pr })) }));
  registerShipment(item('FG-13').id, 200, d(13));
  // 예시 기록의 작성 시각을 작업일로 맞춤(당일 취소 규칙 확인용)
  S.receipts.forEach((r) => { r.created_at = r.received_on + 'T09:00:00.000Z'; });
  S.logs.forEach((g) => { g.created_at = g.work_date + 'T09:00:00.000Z'; });
}
export function reset() { seedMaster(); seedHistory(); save(); }
export function init() {
  try { const raw = localStorage.getItem(KEY); if (raw) { S = JSON.parse(raw); return; } } catch (e) { /* 무시 */ }
  reset();
}
