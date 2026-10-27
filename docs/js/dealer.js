// 親（テーブルを作った人）の画面（アプリの Views/Chips/DealerView.swift）。
// 上に参加者の帯、左に罫線、右に勝敗の入力盤。勝敗を入れると、みんなのベットを pt で精算する。
import * as T from './table.js';
import {
  statusPill, memberCard, betPadHTML, bindBetPad, noMoreBets, limitPickerHTML, chosenLimits, limitStateFrom, toInt,
  openSummary, openPastSummaries, moveRowHTML, askText, settlementLine,
} from './chipui.js';
import { boardHTML, paintBoard, deckHTML, isLandscape } from './board.js';
import { shoes } from './shoes.js';
import { openRules, openTips, openHistory } from './sheets.js';
import { prefs, modeButton, leaveToPicker, countForNudge } from './app.js';
import { netAvailable, hostOpen, hostPublish, hostEnd, hostListenPlayers, myUid } from './net.js';
import { tbtn, icon, openMenu, openSheet, confirmBox, toast, splash, speak, handPhrase, buzz, store, esc, fmt } from './ui.js';

const HOST_KEY = 'bn.host';
const RESULTS_KEY = 'bn.results';
const CHIP_CHOICES = [10000, 30000, 50000, 100000];

export const pastResults = () => store.get(RESULTS_KEY, []);
const localID = () => {
  let id = store.get('bn.myID', null);
  if (!id) { id = T.newID(); store.set('bn.myID', id); }
  return id;
};

export function dealerScreen(api) {
  const saved = store.get(HOST_KEY, null);
  if (saved?.table) tableScreen(api, saved);
  else setupScreen(api);
}

