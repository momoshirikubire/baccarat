// 画面の切り替え（アプリの RootView・ModePickerView）と罫線だけの画面（RoadGameView）
import { boardHTML, paintBoard, deckHTML, isLandscape } from './board.js';
import { shoes } from './shoes.js';
import { openRules, openTips, openHistory } from './sheets.js';
import { tbtn, icon, openMenu, confirmBox, splash, speak, handPhrase, buzz, store, esc } from './ui.js';

const app = document.getElementById('app');

// ---- 表示の設定（アプリの @AppStorage） ----
export const prefs = {
  get showAll() { return store.get('bn.showAll', false); },
  set showAll(v) { store.set('bn.showAll', v); },
  get tieStyle() { return store.get('bn.tieStyle', 'dot'); },
  set tieStyle(v) { store.set('bn.tieStyle', v); },
  get announce() { return store.get('bn.announce', true); },
  set announce(v) { store.set('bn.announce', v); },
};

// ---- 応援のお願い（TipNudge）：新しいシュー・テーブルを終えたときを数え、2回ごとに出す ----
export function countForNudge() {
  const n = store.get('bn.newShoeCount', 0) + 1;
  store.set('bn.newShoeCount', n);
  const tipped = store.get('bn.tippedAt', 0);
  if (n % 2 !== 0 || Date.now() - tipped < 365 * 864e5) return;
  setTimeout(() => confirmBox({
    title: '応援してもらえませんか？',
    message: '広告なしで続けるために、応援をお願いしています。応援しなくても、すべての機能を使えます。',
    buttons: [{ label: '応援を見る', run: openTips }, { label: 'あとで', role: 'cancel' }],
  }), 500);
}

// ---- 使い方（AppMode） ----
const MODES = {
  roads: () => roadsScreen(),
  dealer: () => import('./dealer.js').then(m => m.dealerScreen(screenAPI)),
  player: () => import('./player.js').then(m => m.playerScreen(screenAPI)),
};
let current = null; // { render, dispose, canLeave }

export const screenAPI = {
  app,
  pickMode: () => showPicker(),
  setScreen,
};

function setScreen(screen) {
  current?.dispose?.();
  current = screen;
  screen.render();
}

function start(mode) {
  store.set('bn.mode', mode);
  MODES[mode]();
}

/** 左上の「使い方」。テーブルを持っている・参加しているときは、その画面が確かめてから閉じる。 */
export function modeButton() { return tbtn('mode', 'grid', '使い方'); }
export function leaveToPicker() {
  if (current?.confirmLeave) current.confirmLeave(() => showPicker());
  else showPicker();
}

function showPicker() {
  current?.dispose?.();
  current = { render: showPicker };
  const card = (mode, iconName, title, role, detail) => `<button class="mode-card" data-mode="${mode}">
    <span class="mode-icon">${icon(iconName, 26)}</span><b>${title}</b>${role ? `<em>${role}</em>` : ''}<span>${detail}</span></button>`;
  app.innerHTML = `<div class="picker"><div class="picker-inner">
    <h1>どう使いますか？</h1>
    <div class="mode-cards">
      ${card('roads', 'grid', '罫線だけ', '', '勝敗を入れて罫線を記録します。')}
      ${card('dealer', 'table', 'テーブルを作る', '勝敗を記録する親になる', '勝敗を入れると、みんなのベットを pt で精算します。自分もベットできます。')}
      ${card('player', 'users', 'テーブルに参加する', 'プレイヤーとしてベットする', '親から聞いた4桁の番号で入って、自分のスマホでベットします。')}
    </div>
    <p class="muted small">あとから画面の左上の「使い方」で変えられます。チップは pt で数える遊び用の記録で、お金には換えられません。</p>
  </div></div>`;
  app.onclick = e => {
    const b = e.target.closest('[data-mode]');
    if (b) start(b.dataset.mode);
  };
}

