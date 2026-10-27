// 罫線の描画（アプリの Views/RoadViews.swift と同じ描き方）。canvas に描く。
import { ROWS, BEAD, bigRoad, place, columns, derived } from './model.js';

const css = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
export const colors = () => ({
  B: css('--banker'), P: css('--player'), T: css('--tie'),
  R: css('--banker'), U: css('--player'),
  line: css('--line'), sheet: css('--sheet'),
});

function ring(ctx, x, y, r, color, w) {
  ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, Math.PI * 2);
  ctx.strokeStyle = color; ctx.lineWidth = w; ctx.stroke();
}
function dot(ctx, x, y, r, color) {
  ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, Math.PI * 2);
  ctx.fillStyle = color; ctx.fill();
}
function slash(ctx, x, y, r, color, w) {
  ctx.beginPath(); ctx.moveTo(x - r, y + r); ctx.lineTo(x + r, y - r);
  ctx.strokeStyle = color; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.stroke();
}
function text(ctx, s, x, y, size, color) {
  ctx.fillStyle = color; ctx.font = `700 ${size}px ${css('--font-ui') || 'sans-serif'}`;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(s, x, y + size * 0.04);
}

/** 下三路の印。大眼仔は白抜きの丸、小路は塗りの丸、曱甴路は斜線 */
export function drawMark(ctx, x, y, cell, k, mark, c) {
  const color = c[mark];
  if (k === 1) ring(ctx, x, y, cell / 2 - 2.2, color, Math.max(1.6, cell / 8));
  else if (k === 2) dot(ctx, x, y, cell / 2 - 2.2, color);
  else slash(ctx, x, y, cell / 2 - 2.6, color, Math.max(1.8, cell / 7));
}

/** 問路や凡例の小さな印（data URL の画像にする） */
export function markIcon(k, mark, size = 16) {
  const dpr = window.devicePixelRatio || 1;
  const cv = document.createElement('canvas');
  cv.width = cv.height = size * dpr;
  const ctx = cv.getContext('2d'); ctx.scale(dpr, dpr);
  drawMark(ctx, size / 2, size / 2, size, k, mark, colors());
  return `<img src="${cv.toDataURL()}" width="${size}" height="${size}" alt="${['', '大眼仔', '小路', '曱甴路'][k]} ${mark === 'R' ? '赤' : '青'}">`;
}

/**
 * 6段の方眼を描く。scroller（横スクロールする箱）の中の canvas に描き、
 * 列が画面に収まらないときは右端（新しい列）まで送る。
 */
function grid(scroller, cell, used, paint) {
  const width = scroller.clientWidth || 300;
  const cols = Math.max(used + 3, Math.ceil(width / cell));
  const w = cols * cell, h = ROWS * cell;
  let cv = scroller.querySelector('canvas');
  if (!cv) { cv = document.createElement('canvas'); scroller.appendChild(cv); }
  const dpr = window.devicePixelRatio || 1;
  cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr);
  cv.style.width = `${w}px`; cv.style.height = `${h}px`;
  const ctx = cv.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  const c = colors();
  ctx.strokeStyle = c.line; ctx.lineWidth = 1;
  ctx.beginPath();
  for (let i = 0; i <= cols; i++) { const x = i * cell + 0.5; ctx.moveTo(x, 0); ctx.lineTo(x, h); }
  for (let j = 0; j <= ROWS; j++) { const y = Math.min(h - 0.5, j * cell + 0.5); ctx.moveTo(0, y); ctx.lineTo(w, y); }
  ctx.stroke();
  paint(ctx, c);
  // 画面に収まるうちは左端、収まらなくなったら右端に合わせる
  scroller.scrollLeft = used + 1 <= Math.floor(width / cell) ? 0 : scroller.scrollWidth;
}

export function drawBigRoad(scroller, hands, cell, tieStyle) {
  const big = bigRoad(hands);
  const cells = place(big.columns);
  const used = cells.reduce((m, c) => Math.max(m, c.x), -1) + 1;
  grid(scroller, cell, used, (ctx, c) => {
    const tie = (x, y, n) => {
      if (tieStyle === 'slash') {
        slash(ctx, x, y, cell / 2 - 5, c.T, Math.max(2.2, cell / 12));
        if (n > 1) { dot(ctx, x, y, cell * 0.2, c.sheet); text(ctx, String(n), x, y, cell * 0.34, c.T); }
      } else {
        dot(ctx, x, y, cell * 0.24, c.T);
        if (n > 1) text(ctx, String(n), x, y, cell * 0.34, '#fff');
      }
    };
    for (const p of cells) {
      const x = (p.x + 0.5) * cell, y = (p.y + 0.5) * cell;
      ring(ctx, x, y, cell / 2 - 3.5, c[p.item.o], Math.max(2.6, cell / 9));
      if (p.item.ties > 0) tie(x, y, p.item.ties);
      if (p.item.bp) dot(ctx, p.x * cell + 4.5, p.y * cell + 4.5, 2.6, c.B);
      if (p.item.pp) dot(ctx, (p.x + 1) * cell - 4.5, (p.y + 1) * cell - 4.5, 2.6, c.P);
    }
    if (big.leadingTies > 0) tie(cell / 2, cell / 2, big.leadingTies);
  });
}

export function drawBeadPlate(scroller, hands, cell) {
  grid(scroller, cell, Math.ceil(hands.length / ROWS), (ctx, c) => {
    hands.forEach((h, i) => {
      const gx = Math.floor(i / ROWS), gy = i % ROWS;
      const x = (gx + 0.5) * cell, y = (gy + 0.5) * cell;
      dot(ctx, x, y, cell / 2 - 2.5, c[h.o]);
      text(ctx, BEAD[h.o], x, y, cell * 0.48, '#fff');
      if (h.bp) { dot(ctx, gx * cell + 5, gy * cell + 5, 3.2, c.sheet); dot(ctx, gx * cell + 5, gy * cell + 5, 2.4, c.B); }
      if (h.pp) { dot(ctx, (gx + 1) * cell - 5, (gy + 1) * cell - 5, 3.2, c.sheet); dot(ctx, (gx + 1) * cell - 5, (gy + 1) * cell - 5, 2.4, c.P); }
    });
  });
}

export function drawDerived(scroller, hands, k, cell) {
  const marks = derived(bigRoad(hands).columns, k);
  const cells = place(columns(marks, m => m));
  const used = cells.reduce((m, c) => Math.max(m, c.x), -1) + 1;
  grid(scroller, cell, used, (ctx, c) => {
    for (const p of cells) drawMark(ctx, (p.x + 0.5) * cell, (p.y + 0.5) * cell, cell, k, p.item, c);
  });
}