// ---- テーブルを作る（DealerSetupView） ----
function setupScreen(api) {
  const { app } = api;
  const f = {
    me: store.get('bn.myName', ''), tableName: '', chips: 10000, customChips: false,
    limits: { preset: 'normal', min: 0, max: 0 }, commission: false, hostBets: false,
  };
  let busy = false;
  const defaultName = () => f.me.trim() ? `${f.me.trim()}のテーブル` : 'テーブル';
  const finalName = () => f.tableName.trim() || defaultName();
  const starting = () => Math.max(1, f.chips || 1);

  const summaryCard = () => {
    const [lo, hi] = chosenLimits(f.limits, starting());
    const row = (a, b) => `<div class="s-row"><span>${a}</span><b class="num">${b}</b></div>`;
    return `<div class="setup-summary">
      <small>こんなテーブルになります</small>
      <h3>${esc(finalName())}</h3>
      ${row('持ち点', `${fmt(starting())} pt`)}
      ${row('ベットの範囲', lo === 0 && hi === 0 ? 'なし' : `${fmt(lo)}〜${fmt(hi)} pt`)}
      ${row('BANKER', f.commission ? '0.95倍' : '1倍')}
      ${row('親のベット', f.hostBets ? 'する' : 'しない')}
      <p>${netAvailable() ? '作ると4桁の参加番号が出ます。' : 'いまは、この1台だけで使うテーブルになります（参加者は親が足します）。'}pt は遊び用で、お金には換えられません。</p>
    </div>`;
  };

  const render = () => {
    const land = isLandscape();
    const past = pastResults();
    const toggle = (key, title, detail) => `<button class="toggle-row" data-toggle="${key}" role="switch" aria-checked="${f[key]}">
      <span><b>${title}</b><small>${detail}</small></span><i class="switch"></i></button>`;
    app.innerHTML = `
      <header class="toolbar"><div class="tb-left">${modeButton()}</div><b class="tb-center">テーブルを作る</b><div class="tb-right"></div></header>
      <main class="setup ${land ? 'side' : 'stack'}">
        <div class="setup-form">
          <section class="card-box"><h4>名前</h4>
            <label class="field"><span>あなた</span><input data-f="me" value="${esc(f.me)}" placeholder="みんなの画面に出る名前" maxlength="20"></label>
            <label class="field"><span>テーブル</span><input data-f="tableName" value="${esc(f.tableName)}" placeholder="${esc(defaultName())}（空のままでよい）" maxlength="30"></label>
          </section>
          <section class="card-box"><h4>はじめの持ち点</h4>
            <div class="choices">${CHIP_CHOICES.map(c => `<button class="choice num" data-chips="${c}" aria-pressed="${!f.customChips && f.chips === c}">${fmt(c)}</button>`).join('')}
              <button class="choice" data-chips="custom" aria-pressed="${f.customChips}">自分で決める</button></div>
            ${f.customChips ? `<label class="field"><span>持ち点</span><input data-f="chips" inputmode="numeric" value="${f.chips || ''}" placeholder="1000"><em>pt</em></label>` : ''}
          </section>
          <section class="card-box"><h4>ベットの範囲（1か所あたり）</h4><div data-limits>${limitPickerHTML(f.limits, starting())}</div></section>
          <section class="card-box"><h4>ルール</h4>
            ${toggle('commission', 'BANKER の手数料 5%', 'オンにすると BANKER の勝ちは 0.95倍')}
            ${toggle('hostBets', '自分もプレイヤーとしてベットする', '親を置かずに、みんなで遊ぶとき')}
          </section>
          ${past.length ? `<button class="link" data-action="past">${icon('history', 15)} これまでの結果（${past.length}）</button>` : ''}
        </div>
        <div class="setup-side">
          <div data-summary>${summaryCard()}</div>
          <button class="primary big" data-action="create" ${busy ? 'disabled' : ''}>${busy ? 'つないでいます…' : 'テーブルを作る'}</button>
        </div>
      </main>`;
  };

  const refreshSummary = () => { app.querySelector('[data-summary]').innerHTML = summaryCard(); };

  app.oninput = e => {
    const k = e.target.dataset.f;
    if (k === 'chips') f.chips = toInt(e.target.value);
    else if (k) f[k] = e.target.value;
    const lim = e.target.dataset.limit;
    if (lim) f.limits[lim] = toInt(e.target.value);
    if (k === 'me') app.querySelector('[data-f="tableName"]').placeholder = `${defaultName()}（空のままでよい）`;
    if (k === 'chips') app.querySelector('[data-limits]').innerHTML = limitPickerHTML(f.limits, starting());
    refreshSummary();
  };
  app.onclick = async e => {
    const b = e.target.closest('button');
    if (!b || b.disabled) return;
    if (b.dataset.action === 'mode') return leaveToPicker();
    if (b.dataset.action === 'past') return openPastSummaries(pastResults());
    if (b.dataset.chips) {
      if (b.dataset.chips === 'custom') f.customChips = true;
      else { f.customChips = false; f.chips = Number(b.dataset.chips); }
      return render();
    }
    if (b.dataset.preset) { f.limits.preset = b.dataset.preset; return render(); }
    if (b.dataset.toggle) { f[b.dataset.toggle] = !f[b.dataset.toggle]; return render(); }
    if (b.dataset.action === 'create') {
      busy = true; render();
      try {
        store.set('bn.myName', f.me.trim());
        const [minBet, maxBet] = chosenLimits(f.limits, starting());
        let code = '', myID = localID();
        if (netAvailable()) ({ code, uid: myID } = await hostOpen());
        const table = T.createTable({ name: finalName(), startingChips: starting(), bankerCommission: f.commission, minBet, maxBet });
        if (f.hostBets) T.join(table, myID, f.me.trim() || '記録係');
        // 新しいテーブルは空の罫線から始める（いまのシューは「過去のシュー」へ）
        shoes.startNew();
        const saved = { code, myID, open: true, table };
        store.set(HOST_KEY, saved);
        tableScreen(api, saved);
      } catch (err) {
        busy = false; render();
        toast(err.message || 'テーブルを作れませんでした。');
      }
    }
  };

  api.setScreen({ render });
}