// ---- 罫線だけの画面 ----
function roadsScreen() {
  const pairs = { bp: false, pp: false };

  const render = () => {
    const land = isLandscape();
    const { showAll } = prefs;
    const hands = shoes.hands;
    const compact = land && !showAll;
    const title = `${hands.length} 手`;
    app.innerHTML = `
      <header class="toolbar">
        <div class="tb-left">${modeButton()}${tbtn('history', 'history', '履歴')}${tbtn('rules', 'book', 'ルール')}${land ? `<b class="tb-title">${title}</b>` : ''}</div>
        ${land ? '' : `<b class="tb-center">${title}</b>`}
        <div class="tb-right">${tbtn('view', 'sliders', '表示')}${tbtn('new-shoe', 'plus', '新しいシュー')}${tbtn('tips', 'gift', '応援')}</div>
      </header>
      <main class="screen ${land ? 'side' : 'stack'}">
        <div class="pane">${boardHTML(hands, { showAll, compact, note: shoes.isSample ? 'いま表示しているのは例のシューです。1手目を記録すると消えて、あなたの記録が始まります。' : '' })}</div>
        <aside class="deck-wrap" style="${land ? `width:${compact ? 200 : 300}px` : ''}">
          ${deckHTML(hands, { narrow: compact, showAsk: showAll, pairs, canUndo: shoes.canUndo, sampleNote: compact && shoes.isSample })}
        </aside>
      </main>`;
    requestAnimationFrame(() => paintBoard(app.querySelector('.pane'), hands, { showAll, compact, tieStyle: prefs.tieStyle }));
  };

  const viewMenu = anchor => openMenu(anchor, [
    { heading: '大路のタイの印' },
    { label: 'まる', checked: prefs.tieStyle === 'dot', run: () => { prefs.tieStyle = 'dot'; render(); } },
    { label: '斜線', checked: prefs.tieStyle === 'slash', run: () => { prefs.tieStyle = 'slash'; render(); } },
    { heading: '表示' },
    { label: '珠盤路・下三路・問路も見る', checked: prefs.showAll, run: () => { prefs.showAll = !prefs.showAll; render(); } },
    { label: '結果を大きく出して読み上げる', checked: prefs.announce, run: () => { prefs.announce = !prefs.announce; } },
  ]);

  const newShoe = () => confirmBox({
    title: '新しいシューを始めますか？',
    message: shoes.isSample || !shoes.hands.length ? '空の罫線から記録を始めます。' : 'いまのシューは「過去のシュー」に残ります。',
    buttons: [
      { label: '新しいシューを始める', run: () => { shoes.startNew(); pairs.bp = pairs.pp = false; render(); countForNudge(); } },
      { label: 'キャンセル', role: 'cancel' }],
  });

  app.onclick = e => {
    const b = e.target.closest('[data-action]');
    if (!b || b.disabled) return;
    switch (b.dataset.action) {
      case 'mode': return leaveToPicker();
      case 'history': return openHistory({ tieStyle: prefs.tieStyle });
      case 'rules': return openRules();
      case 'tips': return openTips();
      case 'view': return viewMenu(b);
      case 'new-shoe': return newShoe();
      case 'toggle-all': prefs.showAll = !prefs.showAll; return render();
      case 'pair': pairs[b.dataset.pair] = !pairs[b.dataset.pair]; buzz(); return render();
      case 'undo': shoes.undo(); buzz(); return render();
      case 'result': {
        shoes.record(b.dataset.o, pairs.bp, pairs.pp);
        pairs.bp = pairs.pp = false;
        buzz();
        render();
        if (prefs.announce) {
          const hand = shoes.hands.at(-1);
          splash({ hand, handNumber: shoes.hands.length });
          speak(handPhrase(hand));
        }
      }
    }
  };

  setScreen({ render });
}

// ---- 起動 ----
let resizeTimer;
addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => current?.render(), 120);
});

const saved = store.get('bn.mode', null);
// テーブルは開き直すと入り直しになるので、罫線だけのとき以外は使い方の選択から始める
if (saved === 'roads') start('roads');
else showPicker();

if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js');
