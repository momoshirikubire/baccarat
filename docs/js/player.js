// プレイヤーの画面（アプリの Views/Chips/PlayerView.swift）。
// 親から聞いた4桁の番号でテーブルに入り、自分の分だけベットする。勝敗は親が入れる。左に親と同じ罫線（見るだけ）。
import * as T from './table.js';
import { statusPill, memberCard, betPadHTML, bindBetPad, noMoreBets, openSummary, settlementLine, moveRowHTML, toInt } from './chipui.js';
import { boardHTML, paintBoard, isLandscape } from './board.js';
import { openRules, openTips } from './sheets.js';
import { prefs, modeButton, leaveToPicker, countForNudge } from './app.js';
import { netAvailable, findTable, guestWrite, guestListen, myUid } from './net.js';
import { tbtn, icon, openMenu, openSheet, confirmBox, toast, splash, speak, handPhrase, buzz, store, esc, fmt } from './ui.js';

const GUEST_KEY = 'bn.guest';

export function playerScreen(api) {
  const saved = store.get(GUEST_KEY, null);
  joinScreen(api, saved);
}

// ---- 参加する（PlayerJoinView） ----
function joinScreen(api, saved) {
  const { app } = api;
  let name = store.get('bn.myName', '');
  let code = saved?.code || '';
  let busy = false;

  const render = () => {
    app.innerHTML = `
      <header class="toolbar"><div class="tb-left">${modeButton()}</div><b class="tb-center">テーブルに参加</b><div class="tb-right"></div></header>
      <main class="join"><form class="join-card">
        ${netAvailable() ? `
        <label class="field col"><span>あなたの名前</span><input name="name" value="${esc(name)}" placeholder="みんなの画面に出る名前" maxlength="20" autocomplete="nickname"></label>
        <label class="field col"><span>参加番号（4桁）</span><input name="code" class="code-input num" value="${esc(code)}" inputmode="numeric" maxlength="4" placeholder="0000" autocomplete="off"></label>
        <button class="primary big" type="submit" ${busy ? 'disabled' : ''}>${busy ? '参加しています…' : '参加する'}</button>
        <p class="muted small">テーブルを作った人の画面の左上に出ている4桁の番号を入れます。インターネットにつながっている必要があります。前に参加したテーブルなら、残りの pt から続けられます。</p>`
        : `<p><b>テーブルに参加する機能は、いま準備中です。</b></p><p class="muted small">親の1台だけで使うときは「テーブルを作る」で、参加者を親が足してください。</p>`}
      </form></main>`;
  };

  app.oninput = e => {
    if (e.target.name === 'name') name = e.target.value;
    if (e.target.name === 'code') { code = e.target.value.replace(/\D/g, '').slice(0, 4); e.target.value = code; }
  };
  app.onclick = e => { if (e.target.closest('[data-action="mode"]')) leaveToPicker(); };
  app.onsubmit = async e => {
    e.preventDefault();
    if (busy) return;
    if (!name.trim()) return toast('名前を入れてください。');
    if (code.length !== 4) return toast('4桁の参加番号を入れてください。');
    busy = true; render();
    try {
      const found = await findTable(code);
      const uid = await myUid();
      if (!found) throw new Error('この番号のテーブルは見つかりません。親の画面の番号を確かめてください。');
      if (!found.open && !T.member(found.table, uid)) throw new Error('このテーブルは、いま新しい人が参加できません。');
      store.set('bn.myName', name.trim());
      await guestWrite(code, { name: name.trim(), tableId: found.table.id, joinedAt: Date.now(), left: false });
      store.set(GUEST_KEY, { code, tableId: found.table.id });
      tableScreen(api, { code, tableId: found.table.id, uid });
    } catch (err) {
      busy = false; render();
      toast(err.message || '参加できませんでした。');
    }
  };

  api.setScreen({ render, dispose: () => { app.onsubmit = null; } });
}

