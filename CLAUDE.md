# 罫線ノート — 広告なしのバカラ罫線アプリ

- ユーザーへの返答は**必ず日本語**で。
- ユーザーが自分で使うために作った、広告のないバカラ罫線の記録アプリ。App Store で公開する。
- 収益は広告ではなく「応援（チップ）」の消耗型アプリ内課金だけ。チップを買っても機能は変わらない。外部の寄付リンクは置かない（App Store の規約で、デジタルのチップはアプリ内課金にする必要がある）。
- 勝ちを保証するような表現（「必勝」「予想が当たる」など）はアプリにも説明文にも書かない。審査で賭博アプリと見なされないよう、あくまで「記録」として説明する。

## 技術
- SwiftUI、iOS 17 以降、Swift 5 モード。外部ライブラリなし。
- プロジェクトは `Keisen.xcodeproj`（スキーム `Keisen`）、ソースは `Keisen/`。Xcode の「フォルダ同期グループ」なので、ファイルを置くだけでビルド対象になる。
- 表示名は「罫線ノート」、バンドルIDは `com.tadahonami.keisen`。署名チームは pbxproj に入れていないので、Xcode の Signing & Capabilities でチームを選ぶ（または xcodebuild に `DEVELOPMENT_TEAM=...` を渡す）。
- `Keisen/Info.plist` には `ITSAppUsesNonExemptEncryption = NO` と、チップのテーブル用のローカルネットワークの説明・Bonjour サービス。アプリアイコンはアルファなしの 1024px PNG。
- `Keisen/PrivacyInfo.xcprivacy`：データ収集なし、UserDefaults（チップ回数の保存）の理由 CA92.1。
- `Keisen.storekit`：チップのテスト用設定。スキームの Run → Options → StoreKit Configuration で選ぶとシミュレータで買える。

## フォルダ構成
- 1.0 はバカラだけ（`App/KeisenApp.swift` はタブなしでバカラ画面を出す。v1.1 では `BaccaratView` が、チップのテーブルに子として入っているときは親の罫線とベット欄、それ以外は `RoadGameView`）。ドラゴンタイガー・ブラックジャック・ポーカー・点数表のコードは残してあり、あとのアップデートで TabView に戻して出す。右上のハートから応援画面を開ける（`.tipButton()`）。
- 画面は横向きだけ（pbxproj の UISupportedInterfaceOrientations_iPhone）。横向き（verticalSizeClass が compact）では、大路のマスを画面の高さに収まる大きさにして入力盤を右端に置く。縦向きのレイアウトのコードも残してある。
- バカラ画面は大路だけが基本（大きめのマス）。「珠盤路・下三路・問路も見る」で残りの罫線と入力盤の問路を出す（`@AppStorage("showAllRoads")`）。過去のシューは全部出す。
- 結果の呼び名は英字（BANKER / PLAYER / TIE、ペアは B PAIR / P PAIR）。
- `Keisen/Models/Hand.swift`：結果（B / P / T）、ペア、シュー、初回に見せる例のシュー。`RoadGame` でバカラとドラゴンタイガーの呼び名を切り替える（ドラゴン＝バンカーの位置、タイガー＝プレイヤーの位置。罫線の計算は同じ）。
- `Keisen/Models/Roads.swift`：罫線の計算。大路（タイは直前のマスに数で付ける、6段を超えたり下が埋まっていたら右へ曲がるドラゴンテール）、下三路（大眼仔・小路・曱甴路 = 1・2・3列前と比べる）、問路（次が B / P のときに付く印）。
- `Keisen/Store/ShoeStore.swift`：いまのシューと過去のシュー。ゲームごとに `Application Support/shoes.json`（バカラ）・`dragon-tiger.json` に保存。読み書きは `FileStore`。
- ブラックジャック（`Models/Blackjack.swift`・`BlackjackStore`・`Views/Blackjack/`）：勝ち・負け・引き分け・BJ（+1.5）・降参（−0.5）・ダブル（×2）を1ベット単位で記録し、収支のグラフ（Swift Charts）と過去のセッション。Hi-Lo カウントの練習（アプリ内で配るカードだけを使う。実際のテーブルで使う道具にはしない）。
- ポーカー（`Models/Poker.swift`・`PokerStore`・`Views/Poker/`）：ホームゲームの参加者ごとのバイインと最後のチップ、受け渡しの少ない精算。ブラインドタイマー（終わる時刻を保存するのでアプリを閉じてもずれない。動いているあいだは画面を消さない）。
- チップ（`Models/ChipTable.swift`・`ChipStore`・`Views/Chips/`）：実物のチップの代わりに、参加者の残高とポットを pt で数える。親の端末がテーブルを持って `chips.json` に保存し、近くの端末とは MultipeerConnectivity（サービス名 `keisen-chips`、4桁の参加番号）で直接つなぐ。子は「渡す／ポットに出す／ポットを取る」を親に送り、親が確かめてから全員にテーブルを配る。1台だけでも使える（アプリのない人は親が参加者として足す）。バカラ画面の左上のボタンから開く。v1.1 から。
- バカラ×チップ（`Models/ChipBaccarat.swift`・`Views/Chips/ChipBetViews.swift`）：テーブルがあると、バカラの入力盤の上に参加者ごとのベット欄（BANKER／PLAYER／TIE／B PAIR／P PAIR と英字で表示、pt）が出る。親は全員分、子は自分の分だけ（`.bet` を親に送り、親が確かめて配る）。親が結果を記録すると自動で精算し（P 1倍、B 0.95倍＝手数料5%・端数切り捨て、テーブル作成時に手数料なし 1倍も選べる、T 8倍、ペア 11倍、タイのとき B/P は戻る）、「場」（`ChipParty.bank`）との `ChipMove` で残す。「1つ戻す」で直前の精算を取り消してベットを戻す（`ChipRound` の手番号とシューIDで確かめる）。ベット中の額は使えない（渡す・ポットに出すも、残高からベットを引いた額で確かめる）。親の罫線は `ChipTable.hands` で配り、子のバカラタブ（`BaccaratView`）は入力盤の代わりに親の罫線・ベット欄・最後の精算を出す。精算があるので v1.1 から年齢区分は 17+（了承済み、`APPSTORE.md`）。
- 点数表（`ScoreStore`・`Views/Scores/`）：参加者×ラウンドの点数。
- 点数やチップはすべて「pt（ポイント）」で数え、「円」は使わない（日本では仲間内でもお金を賭けると賭博罪になるため）。
- `Keisen/Store/TipStore.swift`：StoreKit 2 のチップ。商品ID は `com.tadahonami.keisen.tip.small / medium / large / huge`（消耗型。¥300 / ¥1,000 / ¥2,000 / ¥5,000）。
- `Keisen/Views/`：罫線画面と入力盤（`RoadGameView`）、罫線の描画（`RoadViews`、Canvas）、過去のシュー、応援画面。
- `docs/`：ブラウザ版（ホーム画面に追加できる PWA）。GitHub Pages で `docs/` を公開する。
- `APPSTORE.md`：App Store 提出の手順。
