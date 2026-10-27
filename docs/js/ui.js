// 画面の部品：シート・確認・お知らせ・結果の大きな表示・読み上げ
import { NAME } from './model.js';

export const esc = s => String(s ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
export const fmt = n => Number(n || 0).toLocaleString('ja-JP');
export const signed = n => (n > 0 ? '+' : n < 0 ? '−' : '±') + fmt(Math.abs(n));

/** 保存（ブラウザの中だけ）。読めないときは既定の値。 */
export const store = {
  get(key, fallback) {
    try { const v = localStorage.getItem(key); return v == null ? fallback : JSON.parse(v); } catch { return fallback; }
  },
  set(key, value) {
    try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* 保存できない環境ではその場だけ */ }
  },
};

// ---- アイコン（SF Symbols の代わりの小さな SVG） ----
const PATHS = {
  history: 'M12 8v4l3 2M3.05 11a9 9 0 1 1 .5 4M3 4v5h5',
  book: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20V3H6.5A2.5 2.5 0 0 0 4 5.5zM4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5',
  sliders: 'M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0M14 4v4M8 10v4M16 16v4',
  plus: 'M12 5v14M5 12h14',
  gift: 'M20 12v9H4v-9M2 7h20v5H2zM12 22V7M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7zM12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z',
  undo: 'M9 14 4 9l5-5M4 9h11a5 5 0 0 1 0 10h-1',
  close: 'M18 6 6 18M6 6l12 12',
  swap: 'M7 16V4M3 8l4-4 4 4M17 8v12M21 16l-4 4-4-4',
  users: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  table: 'M3 3h18v18H3zM3 9h18M9 21V9',
  grid: 'M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z',
  door: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
  check: 'M20 6 9 17l-5-5',
  chevron: 'm6 9 6 6 6-6',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
};
export const icon = (name, size = 18) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${PATHS[name] || ''}"/></svg>`;

/** ツールバーのボタン（アイコンと文字） */
export const tbtn = (action, iconName, label, extra = '') =>
  `<button class="tbtn" data-action="${action}" ${extra}>${icon(iconName, 17)}<span>${esc(label)}</span></button>`;

// ---- シート（下から出る／横向きでは真ん中） ----
const layer = () => document.getElementById('layer');

/**
 * シートを開く。render(close) は中身の HTML を返す。bind(el, close) で中のボタンをつなぐ。
 * 戻り値の close で閉じる。update() で中身を描き直す。
 */
export function openSheet({ title, render, bind, wide = false, onClose }) {
  const wrap = document.createElement('div');
  wrap.className = 'sheet-backdrop';
  wrap.innerHTML = `<div class="sheet-panel${wide ? ' wide' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}">
    <header class="sheet-head"><h2>${esc(title)}</h2><button class="sheet-close" data-close aria-label="閉じる">閉じる</button></header>
    <div class="sheet-body"></div></div>`;
  const body = wrap.querySelector('.sheet-body');
  let closed = false;
  const close = () => {
    if (closed) return;
    closed = true;
    wrap.classList.add('leaving');
    setTimeout(() => wrap.remove(), 160);
    onClose?.();
  };
  const update = () => {
    if (closed) return;
    const top = body.scrollTop;
    body.innerHTML = render(close);
    bind?.(body, close, update);
    body.scrollTop = top;
  };
  wrap.addEventListener('click', e => {
    if (e.target === wrap || e.target.closest('[data-close]')) close();
  });
  layer().appendChild(wrap);
  update();
  return { close, update, get closed() { return closed; }, el: body };
}

