// 罫線の一式と入力盤（アプリの RoadsBoard・InputDeck・MiniStats・StatsBar）。罫線だけの画面・親・プレイヤーで使う。
import { NAME, BEAD, DERIVED, ROWS, count, percent, nextMark, streakText } from './model.js';
import { drawBigRoad, drawBeadPlate, drawDerived, markIcon } from './draw.js';
import { esc, icon } from './ui.js';

export const isLandscape = () => innerWidth > innerHeight;

/** 罫線の一式。showAll が false なら大路だけを大きく。 */
export function boardHTML(hands, { showAll, compact, note }) {
  const c = count(hands), n = hands.length;
  const stat = (v, label, sub, cls) =>
    `<div class="stat ${cls}"><b>${v}</b><span>${label}</span><small>${sub ?? '&nbsp;'}</small></div>`;
  return `<div class="board${compact ? ' compact' : ''}">
    ${note && !compact ? `<div class="notice">${esc(note)}</div>` : ''}
    ${compact ? '' : `<div class="stats">
      ${stat(c.B, 'BANKER', percent(c.B, n), 'b')}${stat(c.P, 'PLAYER', percent(c.P, n), 'p')}${stat(c.T, 'TIE', percent(c.T, n), 't')}
      ${stat(c.bp, 'B PAIR', null, 'b')}${stat(c.pp, 'P PAIR', null, 'p')}</div>`}
    <section class="road big"><h3>大路<em>${esc(streakText(hands))}</em></h3><div class="scroller" data-road="big"></div></section>
    ${showAll ? `
      <section class="road"><h3>珠盤路</h3><div class="scroller" data-road="bead"></div></section>
      ${DERIVED.map(d => `<section class="road"><h3>${d.title}</h3><div class="scroller" data-road="d${d.k}"></div></section>`).join('')}` : ''}
    ${compact ? '' : `<button class="more" data-action="toggle-all">${icon('chevron', 14)}${showAll ? '大路だけにする' : '珠盤路・下三路・問路も見る'}</button>`}
  </div>`;
}

/** 描いた HTML の canvas に罫線を描く。横向きの大路だけのときは、6段が高さに収まる大きさにする。 */
export function paintBoard(root, hands, { showAll, compact, tieStyle }) {
  const big = root.querySelector('[data-road="big"]');
  if (!big) return;
  const landscape = isLandscape();
  const scale = landscape ? 1.35 : 1;
  let cell;
  if (showAll) cell = 22 * scale;
  else if (landscape) {
    const h = root.querySelector('.board')?.parentElement?.clientHeight || innerHeight;
    cell = Math.max(22, Math.min(compact ? 80 : 42, (h - (compact ? 56 : 130)) / ROWS));
  } else cell = 38;
  drawBigRoad(big, hands, cell, tieStyle);
  if (!showAll) return;
  drawBeadPlate(root.querySelector('[data-road="bead"]'), hands, 26 * scale);
  for (const d of DERIVED) drawDerived(root.querySelector(`[data-road="d${d.k}"]`), hands, d.k, 13 * scale);
}

/** 細い入力盤の上に出す集計 */
export function miniStatsHTML(hands) {
  const c = count(hands), n = hands.length;
  const row = (o, v) => `<div class="mini-row"><i class="dot ${o.toLowerCase()}"></i><b>${NAME[o]}</b><span class="grow"></span><strong>${v}</strong><small>${percent(v, n)}</small></div>`;
  return `<div class="mini-stats">${row('B', c.B)}${row('P', c.P)}${row('T', c.T)}
    <div class="mini-pairs"><span>B PAIR ${c.bp}</span><span>P PAIR ${c.pp}</span></div></div>`;
}

/**
 * 勝敗の入力盤。narrow なら細い列（集計・縦の結果ボタン）、そうでなければ問路つきの横並び。
 * ボタンは data-action="result" data-o="B|P|T"、"pair" data-pair="bp|pp"、"undo"。
 */
export function deckHTML(hands, { narrow, showAsk, pairs, canUndo, sampleNote, disabled }) {
  const res = o => `<button class="res ${o.toLowerCase()}" data-action="result" data-o="${o}" ${disabled ? 'disabled' : ''}>
    <span>${NAME[o]}</span><small>${o} ${BEAD[o]}</small></button>`;
  const pair = (key, label) => `<button class="pair ${key}" data-action="pair" data-pair="${key}" aria-pressed="${!!pairs[key]}" ${disabled ? 'disabled' : ''}>${label}</button>`;
  const undo = label => `<button class="undo" data-action="undo" ${canUndo && !disabled ? '' : 'disabled'} aria-label="1つ戻す">${icon('undo', 16)}${label ? '<span>1つ戻す</span>' : ''}</button>`;
  if (narrow) {
    return `<div class="deck narrow">${miniStatsHTML(hands)}
      ${sampleNote ? `<p class="deck-note">いまは例のシューです。1手目を記録すると消えます。</p>` : ''}
      ${res('B')}${res('P')}${res('T')}
      <div class="deck-row">${pair('bp', 'B PAIR')}${pair('pp', 'P PAIR')}${undo(false)}</div></div>`;
  }
  const ask = o => {
    const marks = DERIVED.map(d => ({ d, m: nextMark(hands, o, d.k) })).filter(x => x.m);
    return `<div class="ask"><b class="${o.toLowerCase()}">${o}なら</b>${marks.length
      ? marks.map(x => markIcon(x.d.k, x.m)).join('') : '<span class="none">まだ出ません</span>'}</div>`;
  };
  return `<div class="deck wide">
    ${showAsk ? `<div class="deck-row">${ask('B')}${ask('P')}</div>` : ''}
    <div class="deck-row results">${res('B')}${res('T')}${res('P')}</div>
    <div class="deck-row">${pair('bp', 'B PAIR')}${pair('pp', 'P PAIR')}${undo(true)}</div></div>`;
}
