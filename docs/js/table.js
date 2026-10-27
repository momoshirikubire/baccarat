// チップのテーブル（アプリの Models/ChipTable.swift・ChipBaccarat.swift）。
// 参加者の残高を pt で数える。お金には換えない（円は使わない）。テーブルはふつうの JSON のオブジェクトで、親の端末が持つ。
import { fmt, signed } from './ui.js';

export const SPOTS = ['banker', 'tie', 'player', 'bankerPair', 'playerPair'];
export const SPOT = {
  banker: { title: 'BANKER', short: 'B', cls: 'b' },
  player: { title: 'PLAYER', short: 'P', cls: 'p' },
  tie: { title: 'TIE', short: 'T', cls: 't' },
  bankerPair: { title: 'B PAIR', short: 'BP', cls: 'b' },
  playerPair: { title: 'P PAIR', short: 'PP', cls: 'p' },
};
export const OUTCOME_TITLE = { B: 'BANKER', P: 'PLAYER', T: 'TIE' };

export const newID = () => crypto.randomUUID?.() || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;

/** 払い戻しの説明 */
export const odds = (spot, commission) =>
  ({ banker: commission ? '0.95倍' : '1倍', player: '1倍', tie: '8倍', bankerPair: '11倍', playerPair: '11倍' })[spot];

/** この手での増減（負けはマイナス）。TIE のとき BANKER・PLAYER は戻る（0）。手数料ありの BANKER の勝ちは 0.95倍で切り捨て。 */
export function spotNet(spot, amount, hand, commission) {
  switch (spot) {
    case 'banker': return hand.o === 'B' ? (commission ? Math.floor(amount * 95 / 100) : amount) : hand.o === 'T' ? 0 : -amount;
    case 'player': return hand.o === 'P' ? amount : hand.o === 'T' ? 0 : -amount;
    case 'tie': return hand.o === 'T' ? amount * 8 : -amount;
    case 'bankerPair': return hand.bp ? amount * 11 : -amount;
    case 'playerPair': return hand.pp ? amount * 11 : -amount;
  }
  return 0;
}

const sum = spots => Object.values(spots || {}).reduce((a, b) => a + b, 0);
export const betSum = sum;

// ---- きりのいい数と、ベットの範囲の候補（BetLimitPreset） ----
export const NICE = (() => {
  const list = [1, 5];
  for (let base = 10; base <= 10_000_000; base *= 10) list.push(base, base * 5 / 2, base * 5);
  return list;
})();
export const nice = v => NICE.reduce((best, c) => Math.abs(c - v) < Math.abs(best - v) ? c : best, 1);

export const PRESETS = [
  { key: 'none', title: 'なし' },
  { key: 'slow', title: 'ゆっくり', r: [0.01, 0.1] },
  { key: 'normal', title: 'ふつう', r: [0.02, 0.2] },
  { key: 'large', title: '大きく', r: [0.05, 0.5] },
  { key: 'custom', title: '自分で決める' },
];
/** 持ち点からの下限・上限。なしは [0, 0]、自分で決めるは null。 */
export function presetLimits(key, startingChips) {
  if (key === 'none') return [0, 0];
  const p = PRESETS.find(x => x.key === key);
  if (!p?.r) return null;
  const s = Math.max(1, startingChips);
  const low = nice(s * p.r[0]);
  let high = nice(s * p.r[1]);
  if (high <= low) high = NICE.find(c => c > low) ?? low * 2;
  return [low, high];
}
export function matchingPreset(minBet, maxBet, startingChips) {
  if (!minBet && !maxBet) return 'none';
  return ['slow', 'normal', 'large'].find(k => {
    const l = presetLimits(k, startingChips);
    return l[0] === minBet && l[1] === maxBet;
  }) || 'custom';
}
/** ベットの +N：持ち点の 1/100・1/20・1/10・1/2 */
export function betSteps(startingChips) {
  const s = Math.max(1, startingChips);
  return [...new Set([0.01, 0.05, 0.1, 0.5].map(r => nice(s * r)))];
}
/** 0 でなければ、下限以上・上限以下にそろえる */
export function clampBet(amount, minBet, maxBet) {
  if (amount <= 0) return 0;
  let a = amount;
  if (minBet > 0) a = Math.max(a, minBet);
  if (maxBet > 0) a = Math.min(a, maxBet);
  return a;
}

// ---- テーブル ----
export function createTable({ name, startingChips, bankerCommission = false, minBet = 0, maxBet = 0 }) {
  return {
    id: newID(), name, startingChips: Math.max(0, startingChips), bankerCommission, minBet: Math.max(0, minBet), maxBet: Math.max(0, maxBet),
    members: [], moves: [], bets: {}, hands: [], rounds: [], stats: {}, settledHands: 0,
    createdAt: Date.now(), rebuyRequests: [], betsClosed: false, bankNet: 0,
  };
}

