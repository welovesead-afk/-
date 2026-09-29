// SEA.D 통합관리 — 화면 (시안: 데모 저장소 사용)
import * as db from './store-demo.js';

const $ = (s, el = document) => el.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n, d = 3) => (n == null || Number.isNaN(n)) ? '-' : Number(n).toLocaleString('ko-KR', { maximumFractionDigits: d });
// 화면 표시는 회사 장부 용어(원자재/부자재), OEM 은 별도 구분
const TYPE = { RAW: '원자재', SUB: '원자재(가공)', PACK: '부자재', SEMI: '반제품', FG: '완제품' };
const typeLabel = (i) => i.oem_type ? i.oem_type : (TYPE[i.item_type] + (i.is_set ? '(세트)' : ''));
// 입고 구분 → 품목 조건
const RECEIVE_CATS = {
  '원자재': (i) => ['RAW', 'SUB'].includes(i.item_type) && !i.oem_type,
  '부자재': (i) => i.item_type === 'PACK',
  'OEM': (i) => i.oem_type === 'OEM매입',
};
const ICON = {
  critical: '<svg class="ic" viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M8 1l7 13H1z"/><path fill="#fff" d="M7.3 6h1.4v4H7.3zM7.3 11h1.4v1.4H7.3z"/></svg>',
  good: '<svg class="ic" viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="7" fill="currentColor"/><path d="M4.5 8.2l2.3 2.2 4.7-4.8" stroke="#fff" stroke-width="1.8" fill="none"/></svg>',
  warning: '<svg class="ic" viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="7" fill="currentColor"/><path fill="#241916" d="M7.3 4h1.4v5H7.3zM7.3 10.5h1.4v1.4H7.3z"/></svg>',
};
// 다시 그리는 도중(포커스 이동 → change 이벤트) 겹쳐 호출되지 않게 막음
const guard = (fn) => { let busy = false; return (...a) => { if (busy) return; busy = true; try { fn(...a); } finally { busy = false; } }; };
const thumb = (it, size = 40) => it && it.img
  ? `<img class="thumb" src="img/products/${esc(it.img)}.jpg" alt="" width="${size}" height="${size}" loading="lazy">`
  : `<span class="thumb ph-thumb" style="width:${size}px;height:${size}px" aria-hidden="true">${esc((TYPE[it?.item_type] || '').slice(0, 1))}</span>`;
const status = (kind, text) => `<span class="status ${kind}">${ICON[kind]}${esc(text)}</span>`;

db.init();

// ------------------------------------------------------------ 공통: 품목 선택 시트
function pickItem({ title, filter, onPick }) {
  const bg = document.createElement('div');
  bg.className = 'sheet-bg';
  const stock = Object.fromEntries(db.itemStock().map((i) => [i.id, i]));
  const render = (q) => {
    const items = db.listItems().filter(filter).filter((i) => !q || (i.name + i.code).toLowerCase().includes(q.toLowerCase()));
    const keys = [...new Set(items.map(typeLabel))];
    const groups = keys.map((k) => [k, items.filter((i) => typeLabel(i) === k)]);
    return groups.map(([t, a]) => `<div class="grp">${esc(t)}</div>` + a.map((i) =>
      `<button type="button" class="opt" data-id="${i.id}">${thumb(i, 36)}<span class="c">${esc(i.code)}</span><span>${esc(i.name)}</span>
        <span class="s">재고 ${fmt(stock[i.id].stock_qty)} ${esc(i.unit)}</span></button>`).join('')).join('') || '<p class="empty">검색 결과가 없습니다.</p>';
  };
  bg.innerHTML = `<div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(title)}">
    <header><button class="x" type="button" aria-label="닫기">×</button><strong>${esc(title)}</strong>
      <input class="input" type="search" placeholder="품목명 또는 코드 검색" style="margin-top:10px" autocomplete="off"></header>
    <div class="list">${render('')}</div></div>`;
  document.body.appendChild(bg);
  const close = () => bg.remove();
  const inp = $('input', bg);
  setTimeout(() => inp.focus(), 30);
  inp.addEventListener('input', () => { $('.list', bg).innerHTML = render(inp.value.trim()); });
  bg.addEventListener('click', (e) => {
    if (e.target === bg || e.target.closest('.x')) return close();
    const b = e.target.closest('.opt'); if (b) { close(); onPick(db.getItem(Number(b.dataset.id))); }
  });
  bg.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
}

function recentList(rows, kind) {
  if (!rows.length) return '<p class="empty">아직 기록이 없습니다.</p>';
  return `<ul class="recent">${rows.map((r) => {
    const t = kind === 'r'
      ? `${esc(r.item.name)} · ${fmt(r.qty)} ${esc(r.unit)}`
      : (r.summary ? `${r.kind ? '[' + esc(r.kind) + '] ' : ''}${esc(r.summary)}` : `${esc(r.item.name)} · ${fmt(r.output_qty)} ${esc(r.item.unit)}`);
    const m = kind === 'r'
      ? `${esc(r.received_on)}${r.lot?.expiry_date ? ' · 소비 ' + esc(r.lot.expiry_date) : ''} · ${esc(r.created_by)}`
      : `${esc(r.work_date)}${r.lot?.expiry_date ? ' · 소비 ' + esc(r.lot.expiry_date) : ''}${r.yield_pct != null ? ` · 수율 ${fmt(r.yield_pct, 1)}%` : ''} · ${esc(r.created_by)}`;
    return `<li class="${r.is_void ? 'void' : ''}"><div class="main"><div class="t">${t}</div><div class="m">${m}${r.is_void ? ` · 취소됨(${esc(r.void_reason)})` : ''}</div></div>
      ${r.can_void ? `<button type="button" class="btn small" data-void="${r.id}">취소</button>` : ''}</li>`;
  }).join('')}</ul>`;
}
function bindVoid(el, fn, rerender) {
  el.addEventListener('click', (e) => {
    const b = e.target.closest('[data-void]'); if (!b) return;
    const reason = prompt('취소 사유를 입력하세요 (필수)\n취소해도 기록은 남고, 재고는 반대 기록으로 되돌립니다.');
    if (reason == null) return;
    try { fn(Number(b.dataset.void), reason); rerender(); } catch (err) { alert(err.message); }
  });
}
const errorBox = (msg) => `<div class="error" role="alert">${ICON.critical.replace('class="ic"', 'class="ic" style="color:var(--critical);width:18px;height:18px"')}<div>${esc(msg)}</div></div>`;