// ---- 親のテーブル（DealerTableView） ----
function tableScreen(api, saved) {
  const { app } = api;
  const state = saved; // { code, myID, open, table }
  const t = () => state.table;
  const pairs = { bp: false, pp: false };
  const live = new Set(); // 開いているシート（変わったら描き直す）
  let stopPlayers = null, publishTimer = null, disposed = false, players = [];
  const online = !!state.code;

  const sharedHands = () => shoes.isSample ? [] : shoes.hands;

  const commit = () => {
    if (disposed) return;
    store.set(HOST_KEY, state);
    if (online) {
      clearTimeout(publishTimer);
      publishTimer = setTimeout(() => hostPublish(state.code, state.table, state.open).catch(() => toast('送れませんでした。電波を確かめてください。')), 60);
    }
    render();
    live.forEach(s => s.closed ? live.delete(s) : s.update());
  };

  // ---- プレイヤーから届いたこと（名前・ベット・追加のお願い・渡す）を確かめて入れる ----
  const onPlayers = list => {
    players = list;
    const tb = t();
    tb.seen ||= {}; tb.acks ||= {};
    let changed = false;
    for (const p of list) {
      const seen = tb.seen[p.uid] ||= { bet: 0, rebuy: 0, give: 0 };
      const m = T.member(tb, p.uid);
      if (!m) {
        if (!state.open || p.left || !p.name) continue;
        T.join(tb, p.uid, String(p.name).slice(0, 20));
        changed = true;
      } else if (p.name && m.name !== p.name) { m.name = String(p.name).slice(0, 20); changed = true; }
      if (p.betAt > seen.bet) {
        seen.bet = p.betAt;
        let spots = {};
        try { spots = JSON.parse(p.bet || '{}'); } catch { /* 読めないものは空 */ }
        const problem = T.betProblem(tb, spots, p.uid);
        if (!problem) T.setBet(tb, spots, p.uid);
        tb.acks[p.uid] = { at: p.betAt, error: problem };
        changed = true;
      }
      if (p.rebuyAt > seen.rebuy) {
        seen.rebuy = p.rebuyAt;
        if (!tb.rebuyRequests.includes(p.uid)) tb.rebuyRequests.push(p.uid);
        changed = true;
      }
      if (p.give?.at > seen.give) {
        seen.give = p.give.at;
        const problem = T.transfer(tb, p.uid, p.give.to, toInt(p.give.amount), p.uid);
        tb.acks[p.uid] = { ...tb.acks[p.uid], giveAt: p.give.at, giveError: problem };
        changed = true;
      }
    }
    if (changed) commit(); else render();
  };

  if (online) {
    hostListenPlayers(state.code, t().id, onPlayers, () => toast('つながりが切れました。電波を確かめてください。'))
      .then(stop => { if (disposed) stop(); else stopPlayers = stop; });
    // 開き直したときも、いまのテーブルを配り直す
    hostPublish(state.code, state.table, state.open).catch(() => {});
  }

  const startRebuy = m => askText({
    title: '追加（リバイ）', message: `${m.name}さんに、場から pt を足します。`, numeric: true,
    value: String(t().startingChips), okLabel: '追加する',
    onOK: v => { const a = toInt(v); if (a > 0) { T.rebuy(t(), m.id, a, state.myID); commit(); } },
  });
  const addMember = () => askText({
    title: '参加者を足す', message: 'スマホを使わない人のぶんです。はじめの持ち点を配ります。', placeholder: '名前',
    okLabel: '足す', onOK: v => { T.join(t(), T.newID(), v.slice(0, 20)); commit(); },
  });

  // ---- 上の帯：参加番号・場の収支・直前の結果・参加者 ----
  const band = () => {
    const tb = t(), last = T.lastRound(tb);
    const remote = tb.members.filter(m => players.some(p => p.uid === m.id)).length;
    return `<div class="band">
      <div class="band-info">
        <div>${online ? (state.open
          ? `<small>参加番号</small><b class="code num">${esc(state.code)}</b><small>${remote} 人がスマホで参加</small>`
          : '<small>新しい人は<br>参加できません</small>') : '<small>この1台だけで<br>使っています</small>'}</div>
        <div>${statusPill(tb.betsClosed)}
          <b class="bank num ${tb.bankNet > 0 ? 'up' : tb.bankNet < 0 ? 'down' : ''}">場 ${T.netText(tb.bankNet)} pt</b>
          ${T.limitText(tb) ? `<small>${T.limitText(tb)}</small>` : ''}</div>
      </div>
      ${last ? `<div class="band-last"><small>第${last.handNumber}手</small><span class="o-pill ${last.hand.o}">${T.OUTCOME_TITLE[last.hand.o]}</span></div>` : ''}
      <div class="band-members">
        ${tb.members.map(m => `<div class="m-col">${memberCard(tb, m, { isMe: m.id === state.myID, lastNet: last?.results.find(r => r.member === m.id)?.net ?? null, button: true })}
          ${tb.rebuyRequests.includes(m.id) ? `<button class="warn-btn" data-action="rebuy" data-id="${esc(m.id)}">追加する</button>` : ''}</div>`).join('')}
        <button class="add-member" data-action="add-member">${icon('users', 15)}参加者を足す</button>
      </div>
    </div>`;
  };

  const myBetOpts = () => {
    const tb = t(), me = T.member(tb, state.myID);
    if (!me) return null;
    return {
      spots: tb.bets[me.id] || {}, balance: me.balance, commission: tb.bankerCommission, previous: T.lastRound(tb)?.bets[me.id],
      minBet: tb.minBet, maxBet: tb.maxBet, startingChips: tb.startingChips, compact: true, closed: tb.betsClosed,
      onChange: spots => placeBet(spots, me.id),
    };
  };

  const placeBet = (spots, id) => {
    const problem = T.betProblem(t(), spots, id);
    if (problem) return toast(problem);
    T.setBet(t(), spots, id);
    commit();
  };

  const render = () => {
    if (disposed) return;
    const land = isLandscape();
    const tb = t();
    const showAll = prefs.showAll;
    const hands = sharedHands();
    const mine = myBetOpts();
    const closeBar = tb.betsClosed
      ? `<div class="close-bar">${statusPill(true)}<small>勝敗で次の手へ</small></div>`
      : `<button class="close-btn" data-action="close-bets">${icon('lock', 15)}締め切る（NO MORE BETS）</button>`;
    app.innerHTML = `
      <header class="toolbar">
        <div class="tb-left">${modeButton()}${tbtn('rules', 'book', 'ルール')}<b class="tb-title">${hands.length} 手</b></div>
        <div class="tb-right">${tbtn('manage', 'users', 'テーブル')}${tbtn('view', 'sliders', '表示')}${tbtn('shoe', 'history', 'シュー')}${tbtn('tips', 'gift', '応援')}</div>
      </header>
      ${band()}
      <main class="screen ${land ? 'side' : 'stack'}">
        <div class="pane">${boardHTML(hands, { showAll, compact: false })}
          ${mine && !land ? `<div class="mybet inline"><div class="mybet-head"><b>あなたのベット</b><button class="warn-btn" data-action="rebuy" data-id="${esc(state.myID)}">ポイントを追加</button></div><div data-mybet>${betPadHTML(mine)}</div></div>` : ''}
        </div>
        ${mine && land ? `<aside class="mybet"><div class="mybet-head"><b>あなたのベット</b><button class="warn-btn" data-action="rebuy" data-id="${esc(state.myID)}">ポイントを追加</button></div><div data-mybet>${betPadHTML(mine)}</div></aside>` : ''}
        <aside class="deck-wrap dealer" style="${land ? `width:${mine ? 250 : 300}px` : ''}">
          <div class="deck-top">${closeBar}<small class="deck-label">勝敗を記録</small></div>
          ${deckHTML(shoes.hands, { narrow: false, showAsk: showAll, pairs, canUndo: shoes.canUndo })}
        </aside>
      </main>`;
    requestAnimationFrame(() => paintBoard(app.querySelector('.pane'), hands, { showAll, compact: false, tieStyle: prefs.tieStyle }));
  };

  bindBetPad(app, () => disposed ? null : myBetOpts());

  const record = o => {
    shoes.record(o, pairs.bp, pairs.pp);
    pairs.bp = pairs.pp = false;
    const hand = shoes.hands.at(-1);
    const round = T.settle(t(), hand, shoes.hands.length, shoes.current.id, state.myID);
    t().hands = sharedHands();
    buzz();
    commit();
    splash({ hand, handNumber: shoes.hands.length, net: round.results.find(r => r.member === state.myID)?.net });
    if (prefs.speak) speak(handPhrase(hand));
  };

  const undo = () => {
    shoes.undo();
    T.undoRound(t(), shoes.hands.length + 1, shoes.current.id);
    t().hands = sharedHands();
    commit();
  };

  const newShoe = () => confirmBox({
    title: '新しいシューを始めますか？', message: 'いまのシューは「過去のシュー」に残ります。チップの残高はそのままです。',
    buttons: [{ label: '新しいシューを始める', run: () => { shoes.startNew(); pairs.bp = pairs.pp = false; t().hands = []; commit(); countForNudge(); } },
      { label: 'キャンセル', role: 'cancel' }],
  });

  const endTable = () => {
    const result = T.summary(t());
    const list = [result, ...pastResults()].slice(0, 10);
    store.set(RESULTS_KEY, list);
    if (online) hostEnd(state.code, result).catch(() => {});
    store.set(HOST_KEY, null);
    // そのテーブルの罫線は「過去のシュー」に回す
    if (shoes.hands.length && !shoes.isSample) shoes.startNew();
    dispose();
    live.forEach(s => s.close());
    openSummary(result, state.myID, () => { countForNudge(); api.pickMode(); });
  };

  const editMember = id => {
    const m = T.member(t(), id);
    if (!m) return;
    let draft = { ...(t().bets[id] || {}) };
    const opts = () => {
      const tb = t(), mm = T.member(tb, id);
      return mm && {
        spots: draft, balance: mm.balance, commission: tb.bankerCommission, previous: T.lastRound(tb)?.bets[id],
        minBet: tb.minBet, maxBet: tb.maxBet, startingChips: tb.startingChips, closed: tb.betsClosed,
        onChange: s => { draft = s; sheet.update(); },
      };
    };
    const sheet = openSheet({
      title: `${m.name}のベット`,
      render: () => {
        const o = opts();
        if (!o) return '<p class="muted">この人はもういません。</p>';
        const asked = t().rebuyRequests.includes(id);
        return `<button class="${asked ? 'warn-btn' : 'secondary'} wide" data-act="rebuy">${asked ? '追加する（お願いが来ています）' : 'ポイントを追加する（リバイ）'}</button>
          <div class="deck-card">${betPadHTML(o)}</div>
          <p class="muted small">TIE のときは、BANKER と PLAYER へのベットはそのまま戻り、次の手にも残ります。${t().bankerCommission ? 'BANKER の勝ちは手数料5%を引いて、1 pt 未満は切り捨てます。' : ''}</p>
          <button class="primary wide" data-act="save" ${t().betsClosed ? 'disabled' : ''}>決める</button>`;
      },
      bind: (el, close) => {
        if (!el.dataset.bound) { bindBetPad(el, opts); el.dataset.bound = '1'; }
        el.onclick = e => {
          const b = e.target.closest('[data-act]');
          if (!b || b.disabled) return;
          if (b.dataset.act === 'rebuy') { close(); startRebuy(T.member(t(), id)); }
          if (b.dataset.act === 'save') { close(); placeBet(draft, id); }
        };
      },
    });
  };

  const manage = () => {
    let limits = null;
    const sheet = openSheet({
      title: t().name,
      wide: true,
      render: () => {
        const tb = t();
        const me = T.member(tb, state.myID);
        return `<div class="manage">
          <div class="manage-actions">
            <button class="danger" data-act="end">${icon('door', 15)}終了する</button>
            <button class="secondary" data-act="restart">${icon('undo', 15)}持ち点に戻す</button>
            <button class="secondary" data-act="give">${icon('swap', 15)}渡す</button>
          </div>
          ${me ? `<section class="card-box kv"><div><span>あなた</span><b class="num">${fmt(me.balance)} pt</b></div></section>` : ''}
          ${online ? `<section class="card-box"><h4>参加</h4>
            <button class="toggle-row" data-act="open" role="switch" aria-checked="${state.open}"><span><b>新しい人が参加できる</b><small>オフにすると、いまいる人だけで続けます</small></span><i class="switch"></i></button>
            ${state.open ? `<div class="kv"><div><span>参加番号</span><b class="code num">${esc(state.code)}</b></div></div>
              <p class="muted small">参加する人は「テーブルに参加する」でこの番号を入れます。この画面を開いたままにしてください。</p>` : ''}</section>` : ''}
          <section class="card-box"><h4>ベット（1か所あたり）</h4>
            ${limits ? `${limitPickerHTML(limits, tb.startingChips)}<div class="row-btns"><button class="secondary" data-act="limits-cancel">やめる</button><button class="primary" data-act="limits-save">変える</button></div>`
              : `<div class="kv"><div><span>下限</span><b class="num">${tb.minBet ? `${fmt(tb.minBet)} pt` : 'なし'}</b></div><div><span>上限</span><b class="num">${tb.maxBet ? `${fmt(tb.maxBet)} pt` : 'なし'}</b></div></div>
              <button class="link" data-act="limits">下限・上限を変える</button>`}
            <p class="muted small">BANKER・PLAYER・TIE・B PAIR・P PAIR のそれぞれに入れられる額です。変えると、外れたベットは消えます。</p></section>
          <section class="card-box"><h4>参加者</h4>
            <ul class="people">${tb.members.map(m => `<li><b>${esc(m.name)}</b>${m.id === state.myID ? '<small class="muted">あなた</small>' : ''}<span class="grow"></span>
              <span class="num">${fmt(m.balance)} pt</span><button class="del" data-act="remove" data-id="${esc(m.id)}">外す</button></li>`).join('')}</ul>
            <button class="link" data-act="add">${icon('plus', 14)} 参加者を足す</button></section>
          <section class="card-box"><h4>履歴</h4>
            ${tb.moves.length ? `<ul class="moves">${tb.moves.slice(-80).reverse().map(mv => moveRowHTML(tb, mv)).join('')}</ul>` : '<p class="muted">まだ動きはありません。</p>'}</section>
        </div>`;
      },
      bind: (el, close, update) => {
        el.oninput = e => { const k = e.target.dataset.limit; if (k && limits) limits[k] = toInt(e.target.value); };
        el.onclick = e => {
          const b = e.target.closest('button');
          if (!b || b.disabled) return;
          if (b.dataset.preset && limits) { limits.preset = b.dataset.preset; return update(); }
          switch (b.dataset.act) {
            case 'end': return confirmBox({ title: 'テーブルを終了しますか？', message: '全員の画面に結果が出て、テーブルは閉じます。結果はこの端末に残ります。',
              buttons: [{ label: '終了する', role: 'destructive', run: endTable }, { label: 'キャンセル', role: 'cancel' }] });
            case 'restart': return confirmBox({ title: '全員を持ち点に戻して、履歴を消しますか？',
              buttons: [{ label: '持ち点に戻す', role: 'destructive', run: () => { T.restart(t()); commit(); } }, { label: 'キャンセル', role: 'cancel' }] });
            case 'give': return giveSheet();
            case 'open': state.open = !state.open; return commit();
            case 'limits': limits = limitStateFrom(t()); return update();
            case 'limits-cancel': limits = null; return update();
            case 'limits-save': {
              const [lo, hi] = chosenLimits(limits, t().startingChips);
              if (hi > 0 && lo > hi) return toast('上限は下限より大きくしてください。');
              T.setLimits(t(), lo, hi); limits = null; return commit();
            }
            case 'add': return addMember();
            case 'remove': {
              const m = T.member(t(), b.dataset.id);
              return confirmBox({ title: `${m.name}さんを外しますか？`, message: '残高は場に戻ります。',
                buttons: [{ label: '外す', role: 'destructive', run: () => { T.removeMember(t(), m.id, state.myID); commit(); } }, { label: 'キャンセル', role: 'cancel' }] });
            }
          }
        };
      },
    });
    live.add(sheet);
  };

  const giveSheet = () => {
    const tb = t();
    if (tb.members.length < 2) return toast('渡すには、参加者が2人以上いります。');
    const g = { from: (T.member(tb, state.myID) || tb.members[0]).id, to: tb.members.find(m => m.id !== (T.member(tb, state.myID) || tb.members[0]).id).id, amount: '' };
    openSheet({
      title: '渡す',
      render: () => {
        const opts = sel => t().members.map(m => `<option value="${esc(m.id)}" ${m.id === sel ? 'selected' : ''}>${esc(m.name)}（使える ${fmt(T.available(t(), m.id))}）</option>`).join('');
        return `<form class="ask-form">
          <label class="field"><span>渡す人</span><select name="from">${opts(g.from)}</select></label>
          <label class="field"><span>もらう人</span><select name="to">${opts(g.to)}</select></label>
          <label class="field"><span>pt</span><input name="amount" inputmode="numeric" value="${esc(g.amount)}" placeholder="100"></label>
          <button class="primary" type="submit">渡す</button></form>`;
      },
      bind: (el, close) => {
        const f = el.querySelector('form');
        f.onsubmit = e => {
          e.preventDefault();
          const problem = T.transfer(t(), f.from.value, f.to.value, toInt(f.amount.value), state.myID);
          if (problem) return toast(problem);
          close(); commit();
        };
      },
    });
  };

  const viewMenu = anchor => openMenu(anchor, [
    { heading: '大路のタイの印' },
    { label: 'まる', checked: prefs.tieStyle === 'dot', run: () => { prefs.tieStyle = 'dot'; render(); } },
    { label: '斜線', checked: prefs.tieStyle === 'slash', run: () => { prefs.tieStyle = 'slash'; render(); } },
    { heading: '表示' },
    { label: '珠盤路・下三路・問路も見る', checked: prefs.showAll, run: () => { prefs.showAll = !prefs.showAll; render(); } },
    { label: '結果を英語で読み上げる', checked: prefs.speak, run: () => { prefs.speak = !prefs.speak; } },
  ]);
  const shoeMenu = anchor => openMenu(anchor, [
    { label: '新しいシューを始める', run: newShoe },
    { label: '過去のシュー', run: () => openHistory({ tieStyle: prefs.tieStyle }) },
  ]);

  app.oninput = null;
  app.onclick = e => {
    const b = e.target.closest('[data-action]');
    if (!b || b.disabled) return;
    switch (b.dataset.action) {
      case 'mode': return leaveToPicker();
      case 'rules': return openRules();
      case 'tips': return openTips();
      case 'manage': return manage();
      case 'view': return viewMenu(b);
      case 'shoe': return shoeMenu(b);
      case 'toggle-all': prefs.showAll = !prefs.showAll; return render();
      case 'close-bets': t().betsClosed = true; commit(); return noMoreBets(prefs.speak);
      case 'edit-member': return editMember(b.dataset.id);
      case 'rebuy': { const m = T.member(t(), b.dataset.id); return m && startRebuy(m); }
      case 'add-member': return addMember();
      case 'pair': pairs[b.dataset.pair] = !pairs[b.dataset.pair]; buzz(); return render();
      case 'undo': return undo();
      case 'result': return record(b.dataset.o);
    }
  };

  const dispose = () => {
    disposed = true;
    stopPlayers?.();
    clearTimeout(publishTimer);
  };

  api.setScreen({
    render,
    dispose,
    // 「使い方」で離れるときは、テーブルを終えるか確かめる
    confirmLeave: go => confirmBox({
      title: 'テーブルを終了しますか？', message: '全員の画面に結果が出て、テーブルは閉じます。',
      buttons: [{ label: '終了する', role: 'destructive', run: endTable }, { label: 'キャンセル', role: 'cancel' }],
    }),
  });
  t().hands = sharedHands();
  commit();
}

export { myUid };
