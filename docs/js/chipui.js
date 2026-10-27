// 親とプレイヤーの画面で使う部品（アプリの ChipBetViews.swift・SummaryView.swift・ChipView.swift）
import {
  SPOTS, SPOT, OUTCOME_TITLE, odds, betSum, betSteps, clampBet, PRESETS, presetLimits, matchingPreset,
  dealt, limitText, netText, partyName,
} from './table.js';
import { openSheet, confirmBox, esc, fmt, icon, speak } from './ui.js';

const netCls = n => n > 0 ? 'up' : n < 0 ? 'down' : '';

/** 「受付中」「締め切り」の札 */
export const statusPill = closed =>
  `<span class="pill ${closed ? 'closed' : 'open'}">${closed ? icon('lock', 11) + '締め切り' : '<i></i>受付中'}</span>`;

/** 参加者のカード（名前・残高（通算）・ベット・直前の増減） */
export function memberCard(t, m, { isMe = false, lastNet = null, button = false } = {}) {
  const spots = t.bets[m.id] || {};
  const total = m.balance - dealt(t, m.id);
  const tag = button ? 'button' : 'div';
  const bets = SPOTS.filter(s => spots[s] > 0);
  return `<${tag} class="member${isMe ? ' me' : ''}" ${button ? `data-action="edit-member" data-id="${esc(m.id)}"` : ''}>
    <div class="m-top"><b>${esc(m.name)}</b>${isMe ? '<small>あなた</small>' : ''}<span class="grow"></span>${lastNet != null ? `<em class="${netCls(lastNet)}">${netText(lastNet)}</em>` : ''}</div>
    <div class="m-bal num">${fmt(m.balance)} pt <small>(${netText(total)})</small></div>
    ${t.rebuyRequests.includes(m.id) ? '<span class="m-ask">追加をお願い中</span>'
      : bets.length ? `<div class="m-bets">${bets.map(s => `<span class="${SPOT[s].cls}">${SPOT[s].short} ${fmt(spots[s])}</span>`).join('')}</div>`
        : '<div class="m-none">ベットなし</div>'}
  </${tag}>`;
}

/** 「第12手 BANKER あなた +95 pt」と、ほかの人の増減 */
export function settlementLine(round, myID) {
  if (!round) return '';
  const mine = round.results.find(r => r.member === myID);
  const others = round.results.filter(r => r.member !== myID);
  return `<div class="settle-line">
    <div><b>第${round.handNumber}手</b><span class="o-pill ${round.hand.o}">${OUTCOME_TITLE[round.hand.o]}</span>
      ${round.hand.bp ? '<span class="b small">B PAIR</span>' : ''}${round.hand.pp ? '<span class="p small">P PAIR</span>' : ''}
      ${mine ? `<strong class="${netCls(mine.net)}">あなた ${netText(mine.net)} pt</strong>` : ''}</div>
    ${!round.results.length ? '<small>ベットはありませんでした。</small>'
      : others.length ? `<small class="num">${others.map(r => `${esc(r.name)} ${netText(r.net)}`).join('　')}</small>` : ''}
  </div>`;
}

/**
 * ベットの盤。場所を押すと金額のシートが開く。
 * 戻り値の bind(el) で中のボタンをつなぐ。onChange(spots) で新しいベットを返す。
 */
export function betPadHTML({ spots, balance, commission, previous, minBet, maxBet, compact, closed }) {
  const staked = betSum(spots);
  const fig = (label, v) => `<div class="fig"><small>${label}</small><b class="num">${fmt(v)}</b></div>`;
  const spot = (s, tall) => {
    const a = spots[s] || 0;
    return `<button class="spot ${SPOT[s].cls}${a > 0 ? ' on' : ''}${tall ? ' tall' : ''}" data-bet-spot="${s}" ${closed ? 'disabled' : ''}>
      <b>${SPOT[s].title}</b><small class="num">${a > 0 ? `${fmt(a)} pt` : odds(s, commission)}</small></button>`;
  };
  return `<div class="betpad${compact ? ' compact' : ''}${closed ? ' is-closed' : ''}">
    ${minBet || maxBet ? `<p class="bp-limits">1か所あたり　下限 ${minBet ? fmt(minBet) : 'なし'} / 上限 ${maxBet ? fmt(maxBet) : 'なし'}</p>` : ''}
    ${closed ? `<div class="bp-closed">${icon('lock', 13)}<b>締め切り中</b><small>勝敗を記録すると受付に戻ります</small></div>` : ''}
    <div class="bp-row">${fig('残高', balance)}${fig('ベット中', staked)}${fig('使える', balance - staked)}</div>
    <div class="bp-keys">
      <div class="bp-row">${spot('banker', true)}${spot('tie', true)}${spot('player', true)}</div>
      <div class="bp-row">${spot('bankerPair')}${spot('playerPair')}</div>
      <div class="bp-row">
        <button class="padbtn" data-bet-act="prev" ${closed || !previous || !Object.keys(previous).length ? 'disabled' : ''}>前の手と同じ</button>
        <button class="padbtn" data-bet-act="clear" ${closed || !staked ? 'disabled' : ''}>ベットを消す</button>
      </div>
    </div>
  </div>`;
}

