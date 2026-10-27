// テーブルをみんなで使うためのつなぎ（アプリの MultipeerConnectivity の代わり）。
// Firebase の Firestore に、親が tables/{4桁の番号} へテーブルを書き、プレイヤーは tables/{番号}/players/{自分} にだけ書く。
// 親がプレイヤーの書いたベットを確かめてからテーブルに入れ、全員に配る（アプリと同じく親が正）。
//
// Firebase の設定がないときは使えない（テーブルは親の1台だけで使う）。
// ?local をつけて開くと、同じブラウザの別のタブどうしでつなぐ（試すとき用）。
import { FIREBASE } from './config.js';

const SDK = 'https://www.gstatic.com/firebasejs/11.0.2';
const STALE = 12 * 3600e3; // 12時間さわられていない番号は、ほかのテーブルが使ってよい

let backend = null;

export const netAvailable = () => !!FIREBASE || new URLSearchParams(location.search).has('local');

async function getBackend() {
  if (backend) return backend;
  if (FIREBASE) backend = await firebaseBackend();
  else if (new URLSearchParams(location.search).has('local')) backend = localBackend();
  else throw new Error('テーブルの通信はまだ準備中です。');
  return backend;
}

// ---- Firebase ----
async function firebaseBackend() {
  const [{ initializeApp }, auth, fs] = await Promise.all([
    import(`${SDK}/firebase-app.js`), import(`${SDK}/firebase-auth.js`), import(`${SDK}/firebase-firestore.js`)]);
  const app = initializeApp(FIREBASE);
  const a = auth.getAuth(app);
  const db = fs.getFirestore(app);
  const user = a.currentUser || await new Promise((resolve, reject) => {
    const stop = auth.onAuthStateChanged(a, u => { if (u) { stop(); resolve(u); } });
    auth.signInAnonymously(a).catch(reject);
  });
  const tableRef = code => fs.doc(db, 'tables', code);
  const playerRef = (code, uid) => fs.doc(db, 'tables', code, 'players', uid);
  return {
    uid: user.uid,
    async claim(code) {
      return fs.runTransaction(db, async tx => {
        const snap = await tx.get(tableRef(code));
        const d = snap.data();
        if (snap.exists() && d.hostUid !== user.uid && Date.now() - (d.touchedAt || 0) < STALE) return false;
        tx.set(tableRef(code), { hostUid: user.uid, touchedAt: Date.now(), open: true, state: '', ended: '' });
        return true;
      });
    },
    async getTable(code) { const s = await fs.getDoc(tableRef(code)); return s.exists() ? s.data() : null; },
    setTable(code, data) { return fs.updateDoc(tableRef(code), { ...data, touchedAt: Date.now() }); },
    deleteTable(code) { return fs.deleteDoc(tableRef(code)); },
    listenTable(code, cb, onError) {
      return fs.onSnapshot(tableRef(code), s => cb(s.exists() ? s.data() : null), onError);
    },
    setPlayer(code, data) { return fs.setDoc(playerRef(code, user.uid), data, { merge: true }); },
    listenPlayers(code, tableId, cb, onError) {
      const q = fs.query(fs.collection(db, 'tables', code, 'players'), fs.where('tableId', '==', tableId));
      return fs.onSnapshot(q, s => cb(s.docs.map(d => ({ uid: d.id, ...d.data() }))), onError);
    },
  };
}

// ---- 同じブラウザのタブどうし（試すとき用） ----
function localBackend() {
  const ch = new BroadcastChannel('bn-local-net');
  let uid = sessionStorage.getItem('bn.localUid');
  if (!uid) { uid = `u${Math.random().toString(36).slice(2, 10)}`; sessionStorage.setItem('bn.localUid', uid); }
  const read = k => { try { return JSON.parse(localStorage.getItem(`bn.net.${k}`)); } catch { return null; } };
  const write = (k, v) => {
    if (v == null) localStorage.removeItem(`bn.net.${k}`); else localStorage.setItem(`bn.net.${k}`, JSON.stringify(v));
    ch.postMessage(k);
    queueMicrotask(() => listeners.forEach(l => l(k)));
  };
  const listeners = new Set();
  ch.onmessage = e => listeners.forEach(l => l(e.data));
  const listen = (match, fire) => {
    const l = k => { if (match(k)) fire(); };
    listeners.add(l);
    setTimeout(fire, 0);
    return () => listeners.delete(l);
  };
  const players = code => Object.keys(localStorage).filter(k => k.startsWith(`bn.net.p.${code}.`))
    .map(k => ({ uid: k.split('.').pop(), ...JSON.parse(localStorage.getItem(k)) }));
  return {
    uid,
    async claim(code) {
      const d = read(`t.${code}`);
      if (d && d.hostUid !== uid && Date.now() - (d.touchedAt || 0) < STALE) return false;
      write(`t.${code}`, { hostUid: uid, touchedAt: Date.now(), open: true, state: '', ended: '' });
      return true;
    },
    async getTable(code) { return read(`t.${code}`); },
    async setTable(code, data) { write(`t.${code}`, { ...read(`t.${code}`), ...data, touchedAt: Date.now() }); },
    async deleteTable(code) { write(`t.${code}`, null); },
    listenTable(code, cb) { return listen(k => k === `t.${code}`, () => cb(read(`t.${code}`))); },
    async setPlayer(code, data) { write(`p.${code}.${uid}`, { ...read(`p.${code}.${uid}`), ...data }); },
    listenPlayers(code, tableId, cb) {
      return listen(k => k.startsWith(`p.${code}.`), () => cb(players(code).filter(p => p.tableId === tableId)));
    },
  };
}

// ---- 親 ----
/** 空いている4桁の番号をとって、テーブルを置く。 */
export async function hostOpen(preferred) {
  const b = await getBackend();
  for (let i = 0; i < 12; i++) {
    const code = i === 0 && preferred ? preferred : String(Math.floor(Math.random() * 10000)).padStart(4, '0');
    if (await b.claim(code)) return { code, uid: b.uid };
  }
  throw new Error('参加番号をとれませんでした。もう一度ためしてください。');
}

export async function hostPublish(code, table, open) {
  const b = await getBackend();
  await b.setTable(code, { state: JSON.stringify(table), open });
}

export async function hostEnd(code, summary) {
  const b = await getBackend();
  await b.setTable(code, { ended: JSON.stringify(summary), open: false });
}

export async function hostListenPlayers(code, tableId, cb, onError) {
  const b = await getBackend();
  return b.listenPlayers(code, tableId, cb, onError);
}

export async function myUid() { return (await getBackend()).uid; }

// ---- プレイヤー ----
export async function findTable(code) {
  const b = await getBackend();
  const d = await b.getTable(code);
  if (!d || !d.state || d.ended) return null;
  return { ...d, table: JSON.parse(d.state) };
}

export async function guestWrite(code, data) {
  const b = await getBackend();
  await b.setPlayer(code, data);
}

export async function guestListen(code, cb, onError) {
  const b = await getBackend();
  return b.listenTable(code, d => cb(d && {
    open: d.open, hostUid: d.hostUid,
    table: d.state ? JSON.parse(d.state) : null,
    ended: d.ended ? JSON.parse(d.ended) : null,
  }), onError);
}
