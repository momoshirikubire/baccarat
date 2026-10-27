// いまのシューと過去のシュー（アプリの Store/ShoeStore.swift）。この端末のブラウザにだけ保存する。
import { sampleHands } from './model.js';
import { store } from './ui.js';

const KEY = 'bn.shoes';
const OLD_KEY = 'baccarat-roads-v1'; // 前のブラウザ版

const newShoe = (hands = []) => ({ id: crypto.randomUUID?.() || String(Date.now()), startedAt: Date.now(), hands });

function load() {
  const saved = store.get(KEY, null);
  if (saved?.current) return saved;
  const old = store.get(OLD_KEY, null);
  if (old?.hands?.length && !old.sample) {
    return { current: newShoe(old.hands.map(h => ({ o: h.r, bp: !!h.bp, pp: !!h.pp }))), past: [], isSample: false };
  }
  return { current: newShoe(sampleHands()), past: [], isSample: true };
}

export const shoes = {
  ...load(),
  save() { store.set(KEY, { current: this.current, past: this.past, isSample: this.isSample }); },
  get hands() { return this.current.hands; },
  get canUndo() { return !this.isSample && this.current.hands.length > 0; },
  record(o, bp, pp) {
    // 例のシューは、1手目を記録したら消して記録を始める
    if (this.isSample) { this.current = newShoe(); this.isSample = false; }
    this.current.hands.push({ o, bp: !!bp, pp: !!pp });
    this.save();
  },
  undo() {
    if (!this.canUndo) return;
    this.current.hands.pop();
    this.save();
  },
  startNew() {
    if (!this.isSample && this.current.hands.length) this.past.unshift(this.current);
    this.current = newShoe();
    this.isSample = false;
    this.save();
  },
  deletePast(id) {
    this.past = this.past.filter(s => s.id !== id);
    this.save();
  },
};