/** betPadHTML のボタンをつなぐ。opts は betPadHTML と同じもの＋ startingChips、onChange。 */
export function bindBetPad(root, getOpts) {
  root.addEventListener('click', e => {
    const o = getOpts();
    if (!o) return;
    const set = next => {
      if (betSum(next) > o.balance) return;
      // 「前の手と同じ」で、あとから変わった下限・上限から外れるものは入れない
      if (Object.values(next).some(v => v > 0 && clampBet(v, o.minBet, o.maxBet) !== v)) return;
      o.onChange(next);
    };
    const s = e.target.closest('[data-bet-spot]');
    if (s && !s.disabled) {
      const spot = s.dataset.betSpot;
      const cur = o.spots[spot] || 0;
      return amountSheet({
        spot, current: cur, available: o.balance - betSum(o.spots) + cur, minBet: o.minBet, maxBet: o.maxBet,
        steps: betSteps(o.startingChips), commission: o.commission,
        onDecide: amount => {
          const next = { ...o.spots };
          if (amount > 0) next[spot] = amount; else delete next[spot];
          set(next);
        },
      });
    }
    const a = e.target.closest('[data-bet-act]');
    if (!a || a.disabled) return;
    if (a.dataset.betAct === 'prev') set({ ...(o.previous || {}) });
    if (a.dataset.betAct === 'clear') set({});
  });
}

/** 場所ごとの金額を選ぶシート。「決定」で返す。 */
function amountSheet({ spot, current, available, minBet, maxBet, steps, commission, onDecide }) {
  let amount = current;
  const cap = maxBet > 0 ? Math.min(maxBet, available) : available;
  openSheet({
    title: `${SPOT[spot].title} のベット`,
    render: () => {
      const low = amount > 0 && minBet > 0 && amount < minBet;
      return `<div class="amount">
        <div class="amount-left">
          <span class="o-pill big ${SPOT[spot].cls.toUpperCase()}">${SPOT[spot].title}</span>
          <small class="muted">勝つと ${odds(spot, commission)}</small>
          <b class="amount-value num">${fmt(amount)} pt</b>
          <small class="muted num">使える ${fmt(available)}${minBet ? `・下限 ${fmt(minBet)}` : ''}${maxBet ? `・上限 ${fmt(maxBet)}` : ''}</small>
          ${low ? '<small class="b"><b>下限より少ないので置けません</b></small>' : ''}
        </div>
        <div class="amount-right">
          <div class="amount-grid">${steps.map(st => {
            const next = Math.min(clampBet(amount + st, minBet, maxBet), cap);
            return `<button class="amt" data-add="${next}" ${next <= amount ? 'disabled' : ''}>+${fmt(st)}</button>`;
          }).join('')}</div>
          <div class="amount-grid">
            <button class="amt" data-add="0" ${amount === 0 ? 'disabled' : ''}>0 にする</button>
            <button class="amt" data-add="${cap}" ${cap <= amount || (minBet > 0 && cap < minBet) ? 'disabled' : ''}>置けるだけ</button>
          </div>
          <button class="primary" data-decide ${amount === current || low ? 'disabled' : ''}>決定</button>
        </div></div>`;
    },
    bind: (el, close, update) => {
      el.onclick = e => {
        const b = e.target.closest('button');
        if (!b || b.disabled) return;
        if (b.dataset.add != null) { amount = Number(b.dataset.add); update(); }
        if (b.hasAttribute('data-decide')) { onDecide(amount); close(); }
      };
    },
  });
}

// ---- NO MORE BETS ----
export function noMoreBets(voice) {
  document.querySelector('.nomore')?.remove();
  const el = document.createElement('div');
  el.className = 'nomore';
  el.innerHTML = '<b>NO MORE BETS</b><span>ベットは締め切りました</span>';
  el.onclick = () => el.remove();
  document.getElementById('layer').appendChild(el);
  setTimeout(() => { el.classList.add('leaving'); setTimeout(() => el.remove(), 300); }, 1500);
  if (voice) speak('No more bets');
}