/** はい・いいえの確認。buttons: [{label, role:'destructive'|'cancel'|undefined, run}] */
export function confirmBox({ title, message = '', buttons }) {
  const wrap = document.createElement('div');
  wrap.className = 'alert-backdrop';
  wrap.innerHTML = `<div class="alert" role="alertdialog" aria-label="${esc(title)}">
    <h3>${esc(title)}</h3>${message ? `<p>${esc(message)}</p>` : ''}
    <div class="alert-buttons">${buttons.map((b, i) =>
      `<button data-i="${i}" class="${b.role || ''}">${esc(b.label)}</button>`).join('')}</div></div>`;
  wrap.addEventListener('click', e => {
    const btn = e.target.closest('button[data-i]');
    if (!btn && e.target !== wrap) return;
    wrap.remove();
    if (btn) buttons[Number(btn.dataset.i)].run?.();
  });
  layer().appendChild(wrap);
}

/** 1行のお知らせ（少しで消える） */
export function toast(message) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = message;
  layer().appendChild(el);
  setTimeout(() => el.classList.add('leaving'), 2600);
  setTimeout(() => el.remove(), 3000);
}

/** メニュー（「表示」など）。items: [{label, checked?, run}] または {heading} */
export function openMenu(anchor, items) {
  const wrap = document.createElement('div');
  wrap.className = 'menu-backdrop';
  const r = anchor.getBoundingClientRect();
  wrap.innerHTML = `<div class="menu" style="top:${Math.round(r.bottom + 6)}px;right:${Math.max(8, Math.round(innerWidth - r.right))}px">
    ${items.map((it, i) => it.heading
      ? `<div class="menu-heading">${esc(it.heading)}</div>`
      : `<button data-i="${i}" role="menuitemcheckbox" aria-checked="${!!it.checked}"><span class="menu-check">${it.checked ? icon('check', 16) : ''}</span>${esc(it.label)}</button>`).join('')}
  </div>`;
  wrap.addEventListener('click', e => {
    const btn = e.target.closest('button[data-i]');
    wrap.remove();
    if (btn) items[Number(btn.dataset.i)].run?.();
  });
  layer().appendChild(wrap);
}

// ---- 結果の大きな表示と読み上げ（Views/ResultSplash.swift） ----
let splashTimer;
export function splash({ hand, handNumber, net, banner }) {
  document.querySelector('.splash')?.remove();
  clearTimeout(splashTimer);
  const el = document.createElement('div');
  const kind = banner ? 'closed' : hand.o;
  el.className = `splash ${kind}`;
  const pairs = hand ? [hand.bp && 'B PAIR', hand.pp && 'P PAIR'].filter(Boolean) : [];
  el.innerHTML = banner
    ? `<div class="splash-title">${esc(banner)}</div>`
    : `${handNumber ? `<div class="splash-no">第${handNumber}手</div>` : ''}
       <div class="splash-title">${NAME[hand.o]}</div>
       ${pairs.length ? `<div class="splash-pairs">${pairs.join('  ·  ')}</div>` : ''}
       ${net != null ? `<div class="splash-net">${net === 0 ? '±0' : signed(net)} pt</div>` : ''}`;
  el.setAttribute('role', 'status');
  el.addEventListener('click', () => el.remove());
  layer().appendChild(el);
  splashTimer = setTimeout(() => { el.classList.add('leaving'); setTimeout(() => el.remove(), 300); }, 2500);
}

export function speak(phrase) {
  try {
    if (!('speechSynthesis' in window)) return;
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(phrase);
    u.lang = 'en-US';
    const voice = speechSynthesis.getVoices().find(v => v.lang === 'en-US');
    if (voice) u.voice = voice;
    speechSynthesis.speak(u);
  } catch { /* 読み上げできない環境では何もしない */ }
}

export function handPhrase(hand) {
  let p = { B: 'Banker', P: 'Player', T: 'Tie' }[hand.o];
  if (hand.bp && hand.pp) p += ', banker pair and player pair';
  else if (hand.bp) p += ', banker pair';
  else if (hand.pp) p += ', player pair';
  return p;
}

export function buzz() {
  try { navigator.vibrate?.(8); } catch { /* なくてもよい */ }
}
