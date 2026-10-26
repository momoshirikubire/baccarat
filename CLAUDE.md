# 罫線ノート — 広告なしのバカラ罫線アプリ

- ユーザーへの返答は**必ず日本語**で。
- ユーザーが自分で使うために作った、広告のないバカラ罫線の記録アプリ。App Store で公開する。
- 収益は広告ではなく「応援（チップ）」の消耗型アプリ内課金だけ。チップを買っても機能は変わらない。外部の寄付リンクは置かない（App Store の規約で、デジタルのチップはアプリ内課金にする必要がある）。
- 勝ちを保証するような表現（「必勝」「予想が当たる」など）はアプリにも説明文にも書かない。審査で賭博アプリと見なされないよう、あくまで「記録」として説明する。

## 技術
- SwiftUI、iOS 17 以降、Swift 5 モード。外部ライブラリなし。
- プロジェクトは `Keisen.xcodeproj`（スキーム `Keisen`）、ソースは `Keisen/`。Xcode の「フォルダ同期グループ」なので、ファイルを置くだけでビルド対象になる。
- 表示名は「罫線ノート」、バンドルIDは `com.tadahonami.keisen`。署名チームは pbxproj に入れていないので、Xcode の Signing & Capabilities でチームを選ぶ（または xcodebuild に `DEVELOPMENT_TEAM=...` を渡す）。
- `Keisen/Info.plist` には `ITSAppUsesNonExemptEncryption = NO` だけ。アプリアイコンはアルファなしの 1024px PNG。
- `Keisen/PrivacyInfo.xcprivacy`：データ収集なし、UserDefaults（チップ回数の保存）の理由 CA92.1。
- `Keisen.storekit`：チップのテスト用設定。スキームの Run → Options → StoreKit Configuration で選ぶとシミュレータで買える。

## フォルダ構成
- 画面は5つのタブ：バカラ / ドラゴンタイガー / ブラックジャック / ポーカー / 点数表（`App/KeisenApp.swift`）。どの画面も右上のハートから応援画面を開ける（`.tipButton()`）。
- `Keisen/Models/Hand.swift`：結果（B / P / T）、ペア、シュー、初回に見せる例のシュー。`RoadGame` でバカラとドラゴンタイガーの呼び名を切り替える（ドラゴン＝バンカーの位置、タイガー＝プレイヤーの位置。罫線の計算は同じ）。
- `Keisen/Models/Roads.swift`：罫線の計算。大路（タイは直前のマスに数で付ける、6段を超えたり下が埋まっていたら右へ曲がるドラゴンテール）、下三路（大眼仔・小路・曱甴路 = 1・2・3列前と比べる）、問路（次が B / P のときに付く印）。
- `Keisen/Store/ShoeStore.swift`：いまのシューと過去のシュー。ゲームごとに `Application Support/shoes.json`（バカラ）・`dragon-tiger.json` に保存。読み書きは `FileStore`。
- ブラックジャック（`Models/Blackjack.swift`・`BlackjackStore`・`Views/Blackjack/`）：勝ち・負け・引き分け・BJ（+1.5）・降参（−0.5）・ダブル（×2）を1ベット単位で記録し、収支のグラフ（Swift Charts）と過去のセッション。Hi-Lo カウントの練習（アプリ内で配るカードだけを使う。実際のテーブルで使う道具にはしない）。
- ポーカー（`Models/Poker.swift`・`PokerStore`・`Views/Poker/`）：ホームゲームの参加者ごとのバイインと最後のチップ、受け渡しの少ない精算。ブラインドタイマー（終わる時刻を保存するのでアプリを閉じてもずれない。動いているあいだは画面を消さない）。
- 点数表（`ScoreStore`・`Views/Scores/`）：参加者×ラウンドの点数。
- 点数やチップはすべて「pt（ポイント）」で数え、「円」は使わない（日本では仲間内でもお金を賭けると賭博罪になるため）。
- `Keisen/Store/TipStore.swift`：StoreKit 2 のチップ。商品ID は `com.tadahonami.keisen.tip.small / medium / large / huge`（消耗型。¥300 / ¥1,000 / ¥2,000 / ¥5,000）。
- `Keisen/Views/`：罫線画面と入力盤（`RoadGameView`）、罫線の描画（`RoadViews`、Canvas）、過去のシュー、応援画面。
- `docs/`：ブラウザ版（ホーム画面に追加できる PWA）。GitHub Pages で `docs/` を公開する。
- `APPSTORE.md`：App Store 提出の手順。
