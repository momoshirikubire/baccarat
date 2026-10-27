// ルール・応援・過去のシューのシート
import { RANKS, total, isNatural, playerDraws, bankerDraws, bankerReason, count } from './model.js';
import { boardHTML, paintBoard } from './board.js';
import { openSheet, confirmBox, esc, store } from './ui.js';
import { shoes } from './shoes.js';
import { TIP_URL } from './config.js';

// ---- ルール（Views/RulesView.swift） ----
export function openRules() {
  let tab = store.get('bn.rulesTab', 'judge');
  let player = [null, null, null], banker = [null, null, null];
  let picking = null; // {side, index}

  const judge = () => {
    const pTwo = player[0] && player[1] ? player.slice(0, 2) : null;
    const bTwo = banker[0] && banker[1] ? banker.slice(0, 2) : null;
    const pt = pTwo && total(pTwo), bt = bTwo && total(bTwo);
    const pNeeds = !!(pTwo && bTwo) && playerDraws(pt, bt);
    const bNeeds = !!(pTwo && bTwo) && !(pNeeds && !player[2]) && bankerDraws(bt, pt, pNeeds ? player[2] : null);
    if (!pNeeds) player[2] = null;
    if (!bNeeds) banker[2] = null;
    const result = (p, b) => p === b ? `PLAYER ${p}・BANKER ${b} で TIE` : `PLAYER ${p}・BANKER ${b} で ${p > b ? 'PLAYER' : 'BANKER'} の勝ち`;
    const lines = [];
    if (!pTwo || !bTwo) lines.push('PLAYER と BANKER の2枚ずつを選んでください');
    else {
      lines.push(`最初の2枚：PLAYER ${pt}・BANKER ${bt}`);
      if (isNatural(pt, bt)) {
        lines.push('どちらかが 8 か 9（ナチュラル）なので、どちらも引かずに勝負です', result(pt, bt));
      } else {
        let pf = pt, done = false;
        if (pNeeds) {
          lines.push(`PLAYER は ${pt}（0〜5）なので、3枚目を引きます`);
          if (!player[2]) { lines.push('PLAYER の3枚目を選ぶと、BANKER が引くかがわかります'); done = true; }
          else { pf = total(player); lines.push(`PLAYER の3枚目は ${player[2]}。PLAYER の合計は ${pf}`); }
        } else lines.push(`PLAYER は ${pt}（6・7）なので、スタンドです`);
        if (!done) {
          lines.push(bankerReason(bt, pNeeds ? player[2] : null));
          let bf = bt;
          if (bNeeds) {
            lines.push('→ BANKER は3枚目を引きます');
            if (!banker[2]) { lines.push('BANKER の3枚目を選ぶと、勝ち負けがわかります'); done = true; }
            else { bf = total(banker); lines.push(`BANKER の3枚目は ${banker[2]}。BANKER の合計は ${bf}`); }
          } else lines.push('→ BANKER はスタンドです');
          if (!done) lines.push(result(pf, bf));
        }
      }
    }
    const card = (side, i, label) => {
      const v = (side === 'p' ? player : banker)[i];
      const open = picking && picking.side === side && picking.index === i;
      return `<button class="card ${side}${v ? ' set' : ''}${open ? ' open' : ''}" data-act="pick" data-side="${side}" data-i="${i}">
        <b>${v ?? '?'}</b><small>${label}</small></button>`;
    };
    const row = (side, name, needs) => {
      const cards = side === 'p' ? player : banker;
      const picked = cards.filter(Boolean);
      return `<div class="hand-row"><b class="${side}">${name}</b>${card(side, 0, '1枚目')}${card(side, 1, '2枚目')}${needs ? card(side, 2, '3枚目') : ''}
        <span class="grow"></span>${picked.length >= 2 ? `<strong>合計 ${total(picked)}</strong>` : ''}</div>`;
    };
    return `<div class="judge">
      <div class="judge-picks">
        <p class="muted">配られたカードを順に選ぶと、3枚目を引くかどうかを出します。10・J・Q・K は 0、A は 1 と数えます。</p>
        ${row('p', 'PLAYER', pNeeds)}${row('b', 'BANKER', bNeeds)}
        ${picking ? `<div class="rank-picker">${RANKS.map(r => `<button data-act="rank" data-r="${r}">${r}</button>`).join('')}</div>` : ''}
        <button class="link" data-act="reset">最初から選び直す</button>
      </div>
      <ol class="steps">${lines.map(l => `<li>${esc(l)}</li>`).join('')}</ol>
    </div>`;
  };

  const rules = () => {
    const sec = (title, body) => `<section class="card-box"><h4>${title}</h4>${body}</section>`;
    const rows = list => `<table class="rule-table">${list.map(([a, b]) => `<tr><th>${a}</th><td>${b}</td></tr>`).join('')}</table>`;
    return `<div class="rules">
      ${sec('勝ち負け', '<p>PLAYER と BANKER に2枚ずつ配り、合計の下1けたが 9 に近いほうが勝ちです。同じなら TIE（引き分け）です。</p>')}
      ${sec('カードの数え方', '<p>A は 1、2〜9 はそのまま、10・J・Q・K は 0。合計が 10 を超えたら下1けただけを見ます（7 + 8 = 15 → 5）。</p>')}
      ${sec('ナチュラル', '<p>最初の2枚でどちらかが 8 か 9 なら、どちらも3枚目を引かずに勝負が決まります。</p>')}
      ${sec('PLAYER の3枚目', rows([['0〜5', '引く'], ['6・7', 'スタンド（引かない）']]))}
      ${sec('BANKER の3枚目', `<p>PLAYER がスタンドしたとき：BANKER は 0〜5 で引き、6・7 でスタンド。</p>
        <p>PLAYER が3枚目を引いたときは、BANKER の合計と PLAYER の3枚目で決まります。</p>
        ${rows([['0〜2', 'いつも引く'], ['3', 'PLAYER の3枚目が 8 以外なら引く'], ['4', 'PLAYER の3枚目が 2〜7 なら引く'],
          ['5', 'PLAYER の3枚目が 4〜7 なら引く'], ['6', 'PLAYER の3枚目が 6・7 なら引く'], ['7', 'いつもスタンド']])}`)}
      ${sec('ペア', '<p>最初の2枚が同じ数字（例：7 と 7）のとき、B PAIR・P PAIR として記録します。</p>')}
      <p class="muted small">ルールの細かいところは、お店やテーブルによってちがうことがあります。</p></div>`;
  };

  openSheet({
    title: 'バカラのルール',
    wide: true,
    render: () => `<div class="segmented">
        <button data-act="tab" data-tab="judge" aria-pressed="${tab === 'judge'}">3枚目の判定</button>
        <button data-act="tab" data-tab="rules" aria-pressed="${tab === 'rules'}">ルール</button></div>
      ${tab === 'judge' ? judge() : rules()}`,
    bind: (el, _close, update) => {
      el.onclick = e => {
        const b = e.target.closest('[data-act]');
        if (!b) return;
        const act = b.dataset.act;
        if (act === 'tab') { tab = b.dataset.tab; store.set('bn.rulesTab', tab); }
        if (act === 'pick') {
          const side = b.dataset.side, index = Number(b.dataset.i);
          picking = picking && picking.side === side && picking.index === index ? null : { side, index };
        }
        if (act === 'rank' && picking) {
          (picking.side === 'p' ? player : banker)[picking.index] = b.dataset.r;
          picking = null;
        }
        if (act === 'reset') { player = [null, null, null]; banker = [null, null, null]; picking = null; }
        update();
      };
    },
  });
}