export const member = (t, id) => t.members.find(m => m.id === id);
export const betTotal = (t, id) => sum(t.bets[id]);
export const available = (t, id) => (member(t, id)?.balance ?? 0) - betTotal(t, id);
export const partyName = (t, p) => p === 'bank' ? '場' : member(t, p)?.name ?? '（抜けた人）';
export const dealt = (t, id) => t.stats[id]?.dealt ?? t.startingChips;
export const lastRound = t => t.rounds.at(-1) || null;
export function limitText(t) {
  if (!t.minBet && !t.maxBet) return null;
  return `下限 ${t.minBet ? fmt(t.minBet) : 'なし'} / 上限 ${t.maxBet ? fmt(t.maxBet) : 'なし'}`;
}

const stat = (t, id) => (t.stats[id] ||= { dealt: t.startingChips, wins: 0, betHands: 0, rebuys: 0, rebuyTotal: 0 });
const addTo = (t, party, amount) => { const m = party !== 'bank' && member(t, party); if (m) m.balance += amount; };

/** 動かす。settlement でないとき（配る・追加・戻す）は、場とのやり取りを「もらった持ち点」として数える。 */
function apply(t, move, settlement = false) {
  addTo(t, move.from, -move.amount);
  addTo(t, move.to, move.amount);
  t.moves.push(move);
  if (t.moves.length > 300) t.moves.splice(0, t.moves.length - 300);
  if (settlement) return;
  if (move.from === 'bank' && move.to !== 'bank') stat(t, move.to).dealt += move.amount;
  if (move.to === 'bank' && move.from !== 'bank') stat(t, move.from).dealt -= move.amount;
}
const makeMove = (from, to, amount, by, kind) => ({ id: newID(), date: Date.now(), from, to, amount, by, ...(kind ? { kind } : {}) });

/** 参加する。はじめてなら持ち点を配る。つなぎ直したときは残高をそのままにする。 */
export function join(t, id, name) {
  const m = member(t, id);
  if (m) { m.name = name; return; }
  t.members.push({ id, name, balance: 0 });
  t.stats[id] = { dealt: 0, wins: 0, betHands: 0, rebuys: 0, rebuyTotal: 0 };
  if (t.startingChips > 0) apply(t, makeMove('bank', id, t.startingChips, id));
}

export function removeMember(t, id, by) {
  const m = member(t, id);
  if (!m) return;
  delete t.bets[id];
  if (m.balance > 0) apply(t, makeMove(id, 'bank', m.balance, by));
  t.members = t.members.filter(x => x.id !== id);
  t.rebuyRequests = t.rebuyRequests.filter(x => x !== id);
}

/** 渡す（参加者どうし）。だめなときは理由を返す。 */
export function moveProblem(t, from, to, amount) {
  if (!(amount > 0)) return '1 pt 以上を入れてください。';
  if (from === to) return '同じところには動かせません。';
  if (from !== 'bank') {
    const m = member(t, from);
    if (!m) return '参加者が見つかりません。';
    const free = available(t, from);
    if (free < amount) return betTotal(t, from) > 0
      ? `${m.name}さんの使えるチップが足りません（ベット中を除いて ${fmt(free)} pt）。`
      : `${m.name}さんのチップが足りません（${fmt(m.balance)} pt）。`;
  }
  if (to !== 'bank' && !member(t, to)) return '参加者が見つかりません。';
  return null;
}
export function transfer(t, from, to, amount, by) {
  const p = moveProblem(t, from, to, amount);
  if (!p) apply(t, makeMove(from, to, amount, by));
  return p;
}

/** 追加（リバイ）：場からその人に足す。もらった合計に入り、お願いの印は消える。 */
export function rebuy(t, id, amount, by) {
  if (!(amount > 0) || !member(t, id)) return;
  apply(t, makeMove('bank', id, amount, by, 'rebuy'));
  const s = stat(t, id);
  s.rebuys += 1;
  s.rebuyTotal += amount;
  t.rebuyRequests = t.rebuyRequests.filter(x => x !== id);
}

/** 全員の残高を持ち点に戻して、履歴を消す */
export function restart(t) {
  const people = t.members;
  Object.assign(t, { members: [], moves: [], bets: {}, rounds: [], stats: {}, bankNet: 0, rebuyRequests: [], settledHands: 0, createdAt: Date.now(), betsClosed: false });
  for (const m of people) join(t, m.id, m.name);
}

export function limitProblem(t, spots) {
  for (const s of SPOTS) {
    const a = spots?.[s] || 0;
    if (a <= 0) continue;
    if (t.minBet > 0 && a < t.minBet) return `${SPOT[s].title} は ${fmt(t.minBet)} pt 以上にしてください（下限）。`;
    if (t.maxBet > 0 && a > t.maxBet) return `${SPOT[s].title} は ${fmt(t.maxBet)} pt までです（上限）。`;
  }
  return null;
}