// ---- ベットの範囲を選ぶ（BetLimitPicker） ----
export function limitPickerHTML(state, startingChips) {
  const l = presetLimits(state.preset, startingChips);
  return `<div class="choices">${PRESETS.map(p =>
    `<button class="choice" data-preset="${p.key}" aria-pressed="${state.preset === p.key}">${p.title}</button>`).join('')}</div>
    ${state.preset === 'custom' ? `<label class="field"><span>下限（1か所あたり）</span><input inputmode="numeric" data-limit="min" value="${state.min || ''}" placeholder="なし"><em>pt</em></label>
      <label class="field"><span>上限（1か所あたり）</span><input inputmode="numeric" data-limit="max" value="${state.max || ''}" placeholder="なし"><em>pt</em></label>`
      : `<p class="limit-now num">1か所あたり　${l[0] === 0 && l[1] === 0 ? '下限・上限なし' : `下限 ${fmt(l[0])} / 上限 ${fmt(l[1])}`}</p>`}`;
}
export const chosenLimits = (state, startingChips) => presetLimits(state.preset, startingChips) ?? [state.min || 0, state.max || 0];
export const limitStateFrom = t => ({ preset: matchingPreset(t.minBet, t.maxBet, t.startingChips), min: t.minBet, max: t.maxBet });
export const toInt = v => { const n = parseInt(String(v).replace(/[^\d]/g, ''), 10); return Number.isFinite(n) ? n : 0; };

// ---- 結果（SummaryView） ----
export function summaryHTML(s, myID) {
  const d = t => new Date(t);
  const time = `${d(s.startedAt).toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })} 〜 ${d(s.endedAt).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;
  return `<div class="summary">
    <section class="card-box kv"><div><span>テーブル</span><b>${esc(s.tableName)}</b></div><div><span>時間</span><b>${time}</b></div><div><span>手の数</span><b>${s.hands} 手</b></div></section>
    ${s.bankNet != null ? `<section class="bank-row">${icon('table', 20)}<div><b>場（親）</b><small>精算で受け取った分 − 払った分（持ち点の配布と追加は除く）</small></div>
      <strong class="${netCls(s.bankNet)} num">${netText(s.bankNet)} pt</strong></section>` : ''}
    <h4 class="muted small">結果（増減の大きい順）</h4>
    <ol class="result-rows">${s.rows.length ? s.rows.map((r, i) => `<li class="${r.id === myID ? 'me' : ''}">
      <span class="rank num">${i + 1}</span>
      <div class="grow"><span><b>${esc(r.name)}</b>${r.id === myID ? '<span class="you">あなた</span>' : ''}</span>
        <small>勝った手 ${r.wins} / ベットした手 ${r.betHands}</small>${r.rebuys ? `<small>追加 +${fmt(r.rebuyTotal)} pt（${r.rebuys}回）</small>` : ''}</div>
      <div class="r-net"><strong class="${netCls(r.net)} num">${netText(r.net)} pt</strong><small class="num">残高 ${fmt(r.balance)} pt</small></div></li>`).join('')
      : '<li class="muted">参加者はいませんでした。</li>'}</ol>
    <p class="muted small">増減は、もらった合計（はじめの持ち点＋追加）との差です。チップは pt で数える遊び用の記録で、お金には換えられません。</p>
  </div>`;
}

export function openSummary(s, myID, onClose) {
  return openSheet({ title: '結果', wide: true, render: () => summaryHTML(s, myID), onClose });
}

export function openPastSummaries(list) {
  openSheet({
    title: 'これまでの結果',
    render: () => list.length ? `<ul class="shoe-list">${list.map((s, i) => `<li><button data-i="${i}"><b>${esc(s.tableName)}</b>
      <span class="muted">${new Date(s.endedAt).toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })}・${s.hands} 手・${s.rows.length} 人</span></button></li>`).join('')}</ul>`
      : '<div class="empty"><b>まだありません</b></div>',
    bind: el => { el.onclick = e => { const b = e.target.closest('[data-i]'); if (b) openSummary(list[Number(b.dataset.i)]); }; },
  });
}

// ---- 履歴の1行 ----
export function moveRowHTML(t, mv) {
  const time = new Date(mv.date).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
  const label = mv.kind === 'rebuy' ? `<span class="tag">追加</span>` : '';
  return `<li><small class="muted num">${time}</small>${label}<span>${esc(partyName(t, mv.from))} → ${esc(partyName(t, mv.to))}</span><b class="num">${fmt(mv.amount)} pt</b></li>`;
}

/** 名前を入れてもらう小さなシート */
export function askText({ title, message, placeholder = '', value = '', numeric = false, okLabel = '決める', onOK }) {
  const sheet = openSheet({
    title,
    render: () => `<form class="ask-form">${message ? `<p class="muted">${esc(message)}</p>` : ''}
      <input name="v" ${numeric ? 'inputmode="numeric"' : ''} value="${esc(value)}" placeholder="${esc(placeholder)}" autocomplete="off">
      <button class="primary" type="submit">${esc(okLabel)}</button></form>`,
    bind: (el, close) => {
      const f = el.querySelector('form');
      setTimeout(() => f.v.focus(), 50);
      f.onsubmit = e => { e.preventDefault(); const v = f.v.value.trim(); if (!v) return; close(); onOK(v); };
    },
  });
  return sheet;
}

export { confirmBox };