// ---- 参加中（PlayerTableView） ----
function tableScreen(api, { code, tableId, uid }) {
  const { app } = api;
  let table = null;
  let draft = {};
  let pendingAt = 0;       // 送ったベットの時刻（親が確かめるまで手元のベットを見せる）
  let giveAt = 0;
  let shownRound = null;   // 最後に大きく出した精算
  let lastClosed = null;
  let disposed = false, stop = null, joinTimer = null, retryTimer = null;
  const live = new Set();

  const me = () => table && T.member(table, uid);

  const leave = (summary, message) => {
    if (disposed) return;
    dispose();
    store.set(GUEST_KEY, null);
    live.forEach(s => s.close());
    if (summary) openSummary(summary, uid, () => { countForNudge(); api.pickMode(); });
    else { if (message) toast(message); joinScreen(api, null); }
  };

  const onTable = d => {
    if (disposed) return;
    if (!d || !d.table || d.table.id !== tableId) {
      if (d?.ended) return leave(d.ended);
      return leave(null, 'テーブルが閉じられました。');
    }
    if (d.ended) return leave(d.ended);
    const prev = table;
    table = d.table;
    const mine = me();
    if (!mine) {
      // 親が入れてくれるのを待つ（ずっと入れないときは戻る）
      if (prev && T.member(prev, uid)) return leave(null, '親がテーブルから外しました。');
      joinTimer ||= setTimeout(() => { if (!me()) leave(null, '参加できませんでした。親の画面が開いているか確かめてください。'); }, 15000);
      // 親が見落としたときのために、少ししたらもう一度知らせる
      retryTimer ||= setTimeout(() => { if (!me() && !disposed) guestWrite(code, { joinedAt: Date.now() }).catch(() => {}); }, 3000);
      return render();
    }
    clearTimeout(joinTimer);
    const ack = table.acks?.[uid];
    // 親が確かめたら、親の持っているベットに合わせる（断られたら理由を出す）
    if (pendingAt && ack?.at >= pendingAt) {
      if (ack.error) toast(ack.error);
      pendingAt = 0;
    }
    if (giveAt && ack?.giveAt >= giveAt) {
      toast(ack.giveError || '渡しました。');
      giveAt = 0;
    }
    if (!pendingAt) draft = { ...(table.bets[uid] || {}) };

    const round = T.lastRound(table);
    if (prev === null) {
      shownRound = round?.id ?? null;
      lastClosed = table.betsClosed;
    } else {
      // 新しく精算されたら、大きく出して読み上げる（親が「1つ戻す」で前の手に戻ったときは出さない）
      const isNew = round && round.id !== shownRound && !(prev.rounds || []).some(r => r.id === round.id);
      if (isNew) {
        shownRound = round.id;
        pendingAt = 0;
        draft = { ...(table.bets[uid] || {}) };
        buzz();
        splash({ hand: round.hand, handNumber: round.handNumber, net: round.results.find(r => r.member === uid)?.net });
        if (prefs.speak) speak(handPhrase(round.hand));
      } else if (table.betsClosed && !lastClosed && table.settledHands >= (prev.settledHands || 0)) {
        noMoreBets(prefs.speak);
      }
      lastClosed = table.betsClosed;
    }
    render();
    live.forEach(s => s.closed ? live.delete(s) : s.update());
  };

  guestListen(code, onTable, () => toast('つながりが切れました。電波を確かめてください。'))
    .then(s => { if (disposed) s(); else stop = s; });

  const betOpts = () => {
    const m = me();
    if (!m || disposed) return null;
    return {
      spots: draft, balance: m.balance, commission: table.bankerCommission, previous: T.lastRound(table)?.bets[uid],
      minBet: table.minBet, maxBet: table.maxBet, startingChips: table.startingChips, closed: table.betsClosed,
      compact: needsRebuy(),
      onChange: spots => {
        const problem = T.betProblem(table, spots, uid);
        if (problem) return toast(problem);
        draft = spots;
        pendingAt = Date.now();
        guestWrite(code, { bet: JSON.stringify(spots), betAt: pendingAt }).catch(() => toast('送れませんでした。電波を確かめてください。'));
        render();
      },
    };
  };
  bindBetPad(app, betOpts);

  const needsRebuy = () => {
    const m = me();
    return m && m.balance - T.betSum(draft) < Math.max(1, table.minBet);
  };

  const band = () => {
    const last = T.lastRound(table);
    const members = [...table.members.filter(m => m.id === uid), ...table.members.filter(m => m.id !== uid)];
    return `<div class="band"><div class="band-members">${statusPill(table.betsClosed)}
      ${members.map(m => memberCard(table, m, { isMe: m.id === uid, lastNet: last?.results.find(r => r.member === m.id)?.net ?? null })).join('')}</div></div>`;
  };

  const render = () => {
    if (disposed) return;
    const land = isLandscape();
    const m = me();
    if (!table || !m) {
      app.innerHTML = `<header class="toolbar"><div class="tb-left">${modeButton()}</div></header>
        <main class="join"><div class="join-card"><p><b>参加しています…</b></p><p class="muted small">親の画面が開いているあいだに入れます。</p></div></main>`;
      return;
    }
    const showAll = prefs.showAll;
    const hands = table.hands || [];
    const asked = table.rebuyRequests.includes(uid);
    app.innerHTML = `
      <header class="toolbar">
        <div class="tb-left">${modeButton()}${tbtn('rules', 'book', 'ルール')}<b class="tb-title">${hands.length} 手</b></div>
        <div class="tb-right">${tbtn('manage', 'users', 'テーブル')}${tbtn('view', 'sliders', '表示')}${tbtn('tips', 'gift', '応援')}</div>
      </header>
      ${band()}
      <main class="screen ${land ? 'side' : 'stack'}">
        <div class="pane">${boardHTML(hands, { showAll, compact: false })}</div>
        <aside class="deck-wrap player" style="${land ? 'width:340px' : ''}">
          ${needsRebuy() ? `<button class="warn-btn wide" data-action="ask-rebuy" ${asked ? 'disabled' : ''}>${asked ? '追加をお願いしました' : '親に追加をお願いする'}</button>` : ''}
          ${betPadHTML(betOpts())}
          ${settlementLine(T.lastRound(table), uid)}
        </aside>
      </main>`;
    requestAnimationFrame(() => paintBoard(app.querySelector('.pane'), hands, { showAll, compact: false, tieStyle: prefs.tieStyle }));
  };

  const manage = () => {
    const sheet = openSheet({
      title: table.name,
      wide: true,
      render: () => {
        const m = me();
        if (!m) return '';
        return `<div class="manage">
          <div class="manage-actions">
            <button class="danger" data-act="leave">${icon('door', 15)}テーブルから抜ける</button>
            <button class="secondary" data-act="give">${icon('swap', 15)}渡す</button>
          </div>
          <section class="card-box kv"><div><span>あなた</span><b class="num">${fmt(m.balance)} pt</b></div><div><span>参加番号</span><b class="num">${esc(code)}</b></div></section>
          <section class="card-box"><h4>ベット（1か所あたり）</h4><div class="kv">
            <div><span>下限</span><b class="num">${table.minBet ? `${fmt(table.minBet)} pt` : 'なし'}</b></div>
            <div><span>上限</span><b class="num">${table.maxBet ? `${fmt(table.maxBet)} pt` : 'なし'}</b></div>
            <div><span>BANKER</span><b>${table.bankerCommission ? '0.95倍（手数料5%）' : '1倍'}</b></div></div></section>
          <section class="card-box"><h4>参加者</h4><ul class="people">${table.members.map(x => `<li><b>${esc(x.name)}</b>${x.id === uid ? '<small class="muted">あなた</small>' : ''}<span class="grow"></span><span class="num">${fmt(x.balance)} pt</span></li>`).join('')}</ul></section>
          <section class="card-box"><h4>履歴</h4>${table.moves.length ? `<ul class="moves">${table.moves.slice(-80).reverse().map(mv => moveRowHTML(table, mv)).join('')}</ul>` : '<p class="muted">まだ動きはありません。</p>'}</section>
        </div>`;
      },
      bind: (el, close) => {
        el.onclick = e => {
          const b = e.target.closest('[data-act]');
          if (!b) return;
          if (b.dataset.act === 'leave') confirmBox({
            title: 'テーブルから抜けますか？', message: 'いまの結果を出します。同じ番号でまた入ると、残りの pt から続けられます。',
            buttons: [{ label: '抜ける', role: 'destructive', run: leaveNow }, { label: 'キャンセル', role: 'cancel' }],
          });
          if (b.dataset.act === 'give') { close(); giveSheet(); }
        };
      },
    });
    live.add(sheet);
  };

  const giveSheet = () => {
    const others = table.members.filter(m => m.id !== uid);
    if (!others.length) return toast('渡せる人がいません。');
    openSheet({
      title: '渡す',
      render: () => `<form class="ask-form"><p class="muted">使える ${fmt(T.available(table, uid))} pt</p>
        <label class="field"><span>もらう人</span><select name="to">${others.map(m => `<option value="${esc(m.id)}">${esc(m.name)}</option>`).join('')}</select></label>
        <label class="field"><span>pt</span><input name="amount" inputmode="numeric" placeholder="100"></label>
        <button class="primary" type="submit">渡す</button></form>`,
      bind: (el, close) => {
        const f = el.querySelector('form');
        f.onsubmit = e => {
          e.preventDefault();
          const amount = toInt(f.amount.value);
          const problem = T.moveProblem(table, uid, f.to.value, amount);
          if (problem) return toast(problem);
          giveAt = Date.now();
          guestWrite(code, { give: { to: f.to.value, amount, at: giveAt } }).catch(() => toast('送れませんでした。'));
          close();
        };
      },
    });
  };

  const leaveNow = () => {
    const s = table && T.summary(table);
    guestWrite(code, { left: true }).catch(() => {});
    leave(s);
  };

  const viewMenu = anchor => openMenu(anchor, [
    { heading: '大路のタイの印' },
    { label: 'まる', checked: prefs.tieStyle === 'dot', run: () => { prefs.tieStyle = 'dot'; render(); } },
    { label: '斜線', checked: prefs.tieStyle === 'slash', run: () => { prefs.tieStyle = 'slash'; render(); } },
    { heading: '表示' },
    { label: '珠盤路・下三路も見る', checked: prefs.showAll, run: () => { prefs.showAll = !prefs.showAll; render(); } },
    { label: '結果を英語で読み上げる', checked: prefs.speak, run: () => { prefs.speak = !prefs.speak; } },
  ]);

  app.oninput = null;
  app.onsubmit = null;
  app.onclick = e => {
    const b = e.target.closest('[data-action]');
    if (!b || b.disabled) return;
    switch (b.dataset.action) {
      case 'mode': return leaveToPicker();
      case 'rules': return openRules();
      case 'tips': return openTips();
      case 'manage': return table && manage();
      case 'view': return viewMenu(b);
      case 'toggle-all': prefs.showAll = !prefs.showAll; return render();
      case 'ask-rebuy': guestWrite(code, { rebuyAt: Date.now() }).catch(() => {}); return toast('親にお願いしました。');
    }
  };

  const dispose = () => {
    disposed = true;
    stop?.();
    clearTimeout(joinTimer);
    clearTimeout(retryTimer);
  };

  api.setScreen({
    render, dispose,
    confirmLeave: () => confirmBox({
      title: 'テーブルから抜けますか？', message: 'いまの結果を出します。同じ番号でまた入ると、残りの pt から続けられます。',
      buttons: [{ label: '抜ける', role: 'destructive', run: leaveNow }, { label: 'キャンセル', role: 'cancel' }],
    }),
  });
}