// ------------------------------------------------------------ 입고 등록
function viewReceive(el) {
  const st = { cat: '원자재', item: null, unit: null, lotManual: false, result: null, error: null };
  const draw = guard(() => {
    const it = st.item;
    const units = it ? db.unitsOf(it.id) : [];
    const qty = Number($('#r-qty')?.value || 0);
    const date = $('#r-date')?.value || db.today();
    const dried = $('#r-dried')?.value || '';
    const stock = it ? db.itemStock().find((x) => x.id === it.id) : null;
    const partner = it ? db.primarySupplier(it.id) : null;
    const factor = it && st.unit !== it.unit ? db.unitFactor(it.id, st.unit) : 1;
    el.innerHTML = `<div class="narrow">
      <h1>입고 등록</h1><p class="sub">품목 · 수량 · 입고일만 넣으면 로트가 자동으로 붙습니다.</p>
      ${st.error ? errorBox(st.error) : ''}
      ${st.result ? resultReceipt(st.result) : ''}
      <form class="card" id="r-form" novalidate>
        <div class="field"><span class="label">구분</span>
          <div class="seg" role="group" aria-label="입고 구분" style="margin:0 0 8px">${Object.keys(RECEIVE_CATS).map((c) =>
            `<button type="button" data-cat="${c}" aria-pressed="${st.cat === c}">${c}</button>`).join('')}</div>
          <div class="help" style="margin:0 0 6px">${{ '원자재': '미역·다시마·자른미역·톳·멸치 / 참기름·간장·천일염', '부자재': '봉투·박스·카톤·포장지·라벨·테이프', 'OEM': '위탁 제조해 받아 오는 완제품 (하트미역·해초샐러드 등)' }[st.cat]}</div>
          <span class="label req">품목</span>
          <button type="button" class="picker-btn" id="r-pick">${it
            ? `${thumb(it, 44)}<span><span class="nm">${esc(it.name)}</span><br><span class="meta">${esc(it.code)} · ${esc(typeLabel(it))} · 현재고 ${fmt(stock.stock_qty)} ${esc(it.unit)}</span></span>`
            : '<span class="ph">품목 선택</span>'}<span class="chev">›</span></button></div>
        <div class="field"><label class="req" for="r-qty">수량</label>
          <div class="qty"><input class="input" id="r-qty" inputmode="decimal" type="number" min="0" step="any" placeholder="0" value="${qty || ''}" ${it ? '' : 'disabled'}></div>
          ${units.length > 1 ? `<div class="seg" role="group" aria-label="단위">${units.map((u) => `<button type="button" data-unit="${esc(u)}" aria-pressed="${u === st.unit}">${esc(u)}</button>`).join('')}</div>` : (it ? `<div class="help">단위: ${esc(it.unit)}</div>` : '')}
          ${it && factor !== 1 && qty > 0 ? `<div class="conv">= ${fmt(qty * factor)} ${esc(it.unit)} 로 재고에 들어갑니다</div>` : ''}
        </div>
        ${it && it.oem_type ? `<div class="field"><label class="req" for="r-exp">소비기한 (제품에 인자된 날짜)</label>
          <input class="input" type="date" id="r-exp" value="${esc($('#r-exp')?.value || '')}">
          <div class="help">클레임 추적에 쓰입니다. 받은 제품에 찍힌 날짜 그대로 입력하세요.</div></div>` : ''}
        ${it && it.item_type === 'RAW' ? `<div class="field"><label for="r-dried">원물 건조일</label>
          <input class="input" type="date" id="r-dried" value="${esc(dried)}">
          <div class="help">${dried ? `소비기한 <b>${esc(addMonths(dried, it.shelf_life_months || 36))}</b> 자동 계산 (건조일 + ${it.shelf_life_months || 36}개월)` : '소비기한은 포장일이 아니라 건조일부터 계산합니다.'}</div></div>` : ''}
        <div class="row2">
          <div class="field"><label class="req" for="r-date">입고일</label><input class="input" type="date" id="r-date" value="${esc(date)}"></div>
          <div class="field"><label for="r-lot">로트</label>
            ${st.lotManual ? `<input class="input" id="r-lot" placeholder="로트번호 입력" autocomplete="off">`
              : `<input class="input" id="r-lot" value="${it ? esc(db.nextLotPreview(it.id, date)) : '자동 발급'}" readonly aria-describedby="r-lot-h">`}
            <button type="button" class="btn link" id="r-lot-toggle">${st.lotManual ? '자동 발급으로' : '직접 입력'}</button></div>
        </div>
        <details class="more"><summary>거래처 · 메모 (선택)</summary><div>
          <div class="field"><label for="r-partner">거래처</label><select class="input" id="r-partner"><option value="">선택 안 함</option>
            ${db.listPartners().map((p) => `<option value="${p.id}" ${partner && partner.id === p.id ? 'selected' : ''}>${esc(p.name)}${p.needs_review ? ' (확인필요)' : ''}</option>`).join('')}</select></div>
          <div class="field"><label for="r-note">메모</label><textarea class="input" id="r-note"></textarea></div>
        </div></details>
        <button class="btn primary" type="submit" ${it ? '' : 'disabled'}>입고 저장</button>
      </form>
      <div class="card"><h2>최근 입고<span class="hint">당일 본인 기록은 취소 가능</span></h2><div id="r-recent">${recentList(db.receiptList(8), 'r')}</div></div>
    </div>`;
    el.querySelectorAll('[data-cat]').forEach((b) => b.onclick = () => { st.cat = b.dataset.cat; if (st.item && !RECEIVE_CATS[st.cat](st.item)) st.item = null; draw(); });
    $('#r-pick').onclick = () => pickItem({ title: `입고할 품목 · ${st.cat}`, filter: RECEIVE_CATS[st.cat], onPick: (p) => { st.item = p; st.unit = p.unit; st.result = null; st.error = null; draw(); $('#r-qty').focus(); } });
    el.querySelectorAll('[data-unit]').forEach((b) => b.onclick = () => { st.unit = b.dataset.unit; draw(); });
    $('#r-lot-toggle').onclick = () => { st.lotManual = !st.lotManual; draw(); };
    ['#r-qty', '#r-date', '#r-dried'].forEach((s) => { const x = $(s); if (x) x.onchange = () => draw(); });
    $('#r-form').onsubmit = (e) => {
      e.preventDefault();
      try {
        st.result = db.registerReceipt({ item_id: st.item.id, qty: Number($('#r-qty').value), unit: st.unit, received_on: $('#r-date').value,
          lot_no: st.lotManual ? $('#r-lot').value : null, partner_id: Number($('#r-partner').value) || null,
          dried_date: $('#r-dried')?.value || null, expiry_date: $('#r-exp')?.value || null, note: $('#r-note').value });
        st.result.item = st.item.name; st.error = null; st.item = null; st.lotManual = false;
      } catch (err) { st.error = err.message; }
      draw(); el.scrollIntoView({ block: 'start' });
    };
    bindVoid($('#r-recent'), db.voidReceipt, draw);
  });
  draw();
}
function resultReceipt(r) {
  return `<div class="card result ${r.warnings.length ? 'warn' : ''}" role="status">${status(r.warnings.length ? 'warning' : 'good', '입고 저장 완료')}
    <dl><dt>품목</dt><dd>${esc(r.item)}</dd><dt>재고 증가</dt><dd>+${fmt(r.base_qty)} ${esc(r.unit)}</dd>
      <dt>로트</dt><dd>${esc(r.lot_no)}</dd>${r.expiry_date ? `<dt>소비기한</dt><dd>${esc(r.expiry_date)}</dd>` : ''}<dt>번호</dt><dd>${esc(r.receipt_no)}</dd></dl>
    ${r.warnings.length ? `<ul class="warnings">${r.warnings.map((w) => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}</div>`;
}
function addMonths(s, m) { const d = new Date(s + 'T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + m); return d.toISOString().slice(0, 10); }

// ------------------------------------------------------------ 생산일지
function viewProduce(el) {
  const st = { mode: 'inner', result: null, error: null,
               // 내포장
               raw: null, rawLot: null, outs: {}, waste: '', reason: '',
               // 외포장
               item: null, qty: '', w: {} };
  const draw = guard(() => {
    el.innerHTML = `<div class="narrow">
      <h1>생산일지</h1>
      <div class="seg" role="group" aria-label="작업 구분" style="margin:0 0 12px">
        <button type="button" data-mode="inner" aria-pressed="${st.mode === 'inner'}">내포장 (원물 → 규격별)</button>
        <button type="button" data-mode="outer" aria-pressed="${st.mode === 'outer'}">외포장 (봉입·조립)</button></div>
      ${st.error ? errorBox(st.error) : ''}
      ${st.result ? (st.result.kind === 'inner' ? resultInner(st.result) : resultProduction(st.result)) : ''}
      ${st.mode === 'inner' ? innerForm() : outerForm()}
      <div class="card"><h2>최근 생산일지<span class="hint">당일 본인 기록은 취소 가능</span></h2><div id="p-recent">${recentList(db.productionList(8), 'p')}</div></div>
    </div>`;
    el.querySelectorAll('[data-mode]').forEach((x) => x.onclick = () => { st.mode = x.dataset.mode; st.result = null; st.error = null; draw(); });
    if (st.mode === 'inner') bindInner(); else bindOuter();
    bindVoid($('#p-recent'), db.voidProduction, draw);
  });

  // ---------- 내포장: 원물 1종(소비기한) → 여러 규격, 남은 조각은 원물 재고에 그대로
  const innerForm = () => {
    const raws = db.innerPackRaws();
    const raw = st.raw; const lots = raw ? db.rawLots(raw.id) : [];
    if (raw && !lots.some((x) => x.lot.id === st.rawLot)) st.rawLot = lots[0]?.lot.id || null;
    const targets = raw ? db.innerPackTargets(raw.id) : [];
    const outKg = targets.reduce((a, t) => a + (Number(st.outs[t.id]) || 0) * t.net_weight_g / 1000, 0);
    const waste = Number(st.waste) || 0; const useKg = outKg + waste;
    const lotBal = lots.find((x) => x.lot.id === st.rawLot)?.bal || 0;
    const totalBal = lots.reduce((a, x) => a + x.bal, 0);
    return `<form class="card" id="i-form" novalidate>
      <div class="field"><span class="label req">원물</span>
        <div class="seg" role="group" aria-label="원물">${raws.map((r) => `<button type="button" data-raw="${r.id}" aria-pressed="${raw && raw.id === r.id}">${esc(r.name.replace(/^자연건조/, '').replace(/\((.+)\)/, ' $1'))}</button>`).join('')}</div></div>
      ${raw ? `<div class="field"><span class="label req">원물 소비기한 <span class="hint" style="font-weight:400;color:var(--ink-3)">빠른 날짜가 먼저</span></span>
        ${lots.length ? `<div class="seg" role="group" aria-label="원물 소비기한">${lots.map((x) => `<button type="button" data-lot="${x.lot.id}" aria-pressed="${st.rawLot === x.lot.id}">
            ${esc(x.expiry || '소비기한 없음')} · ${fmt(x.bal)}kg</button>`).join('')}</div>
          <div class="help">${(() => { const x = lots.find((y) => y.lot.id === st.rawLot); return x ? `건조일 ${esc(x.dried || '-')} · 입고 ${esc(x.received_on || '-')} · ${esc(x.partner || '-')}` : ''; })()}</div>`
          : status('critical', '이 원물 재고가 없습니다. 입고부터 등록하세요.')}</div>
      <div class="field"><span class="label req">나온 개수 (규격별)</span>
        <ul class="inputs">${targets.map((t) => `<li style="grid-template-columns:1fr 110px;align-items:center"><span>${thumb(t, 32)} <span class="nm">${esc(t.spec || '')}</span> <span class="code">${esc(t.name)}</span></span>
          <input class="input" type="number" inputmode="numeric" min="0" data-out="${t.id}" value="${esc(st.outs[t.id] || '')}" placeholder="0" style="min-height:44px;text-align:right"></li>`).join('')}</ul></div>
      <div class="row2">
        <div class="field"><label for="i-waste">폐기 kg (선택)</label><input class="input" id="i-waste" type="number" inputmode="decimal" step="any" value="${esc(st.waste)}" placeholder="0"></div>
        <div class="field"><label for="i-reason">폐기 사유</label><select class="input" id="i-reason">${['', '파손', '이물 선별', '계량차', '불량', '기타'].map((r) => `<option ${st.reason === r ? 'selected' : ''} value="${r}">${r || '선택 안 함'}</option>`).join('')}</select></div>
      </div>
      <div class="yield-live">
        <div><div class="k">원물 사용</div><div class="v">${fmt(useKg)} kg</div></div>
        <div><div class="k">남는 원물</div><div class="v">${fmt(totalBal - useKg)} kg</div></div>
        <div><div class="k">수율</div><div class="v">${useKg > 0 ? fmt(outKg / useKg * 100, 1) + '%' : '-'}</div></div>
      </div>
      <div class="help">남은 조각(자투리)은 따로 입력하지 않아도 <b>같은 소비기한의 원물 재고</b>로 남습니다. 다음 20g 작업 때 그대로 쓰면 됩니다.
        ${useKg > lotBal && lotBal > 0 ? '<br>선택한 소비기한 원물이 모자라면 다음 소비기한 원물에서 이어서 씁니다(가장 빠른 소비기한으로 표시).' : ''}</div>` : ''}
      <button class="btn primary" type="submit" ${raw && outKg > 0 ? '' : 'disabled'}>내포장 저장</button>
    </form>`;
  };
  const bindInner = () => {
    el.querySelectorAll('[data-raw]').forEach((x) => x.onclick = () => { st.raw = db.getItem(Number(x.dataset.raw)); st.rawLot = null; st.outs = {}; st.result = null; draw(); });
    el.querySelectorAll('[data-lot]').forEach((x) => x.onclick = () => { st.rawLot = Number(x.dataset.lot); draw(); });
    el.querySelectorAll('[data-out]').forEach((x) => x.onchange = () => { st.outs[x.dataset.out] = x.value; draw(); });
    const w = $('#i-waste'); if (w) w.onchange = () => { st.waste = w.value; draw(); };
    const r = $('#i-reason'); if (r) r.onchange = () => { st.reason = r.value; };
    const f = $('#i-form'); if (!f) return;
    f.onsubmit = (e) => {
      e.preventDefault();
      el.querySelectorAll('[data-out]').forEach((x) => { st.outs[x.dataset.out] = x.value; });
      try {
        st.result = { kind: 'inner', ...db.registerInnerPack({ raw_item_id: st.raw.id, raw_lot_id: st.rawLot, waste_kg: Number(st.waste) || 0, waste_reason: st.reason || null,
          outputs: Object.entries(st.outs).map(([k, v]) => ({ item_id: Number(k), qty: Number(v) || 0 })) }) };
        st.error = null; st.outs = {}; st.waste = ''; st.reason = '';
      } catch (err) { st.error = err.message; }
      draw(); el.scrollIntoView({ block: 'start' });
    };
  };

  // ---------- 외포장: 봉입·세트 조립 → 쓸 반제품은 소비기한 빠른 것부터, 인자할 소비기한 표시
  const outerForm = () => {
    const p = st.item; const qty = Number(st.qty) || 0;
    const lines = p ? db.previewProduction(p.id, qty) : [];
    const anyShort = lines.some((l) => l.short);
    const exps = [...new Set(lines.flatMap((l) => l.alloc.map((a) => a.lot?.expiry_date)).filter(Boolean))].sort();
    return `<form class="card" id="p-form" novalidate>
      <div class="field"><span class="label req">만든 제품</span>
        <button type="button" class="picker-btn" id="p-pick">${p
          ? `${thumb(p, 44)}<span><span class="nm">${esc(p.name)}</span><br><span class="meta">${esc(p.code)} · ${esc(typeLabel(p))}</span></span>`
          : '<span class="ph">제품 선택 (IN BOX, 단품 라벨, 선물세트 …)</span>'}<span class="chev">›</span></button></div>
      <div class="field"><label class="req" for="p-qty">개수</label>
        <div class="qty"><button type="button" class="stepper" data-step="-1" aria-label="1 빼기" ${p ? '' : 'disabled'}>−</button>
          <input class="input" id="p-qty" inputmode="numeric" type="number" min="0" step="1" placeholder="0" value="${esc(st.qty)}" ${p ? '' : 'disabled'}>
          <button type="button" class="stepper" data-step="1" aria-label="1 더하기" ${p ? '' : 'disabled'}>＋</button></div></div>
      ${p ? `<div class="field"><span class="label">자동으로 쓰는 재료 ${anyShort ? status('critical', '재고 부족 있음') : ''}</span>
        ${lines.length ? `<ul class="inputs">${lines.map((l) => `<li><span class="nm">${esc(l.item.name)}</span>
          <span class="q">${qty ? fmt(l.need) : '-'} ${esc(l.item.unit)}</span>
          <span class="lots">${qty ? l.alloc.map((a) => a.lot ? `<span class="chip">${a.lot.expiry_date ? '소비 ' + esc(a.lot.expiry_date) : '재고'} · ${fmt(a.qty)}</span>`
            : `<span class="chip bad">${ICON.critical.replace('class="ic"', 'class="ic" style="width:11px;height:11px;color:var(--critical);vertical-align:-1px"')} 부족 ${fmt(a.qty)}</span>`).join('')
            : `<span class="chip">현재고 ${fmt(l.stock)}</span>`}</span></li>`).join('')}</ul>`
          : '<p class="empty">이 제품은 구성(BOM)이 아직 없습니다.</p>'}
        ${qty && exps.length ? `<div class="print-exp">인자할 소비기한 <b>${esc(exps[0])}</b>${exps.length > 1 ? `<br><small>소비기한 ${exps.length}종이 섞여 가장 빠른 날짜로 인자</small>` : ''}</div>` : ''}
        <div class="help">반제품은 소비기한이 빠른 것부터 씁니다. 오늘 내포장한 것 중 일부만 봉입해도 나머지는 같은 소비기한으로 재고에 남습니다.</div></div>` : ''}
      <button class="btn primary" type="submit" ${p && qty > 0 ? '' : 'disabled'}>외포장 저장</button>
    </form>`;
  };
  const bindOuter = () => {
    $('#p-pick').onclick = () => pickItem({ title: '외포장한 제품', filter: (i) => ['SEMI', 'FG'].includes(i.item_type) && i.oem_type !== 'OEM매입' && !db.isInnerPackProduct(i.id),
      onPick: (x) => { st.item = x; st.qty = ''; st.result = null; st.error = null; draw(); $('#p-qty').focus(); } });
    const qi = $('#p-qty');
    qi.oninput = () => { st.qty = qi.value; draw(); $('#p-qty').focus(); };
    el.querySelectorAll('[data-step]').forEach((b) => b.onclick = () => { st.qty = String(Math.max(0, (Number(st.qty) || 0) + Number(b.dataset.step))); draw(); });
    $('#p-form').onsubmit = (e) => {
      e.preventDefault();
      try {
        st.result = db.registerProduction({ product_id: st.item.id, output_qty: Number(st.qty) });
        st.result.item = st.item.name; st.result.qty = st.qty; st.result.unit = st.item.unit; st.result.img = st.item.img;
        st.error = null; st.item = null; st.qty = '';
      } catch (err) { st.error = err.message; }
      draw(); el.scrollIntoView({ block: 'start' });
    };
  };
  draw();
}
function resultInner(r) {
  return `<div class="card result ${r.warnings.length ? 'warn' : ''}" role="status">${status(r.warnings.length ? 'warning' : 'good', '내포장 저장 완료')}
    <dl><dt>원물</dt><dd>${esc(r.raw)} ${fmt(r.use_kg)}kg 사용 (폐기 ${fmt(r.waste_kg)}kg)</dd>
      <dt>나온 것</dt><dd>${r.outputs.map((o) => `${esc(o.item)} ${fmt(o.qty)}${esc(o.unit)}`).join(', ')}</dd>
      <dt>소비기한</dt><dd>${esc(r.expiry || '-')} (건조일 ${esc(r.dried || '-')}) — 모든 규격 동일</dd>
      <dt>수율</dt><dd>${r.yield_pct != null ? fmt(r.yield_pct, 1) + '%' : '-'} · 남은 원물 ${fmt(r.raw_left)}kg</dd><dt>번호</dt><dd>${esc(r.log_no)}</dd></dl>
    ${r.warnings.length ? `<ul class="warnings">${r.warnings.map((w) => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}</div>`;
}
function resultProduction(r) {
  return `<div class="card result ${r.warnings.length ? 'warn' : ''}" role="status">${r.img ? `<img class="result-img" src="img/products/${esc(r.img)}.jpg" alt="${esc(r.item)}">` : ''}${status(r.warnings.length ? 'warning' : 'good', '외포장 저장 완료')}
    ${r.expiry_date ? `<div class="print-exp">인자할 소비기한 <b>${esc(r.expiry_date)}</b></div>` : ''}
    <dl><dt>제품</dt><dd>${esc(r.item)} ${fmt(r.qty)} ${esc(r.unit)}</dd>
      <dt>쓴 재료</dt><dd>${r.inputs.map((i) => `${esc(i.item)} ${fmt(i.qty)}${esc(i.unit)}`).join(', ') || '-'}</dd><dt>번호</dt><dd>${esc(r.log_no)}</dd></dl>
    ${r.warnings.length ? `<ul class="warnings">${r.warnings.map((w) => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}</div>`;
}

// ------------------------------------------------------------ 대표 현황
function viewDashboard(el) {
  const st = { type: 'ALL', q: '' };
  const month = db.today().slice(0, 7);
  const draw = guard(() => {
    const stock = db.itemStock();
    const short = stock.filter((i) => i.below_safety).sort((a, b) => (a.stock_qty / a.safety_stock) - (b.stock_qty / b.safety_stock));
    const ys = db.monthlyYield(month).sort((a, b) => a.item.code.localeCompare(b.item.code));
    const withY = ys.filter((r) => r.yield_pct != null);
    const inSum = withY.reduce((a, r) => a + r.input_kg, 0), outSum = withY.reduce((a, r) => a + r.output_kg, 0);
    const avgY = inSum > 0 ? outSum / inSum * 100 : null;
    const runs = ys.reduce((a, r) => a + r.runs, 0);
    const lots = db.lotStock().filter((l) => l.stock_qty > 0 && l.expiry_date);
    const soon = lots.filter((l) => (new Date(l.expiry_date) - new Date(db.today())) / 864e5 <= 365);
    const rows = stock.filter((i) => (st.type === 'ALL' || (st.type === 'OEM' ? !!i.oem_type : i.item_type === st.type && !i.oem_type)) && (!st.q || (i.name + i.code).toLowerCase().includes(st.q.toLowerCase())));
    const lo = 80, hi = 100; const xp = (v) => Math.max(0, Math.min(100, (v - lo) / (hi - lo) * 100));

    el.innerHTML = `
      <h1>대표 현황</h1><p class="sub">${month.replace('-', '년 ')}월 기준 · 재고는 입고·생산·출고 기록을 합산한 값입니다.</p>
      <div class="tiles">
        <div class="tile"><div class="k">안전재고 미달</div><div class="v">${short.length}<small>품목</small></div><div class="d">${short.length ? status('critical', '보충 필요') : status('good', '모두 충분')}</div></div>
        <div class="tile"><div class="k">이번 달 생산</div><div class="v">${runs}<small>건</small></div><div class="d">${ys.length}개 제품</div></div>
        <div class="tile"><div class="k">이번 달 수율 (중량 기준)</div><div class="v">${avgY ? fmt(avgY, 1) : '-'}<small>%</small></div><div class="d">투입 ${fmt(inSum, 1)}kg → 산출 ${fmt(outSum, 1)}kg</div></div>
        <div class="tile"><div class="k">소비기한 1년 이내 로트</div><div class="v">${soon.length}<small>건</small></div><div class="d">재고 있는 로트 ${lots.length}건 중</div></div>
      </div>
      <div class="grid2">
        <section class="card" aria-labelledby="h-short"><h2 id="h-short">안전재고 미달 목록<span class="hint">부족 비율 큰 순</span></h2>
          ${short.length ? `<ul class="short-list">${short.map((i) => `<li><div class="top-row"><span class="nm">${esc(i.name)}</span>
              <span class="nums">${fmt(i.stock_qty)} / ${fmt(i.safety_stock)} ${esc(i.unit)}</span></div>
              <div class="meter" role="img" aria-label="안전재고 대비 ${Math.round(Math.max(0, i.stock_qty) / i.safety_stock * 100)}%"><span style="width:${Math.max(0, Math.min(100, i.stock_qty / i.safety_stock * 100))}%"></span></div>
              <div class="help">${status('critical', `${fmt(i.shortage_qty)} ${i.unit} 부족`)} · <span class="code">${esc(i.code)} · ${esc(typeLabel(i))}</span></div></li>`).join('')}</ul>`
            : '<p class="empty">안전재고보다 적은 품목이 없습니다.</p>'}
          <p class="note">막대 = 현재고 ÷ 안전재고. 안전재고 값은 시안용 예시입니다.</p>
        </section>
        <section class="card" aria-labelledby="h-yield"><h2 id="h-yield">이번 달 제품별 수율<span class="hint">산출 kg ÷ 투입 kg</span></h2>
          ${withY.length ? `<div class="legend"><span><i class="ldot"></i>이번 달 수율</span><span><i class="lstd"></i>표준 수율(1회 실측 임시값)</span></div>
            <div class="yplot" id="yplot">${withY.map((r, i) => `<div class="yrow" data-i="${i}" tabindex="0">
              <span class="nm" title="${esc(r.item.name)}">${esc(r.item.name)}</span>
              <span class="track">${r.std_yield != null ? `<span class="std" style="left:${xp(r.std_yield)}%"></span>` : ''}<span class="dot" style="left:${xp(r.yield_pct)}%"></span></span>
              <span class="val"><b>${fmt(r.yield_pct, 1)}%</b><span class="gap">${r.std_yield != null ? `표준 대비 ${r.yield_pct - r.std_yield >= 0 ? '+' : ''}${fmt(r.yield_pct - r.std_yield, 1)}%p` : '표준 없음'}</span></span></div>`).join('')}
              <div class="yaxis" aria-hidden="true"><span></span><span class="ticks">${[80, 85, 90, 95, 100].map((t) => `<span style="left:${xp(t)}%">${t}%</span>`).join('')}</span><span></span></div>
            </div>` : '<p class="empty">이번 달 중량을 입력한 생산일지가 없습니다.</p>'}
          <div class="table-wrap" style="margin-top:12px"><table><caption class="sr">이번 달 제품별 생산 실적</caption>
            <thead><tr><th>제품</th><th class="num">건수</th><th class="num">산출</th><th class="num">투입kg</th><th class="num">손실kg</th><th class="num">자투리kg</th><th class="num">초/개</th></tr></thead>
            <tbody>${ys.map((r) => `<tr><td>${esc(r.item.name)}</td><td class="num">${r.runs}</td><td class="num">${fmt(r.output_qty)}</td><td class="num">${r.input_kg ? fmt(r.input_kg) : '-'}</td>
              <td class="num">${r.input_kg ? fmt(r.loss_kg) : '-'}</td><td class="num">${r.input_kg ? fmt(r.scrap_kg) : '-'}</td><td class="num">${r.sec_per_ea ?? '-'}</td></tr>`).join('') || '<tr><td colspan="7" class="empty">기록 없음</td></tr>'}</tbody></table></div>
        </section>
      </div>
      <section class="card" aria-labelledby="h-stock"><h2 id="h-stock">품목별 현재고</h2>
        <div class="filters"><div class="seg" role="group" aria-label="분류" style="margin:0">${['ALL', 'RAW', 'SUB', 'PACK', 'SEMI', 'FG', 'OEM'].map((t) =>
          `<button type="button" data-type="${t}" aria-pressed="${st.type === t}">${t === 'ALL' ? '전체' : t === 'OEM' ? 'OEM' : TYPE[t]}</button>`).join('')}</div>
          <input class="input" type="search" id="s-q" placeholder="품목 검색" value="${esc(st.q)}"></div>
        <div class="table-wrap"><table><thead><tr><th>품목</th><th>분류</th><th class="num">현재고</th><th class="num">안전재고</th><th>상태</th></tr></thead>
          <tbody>${rows.map((i) => `<tr><td><span class="namecell">${thumb(i, 32)}<span>${esc(i.name)}<br><span class="code">${esc(i.code)}</span></span></span></td><td>${esc(typeLabel(i))}</td>
            <td class="num">${fmt(i.stock_qty)} ${esc(i.unit)}</td><td class="num">${i.safety_stock ? fmt(i.safety_stock) : '-'}</td>
            <td>${i.below_safety ? status('critical', '미달') : status('good', '충분')}</td></tr>`).join('') || '<tr><td colspan="5" class="empty">해당 품목이 없습니다.</td></tr>'}</tbody></table></div>
      </section>`;

    el.querySelectorAll('[data-type]').forEach((b) => b.onclick = () => { st.type = b.dataset.type; draw(); });
    const q = $('#s-q'); q.oninput = () => { st.q = q.value; draw(); const n = $('#s-q'); n.focus(); n.setSelectionRange(n.value.length, n.value.length); };
    const tip = $('#tip');
    const show = (row, x, y) => {
      const r = withY[Number(row.dataset.i)];
      tip.innerHTML = `<b>${esc(r.item.name)}</b><br>수율 ${fmt(r.yield_pct, 1)}%${r.std_yield != null ? ` · 표준 ${r.std_yield}%` : ''}<br>
        투입 ${fmt(r.input_kg)}kg → 산출 ${fmt(r.output_kg)}kg<br>손실 ${fmt(r.loss_kg)}kg · 자투리 ${fmt(r.scrap_kg)}kg<br>${r.runs}건 · ${fmt(r.output_qty)}${esc(r.item.unit)}`;
      tip.hidden = false;
      const w = tip.offsetWidth, h = tip.offsetHeight;
      tip.style.left = Math.min(window.innerWidth - w - 8, x + 12) + 'px'; tip.style.top = Math.max(8, y - h - 12) + 'px';
    };
    el.querySelectorAll('.yrow').forEach((row) => {
      row.addEventListener('mousemove', (e) => show(row, e.clientX, e.clientY));
      row.addEventListener('mouseleave', () => { tip.hidden = true; });
      row.addEventListener('focus', () => { const b = row.getBoundingClientRect(); show(row, b.left + b.width / 2, b.top); });
      row.addEventListener('blur', () => { tip.hidden = true; });
      row.addEventListener('click', () => { const b = row.getBoundingClientRect(); show(row, b.left + b.width / 2, b.top); });
    });
  });
  draw();
}

// ------------------------------------------------------------ 판매 (기업 / 개인 / 기타주문 / OEM납품)
const CH = ['기업', '개인', '기타주문', 'OEM납품'];
const CH_HELP = { '기업': '묶음 납품 (컬리·아난티·호텔 등)', '개인': '사이트·기관별 개인고객 개별 배송 (선관위 등)',
                  '기타주문': '전화 및 기타 주문 — 개인·기업이 섞여 별도 관리', 'OEM납품': '고객사 전용품 납품 (와이즐리 PB 등)' };
function viewSales(el) {
  const st = { ch: '' };
  const month = db.today().slice(0, 7);
  const draw = guard(() => {
    const owner = db.user().role === 'owner';
    const sum = db.salesSummary(month);
    const list = db.salesList(st.ch || null);
    el.innerHTML = `
      <h1>판매</h1><p class="sub">${month.replace('-', '년 ')}월 · 구분별 주문. ${owner ? '대표 화면: 받는 사람 정보를 모두 봅니다.' : '직원 화면: 받는 사람 이름·연락처·주소 일부가 가려집니다.'}</p>
      <div class="tiles">${CH.map((c) => { const r = sum[c] || { orders: 0, qty: 0, amount: 0, noAmount: 0 };
        return `<div class="tile"><div class="k">${c}</div><div class="v">${r.orders}<small>건</small></div>
          <div class="d">${r.amount ? fmt(r.amount, 0) + '원' : '금액 없음'}${r.noAmount ? ` · 금액 미입력 ${r.noAmount}줄` : ''}</div></div>`; }).join('')}</div>
      <section class="card">
        <div class="filters"><div class="seg" role="group" aria-label="판매 구분" style="margin:0">${['', ...CH].map((c) =>
          `<button type="button" data-ch="${c}" aria-pressed="${st.ch === c}">${c || '전체'}</button>`).join('')}</div></div>
        ${st.ch ? `<p class="help" style="margin-top:0">${CH_HELP[st.ch]}</p>` : ''}
        ${list.length ? `<ul class="recent">${list.map((o) => `<li><div class="main">
            <div class="t">${esc(o.channel)} · ${o.lines.map((l) => `${esc(l.item?.name || l.item_text)} ${fmt(l.qty)}`).join(', ')}</div>
            <div class="m">${esc(o.order_no)} · 출고 ${esc(o.ship_date || '-')} · <b>${esc(o.channel_type)}</b>${o.destination ? ` · ${esc(o.destination)}` : ''}${o.delivery_method ? ` · ${esc(o.delivery_method)}` : ''}</div>
            ${o.recipient_name || o.phone || o.address ? `<div class="m">받는 사람: ${esc(o.recipient_name || '-')}${o.phone ? ` · ${esc(o.phone)}` : ''}${o.address ? ` · ${esc(o.address)}` : ''}</div>` : ''}
          </div><div class="q" style="text-align:right;white-space:nowrap;font-weight:700">${o.amount != null ? fmt(o.amount, 0) + '원' : '<span class="m">금액 없음</span>'}</div></li>`).join('')}</ul>`
          : '<p class="empty">주문이 없습니다.</p>'}
        <p class="note">시안: 판매 입력 화면은 장부 가져오기 방식이 정해진 뒤 만듭니다. 받는 사람은 가상의 예시입니다.</p>
      </section>`;
    el.querySelectorAll('[data-ch]').forEach((b) => b.onclick = () => { st.ch = b.dataset.ch; draw(); });
  });
  draw();
}

// ------------------------------------------------------------ 클레임 추적 (제품 + 소비기한)
function viewTrace(el) {
  const st = { item: null, exp: '' };
  const draw = guard(() => {
    const it = st.item; const exps = it ? db.expiryDatesOf(it.id) : [];
    if (it && !exps.includes(st.exp)) st.exp = exps[0] || '';
    const t = it && st.exp ? db.traceByExpiry(it.id, st.exp) : null;
    const owner = db.user().role === 'owner';
    const direct = t ? t.ships.filter((x) => x.direct) : []; const related = t ? t.ships.filter((x) => !x.direct) : [];
    el.innerHTML = `<div class="narrow">
      <h1>클레임 추적</h1><p class="sub">제품과 포장에 찍힌 소비기한만 고르면 원물 → 작업 → 출고가 한 번에 나옵니다.</p>
      <div class="card">
        <div class="field"><span class="label req">클레임 제품</span>
          <button type="button" class="picker-btn" id="t-pick">${it ? `${thumb(it, 44)}<span><span class="nm">${esc(it.name)}</span><br><span class="meta">${esc(it.code)} · ${esc(typeLabel(it))}</span></span>`
            : '<span class="ph">제품 선택</span>'}<span class="chev">›</span></button></div>
        ${it ? `<div class="field"><span class="label req">포장에 찍힌 소비기한</span>
          ${exps.length ? `<div class="seg" role="group" aria-label="소비기한">${exps.map((e) => `<button type="button" data-exp="${esc(e)}" aria-pressed="${st.exp === e}">${esc(e)}</button>`).join('')}</div>`
            : '<p class="empty">이 제품은 소비기한이 기록된 생산·입고가 없습니다.</p>'}</div>` : ''}
      </div>
      ${t ? `
      <section class="card"><h2>① 원물 (어디서 온 원료인가)</h2>
        ${t.raw.length ? `<ul class="recent">${t.raw.map((r) => `<li><div class="main"><div class="t">${esc(r.item.name)}${r.oem ? ' · OEM 입고' : ''}</div>
          <div class="m">${r.dried ? `건조일 ${esc(r.dried)} · ` : ''}소비기한 ${esc(r.expiry || '-')} · 입고 ${esc(r.received_on || '-')} · ${fmt(r.qty)}${esc(r.item.unit)}</div>
          <div class="m">공급처: <b>${esc(r.partner)}</b></div></div></li>`).join('')}</ul>` : '<p class="empty">연결된 원물 입고 기록이 없습니다(기초재고 등).</p>'}</section>
      <section class="card"><h2>② 작업 (언제·누가 만들었나)</h2>
        <ul class="recent">${t.works.filter((w) => w.on_path).map((w) => `<li><div class="main"><div class="t">[${esc(w.kind)}] ${esc(w.what)}</div>
          <div class="m">${esc(w.date)} · 작업자 ${esc(w.worker)}${w.waste ? ` · 폐기 ${fmt(w.waste)}kg${w.reason ? '(' + esc(w.reason) + ')' : ''}` : ''} · ${esc(w.log_no)}</div></div></li>`).join('') || '<p class="empty">작업 기록 없음</p>'}</ul>
        ${t.works.some((w) => !w.on_path) ? `<details class="more"><summary>같은 원물로 한 다른 작업 ${t.works.filter((w) => !w.on_path).length}건</summary><div><ul class="recent">${t.works.filter((w) => !w.on_path).map((w) =>
          `<li><div class="main"><div class="t">[${esc(w.kind)}] ${esc(w.what)}</div><div class="m">${esc(w.date)} · ${esc(w.worker)}</div></div></li>`).join('')}</ul></div></details>` : ''}
        <p class="note">같은 소비기한으로 여러 날 작업했다면 후보 작업이 모두 표시됩니다.</p></section>
      <section class="card"><h2>③ 출고 (같은 제품·같은 소비기한이 간 곳)</h2>
        ${direct.length ? `<ul class="recent">${direct.map((s) => `<li><div class="main"><div class="t">${esc(s.channel)}</div>
          <div class="m">${esc(s.date)} · ${esc(s.item)} ${fmt(s.qty)}개${s.recipient ? ` · 받는 사람 ${esc(s.recipient)}` : ''}${s.order_no ? ' · ' + esc(s.order_no) : ''}</div></div></li>`).join('')}</ul>`
          : '<p class="empty">아직 출고되지 않았습니다.</p>'}
        ${!owner ? '<p class="note">직원 화면: 받는 사람 이름 일부가 가려집니다.</p>' : ''}</section>
      <section class="card"><h2>④ 회수 범위 (같은 원물로 만든 제품)</h2>
        <div class="tiles" style="margin-bottom:8px">
          <div class="tile"><div class="k">남은 재고</div><div class="v">${fmt(t.stockNow.reduce((a, x) => a + x.bal, 0))}<small>개</small></div><div class="d">${t.stockNow.length}개 품목·소비기한</div></div>
          <div class="tile"><div class="k">다른 출고</div><div class="v">${related.length}<small>건</small></div><div class="d">같은 원물 · 다른 제품</div></div></div>
        ${t.stockNow.length ? `<ul class="recent">${t.stockNow.map((x) => `<li><div class="main"><div class="t">${esc(x.item.name)}</div><div class="m">소비기한 ${esc(x.expiry || '-')} · 재고 ${fmt(x.bal)}</div></div></li>`).join('')}</ul>` : ''}
        ${related.length ? `<details class="more"><summary>다른 출고 ${related.length}건 보기</summary><div><ul class="recent">${related.map((s) => `<li><div class="main"><div class="t">${esc(s.channel)}</div>
          <div class="m">${esc(s.date)} · ${esc(s.item)} ${fmt(s.qty)} · 소비 ${esc(s.expiry || '-')}${s.recipient ? ' · ' + esc(s.recipient) : ''}</div></div></li>`).join('')}</ul></div></details>` : ''}
      </section>` : ''}
    </div>`;
    $('#t-pick').onclick = () => pickItem({ title: '클레임 제품', filter: (i) => ['SEMI', 'FG'].includes(i.item_type), onPick: (x) => { st.item = x; st.exp = ''; draw(); } });
    el.querySelectorAll('[data-exp]').forEach((x) => x.onclick = () => { st.exp = x.dataset.exp; draw(); });
  });
  draw();
}

// ------------------------------------------------------------ 라우팅
const ROUTES = { receive: viewReceive, produce: viewProduce, sales: viewSales, trace: viewTrace, dashboard: viewDashboard };
function route() {
  const name = (location.hash || '#receive').slice(1);
  const view = ROUTES[name] || viewReceive;
  document.querySelectorAll('.tabs a, .bottom-nav a').forEach((a) => a.setAttribute('aria-current', a.getAttribute('href') === '#' + name ? 'page' : 'false'));
  $('#tip').hidden = true;
  const app = $('#app'); view(app);
  app.insertAdjacentHTML('beforeend', `<p class="foot">시안 화면입니다. 입력한 내용은 이 브라우저에만 저장됩니다. ·
    <button type="button" class="btn link" id="reset">예시 데이터로 초기화</button></p>`);
  $('#reset').onclick = () => { if (confirm('입력한 내용을 지우고 예시 데이터로 되돌릴까요?')) { db.reset(); route(); } };
}
document.querySelectorAll('.who button').forEach((b) => b.addEventListener('click', () => {
  db.setUser(b.dataset.role);
  document.querySelectorAll('.who button').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
  route();
}));
window.addEventListener('hashchange', route);
route();