/** ベットを入れられるか。だめなときは理由。 */
export function betProblem(t, spots, id) {
  const m = member(t, id);
  if (!m) return '参加者が見つかりません。';
  if (t.betsClosed) return 'ベットは締め切りました。次の手の受付を待ってください。';
  if (Object.entries(spots || {}).some(([k, v]) => !SPOT[k] || !Number.isInteger(v) || v < 0)) return '0 pt 以上を入れてください。';
  const lp = limitProblem(t, spots);
  if (lp) return lp;
  if (sum(spots) > m.balance) return `${m.name}さんのチップが足りません（${fmt(m.balance)} pt）。`;
  return null;
}

export function setBet(t, spots, id) {
  const kept = Object.fromEntries(Object.entries(spots || {}).filter(([k, v]) => SPOT[k] && v > 0));
  if (Object.keys(kept).length) t.bets[id] = kept;
  else delete t.bets[id];
}

export function setLimits(t, minBet, maxBet) {
  t.minBet = Math.max(0, minBet || 0);
  t.maxBet = Math.max(0, maxBet || 0);
  for (const id of Object.keys(t.bets)) if (limitProblem(t, t.bets[id])) delete t.bets[id];
}

/** 勝敗が決まったら精算する。勝った分は場から受け取り、負けた分は場へ払う。 */
export function settle(t, hand, handNumber, shoeID, by) {
  const round = { id: newID(), date: Date.now(), handNumber, shoeID, hand, bets: structuredClone(t.bets), results: [], moveIDs: [] };
  for (const m of t.members) {
    const spots = t.bets[m.id];
    if (!spots || !Object.keys(spots).length) continue;
    const staked = sum(spots);
    let net = Object.entries(spots).reduce((a, [k, v]) => a + spotNet(k, v, hand, t.bankerCommission), 0);
    net = Math.max(net, -m.balance);
    if (net !== 0) {
      const move = net > 0 ? makeMove('bank', m.id, net, by) : makeMove(m.id, 'bank', -net, by);
      apply(t, move, true);
      round.moveIDs.push(move.id);
    }
    round.results.push({ member: m.id, name: m.name, staked, net });
    t.bankNet -= net;
    const s = stat(t, m.id);
    s.betHands += 1;
    if (net > 0) s.wins += 1;
  }
  // TIE のときは BANKER・PLAYER のベットが戻るので、次の手にそのまま残す
  if (hand.o === 'T') {
    const next = {};
    for (const [id, spots] of Object.entries(t.bets)) {
      const kept = Object.fromEntries(Object.entries(spots).filter(([k]) => k === 'banker' || k === 'player'));
      if (Object.keys(kept).length) next[id] = kept;
    }
    t.bets = next;
  } else t.bets = {};
  t.settledHands += 1;
  t.betsClosed = false;
  t.rounds.push(round);
  if (t.rounds.length > 50) t.rounds.splice(0, t.rounds.length - 50);
  return round;
}

/** 直前の精算を取り消して、そのときのベットに戻す。シューと手番号が合わなければ何もしない。 */
export function undoRound(t, handNumber, shoeID) {
  const round = lastRound(t);
  if (!round || round.handNumber !== handNumber || round.shoeID !== shoeID) return false;
  t.rounds.pop();
  for (const id of [...round.moveIDs].reverse()) {
    const i = t.moves.findLastIndex(x => x.id === id);
    if (i < 0) continue;
    const [move] = t.moves.splice(i, 1);
    addTo(t, move.to, -move.amount);
    addTo(t, move.from, move.amount);
  }
  for (const r of round.results) {
    t.bankNet += r.net;
    const s = t.stats[r.member];
    if (s) { s.betHands -= 1; if (r.net > 0) s.wins -= 1; }
  }
  t.settledHands = Math.max(0, t.settledHands - 1);
  t.betsClosed = true;
  t.bets = Object.fromEntries(Object.entries(round.bets).filter(([id]) => member(t, id)));
  return true;
}

/** 終了したときの結果（増減の大きい順） */
export function summary(t) {
  const rows = t.members.map(m => {
    const s = t.stats[m.id] || { dealt: t.startingChips, wins: 0, betHands: 0, rebuys: 0, rebuyTotal: 0 };
    return { id: m.id, name: m.name, balance: m.balance, net: m.balance - s.dealt, wins: s.wins, betHands: s.betHands, rebuys: s.rebuys, rebuyTotal: s.rebuyTotal };
  }).sort((a, b) => a.net !== b.net ? b.net - a.net : b.balance - a.balance);
  return { id: newID(), tableName: t.name, startedAt: t.createdAt, endedAt: Date.now(), hands: t.settledHands, rows, bankNet: t.bankNet };
}

export const netText = n => n === 0 ? '±0' : signed(n);