// ---- 応援（Views/TipJarView.swift の DeveloperNote） ----
export function openTips() {
  openSheet({
    title: '応援',
    render: () => `<div class="dev-note">
      <div class="dev-head"><img src="icons/developer.jpg" alt="" width="44" height="44">
        <div><b>広告なしで続けたい！</b><small>作った人：桃尻くびれちゃん</small></div></div>
      <p>画面をすっきり使ってほしくて、広告は入れていません。App Store の登録料は毎年自費なので、応援してもらえると、続ける力と次のアップデートの力になります🍑</p>
      <p class="muted small">応援しなくても、すべての機能を使えます。</p>
      <div class="sns">
        <a class="sns-btn ig" href="https://www.instagram.com/momoshiri_kubire/" target="_blank" rel="noopener">Instagram</a>
        <a class="sns-btn tt" href="https://www.tiktok.com/@momoshiri_kubire" target="_blank" rel="noopener">TikTok</a>
      </div>
      ${TIP_URL ? `<a class="tip-link" href="${esc(TIP_URL)}" target="_blank" rel="noopener">応援する（外部のページが開きます）</a>` : ''}
    </div>`,
    // 応援のページを開いた人には、1年はお願いを出さない
    bind: el => { el.querySelector('.tip-link')?.addEventListener('click', () => store.set('bn.tippedAt', Date.now())); },
  });
}

// ---- 過去のシュー（Views/HistoryView.swift） ----
export function openHistory({ tieStyle }) {
  let open = null;
  const date = t => new Date(t).toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  const sheet = openSheet({
    title: '過去のシュー',
    wide: true,
    render: () => {
      if (open) {
        const s = shoes.past.find(x => x.id === open);
        return `<button class="link" data-act="back">← 一覧に戻る</button><p class="muted">${date(s.startedAt)}・${s.hands.length}手</p>
          ${boardHTML(s.hands, { showAll: true })}`;
      }
      if (!shoes.past.length) return `<div class="empty"><b>過去のシューはまだありません</b><p>右上の「新しいシュー」を押すと、いまのシューがここに残ります。</p></div>`;
      return `<ul class="shoe-list">${shoes.past.map(s => {
        const c = count(s.hands);
        return `<li><button data-act="open" data-id="${s.id}"><b>${date(s.startedAt)}</b>
          <span>${s.hands.length}手</span><span class="b">B ${c.B}</span><span class="p">P ${c.P}</span><span class="t">T ${c.T}</span></button>
          <button class="del" data-act="del" data-id="${s.id}" aria-label="消す">消す</button></li>`;
      }).join('')}</ul>`;
    },
    bind: (el, _close, update) => {
      if (open) {
        const s = shoes.past.find(x => x.id === open);
        requestAnimationFrame(() => paintBoard(el, s.hands, { showAll: true, tieStyle }));
      }
      el.onclick = e => {
        const b = e.target.closest('[data-act]');
        if (!b) return;
        if (b.dataset.act === 'open') { open = b.dataset.id; update(); }
        if (b.dataset.act === 'back') { open = null; update(); }
        if (b.dataset.act === 'del') {
          confirmBox({
            title: 'このシューを消しますか？', buttons: [
              { label: '消す', role: 'destructive', run: () => { shoes.deletePast(b.dataset.id); sheet.update(); } },
              { label: 'キャンセル', role: 'cancel' }],
          });
        }
      };
    },
  });
}
