// 罫線と3枚目のルールの計算（アプリの Models/Hand.swift・Roads.swift・ThirdCard.swift と同じ）

export const ROWS = 6;

/** @typedef {'B'|'P'|'T'} Outcome */
/** @typedef {{o: Outcome, bp?: boolean, pp?: boolean}} Hand */

export const NAME = { B: 'BANKER', P: 'PLAYER', T: 'TIE' };
export const BEAD = { B: '庄', P: '闲', T: '和' };

/** 初回に見せる例のシュー */
export function sampleHands() {
  return 'BBPTPPPBBBBPBPPTPBBBPPPPPPPBPBBTBPPBBPB'.split('').map((o, i) => ({ o, bp: i === 5, pp: i === 17 }));
}

export function count(hands) {
  const c = { B: 0, P: 0, T: 0, bp: 0, pp: 0 };
  for (const h of hands) {
    c[h.o]++;
    if (h.bp) c.bp++;
    if (h.pp) c.pp++;
  }
  return c;
}

export function percent(v, n) {
  return n === 0 ? '–' : `${Math.round((v / n) * 100)}%`;
}

/** 同じ種類が続くあいだを1列にまとめる（論理上の列） */
export function columns(items, key) {
  const cols = [];
  for (const it of items) {
    const last = cols[cols.length - 1];
    if (last && key(last[0]) === key(it)) last.push(it);
    else cols.push([it]);
  }
  return cols;
}

/** 論理上の列を6段に置く。下が埋まっているか6段を超えたら右へ曲がる（ドラゴンテール）。 */
export function place(cols) {
  const occ = new Set();
  const cells = [];
  let startX = -1;
  for (const col of cols) {
    startX++;
    while (occ.has(`${startX},0`)) startX++;
    let x = startX, y = 0, turned = false;
    col.forEach((item, i) => {
      if (i > 0) {
        if (!turned && y + 1 < ROWS && !occ.has(`${x},${y + 1}`)) y++;
        else { x++; turned = true; }
      }
      occ.add(`${x},${y}`);
      cells.push({ x, y, item });
    });
  }
  return cells;
}

/** 大路。タイは直前のマスに数として付く。 */
export function bigRoad(hands) {
  const entries = [];
  let leadingTies = 0;
  for (const h of hands) {
    if (h.o === 'T') {
      if (entries.length === 0) leadingTies++;
      else entries[entries.length - 1].ties++;
    } else {
      entries.push({ o: h.o, ties: 0, bp: !!h.bp, pp: !!h.pp });
    }
  }
  if (entries.length) { entries[0].ties += leadingTies; leadingTies = 0; }
  return { columns: columns(entries, e => e.o), leadingTies };
}

/** 下三路：k = 1 大眼仔、2 小路、3 曱甴路。'R'（赤）か 'U'（青）の並び。 */
export const DERIVED = [
  { k: 1, title: '大眼仔' },
  { k: 2, title: '小路' },
  { k: 3, title: '曱甴路' },
];

export function derived(cols, k) {
  const marks = [];
  for (let c = 0; c < cols.length; c++) {
    for (let r = 0; r < cols[c].length; r++) {
      if (r === 0) {
        if (c - 1 - k < 0) continue;
        marks.push(cols[c - 1].length === cols[c - 1 - k].length ? 'R' : 'U');
      } else {
        if (c - k < 0) continue;
        marks.push(cols[c - k].length === r ? 'U' : 'R');
      }
    }
  }
  return marks;
}

/** 問路：次が outcome だったら、その下三路に付く印 */
export function nextMark(hands, outcome, k) {
  const before = derived(bigRoad(hands).columns, k).length;
  const after = derived(bigRoad([...hands, { o: outcome }]).columns, k);
  return after.length > before ? after[after.length - 1] : null;
}

export function streakText(hands) {
  const { columns: cols } = bigRoad(hands);
  const cur = cols[cols.length - 1];
  if (!cur) return '';
  const longest = Math.max(...cols.map(c => c.length));
  return `いま ${cur[0].o}${cur.length}連・最長 ${longest}連`;
}

// ---- 3枚目のルール ----

export const RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
export function cardValue(rank) {
  const i = RANKS.indexOf(rank) + 1;
  return i >= 10 ? 0 : i;
}
export function total(cards) {
  return cards.reduce((s, r) => s + cardValue(r), 0) % 10;
}
export function isNatural(p, b) { return p >= 8 || b >= 8; }
export function playerDraws(p, b) { return !isNatural(p, b) && p <= 5; }
export function bankerDraws(b, p, playerThird) {
  if (isNatural(p, b)) return false;
  if (playerThird == null) return b <= 5;
  const t = cardValue(playerThird);
  switch (b) {
    case 0: case 1: case 2: return true;
    case 3: return t !== 8;
    case 4: return t >= 2 && t <= 7;
    case 5: return t >= 4 && t <= 7;
    case 6: return t === 6 || t === 7;
    default: return false;
  }
}
export function bankerReason(b, playerThird) {
  if (playerThird == null) {
    return b <= 5 ? 'PLAYER がスタンドしたので、BANKER は 0〜5 なら引きます' : 'PLAYER がスタンドしたので、BANKER は 6・7 ならスタンドです';
  }
  const p = `PLAYER の3枚目が ${playerThird}（${cardValue(playerThird)}）`;
  switch (b) {
    case 0: case 1: case 2: return 'BANKER が 0〜2 のときは、いつも引きます';
    case 3: return `${p}。BANKER 3 は、PLAYER の3枚目が 8 のときだけスタンド`;
    case 4: return `${p}。BANKER 4 は、PLAYER の3枚目が 2〜7 なら引きます`;
    case 5: return `${p}。BANKER 5 は、PLAYER の3枚目が 4〜7 なら引きます`;
    case 6: return `${p}。BANKER 6 は、PLAYER の3枚目が 6・7 なら引きます`;
    default: return 'BANKER が 7 のときは、いつもスタンドです';
  }
}
