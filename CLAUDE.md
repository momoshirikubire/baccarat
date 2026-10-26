# バカラノート — 広告なしのバカラ罫線・チップ記録アプリ

- ユーザーへの返答は**必ず日本語**で。
- ユーザーが自分で使うために作った、広告のないバカラ罫線の記録アプリ。App Store で公開する。
- 収益は広告ではなく「応援（チップ）」の消耗型アプリ内課金だけ。チップを買っても機能は変わらない。外部の寄付リンクは置かない（App Store の規約で、デジタルのチップはアプリ内課金にする必要がある）。
- 勝ちを保証するような表現（「必勝」「予想が当たる」など）はアプリにも説明文にも書かない。審査で賭博アプリと見なされないよう、あくまで「記録」として説明する。

## 技術
- SwiftUI、iOS 17 以降、Swift 5 モード。外部ライブラリなし。
- プロジェクトは `Keisen.xcodeproj`（スキーム `Keisen`）、ソースは `Keisen/`。Xcode の「フォルダ同期グループ」なので、ファイルを置くだけでビルド対象になる。
- App Store の名前は「バカラノート - 罫線とチップの記録」（2026-10-26 に「罫線ノート」から変更）、ホーム画面の表示名は「バカラノート」、バンドルIDは `com.tadahonami.keisen`。署名チームは pbxproj に入れていないので、Xcode の Signing & Capabilities でチームを選ぶ（または xcodebuild に `DEVELOPMENT_TEAM=...` を渡す）。
- `Keisen/Info.plist` には `ITSAppUsesNonExemptEncryption = NO` と、チップのテーブル用のローカルネットワークの説明・Bonjour サービス。アプリアイコンはアルファなしの 1024px PNG。
- `Keisen/PrivacyInfo.xcprivacy`：データ収集なし、UserDefaults（チップ回数の保存）の理由 CA92.1。
- `Keisen.storekit`：チップのテスト用設定。スキームの Run → Options → StoreKit Configuration で選ぶとシミュレータで買える。

## フォルダ構成
- ツールバーのボタンは、アイコンだけにせず文字をつける（ツールバーの中では `Label(...).labelStyle(.titleAndIcon)` でもアイコンだけになるので、`ToolbarTitle`（`Views/ModeViews.swift`、アイコンと文字の HStack）を使う：「使い方」「履歴」「表示」「新しいシュー」「テーブル」「テーブルを閉じる」「持ち点に戻す」「テーブルから抜ける」など）。
- 1.0 はバカラだけ（`App/KeisenApp.swift` はタブなしで `RootView` を出す）。v1.1 では起動したら最初に使い方を選ぶ（`Views/ModeViews.swift` の `AppMode`、`@AppStorage("appMode")` で覚えて次からその画面で始まる。左上の `ModeButton` でいつでも変えられ、テーブルを持っている・参加しているときは確かめてから閉じる／抜ける）：「罫線だけ」＝ `RoadGameView`（1.0 と同じ見た目。チップは出さない）、「テーブルを作る（勝敗を記録する）」＝ `DealerView`、「テーブルに参加する（プレイヤー）」＝ `PlayerView`。ドラゴンタイガー・ブラックジャック・ポーカー・点数表のコードは残してあり、あとのアップデートで TabView に戻して出す。右上の「応援」から応援画面を開ける（`.tipButton()`）。
- 画面は横向きだけ（pbxproj の UISupportedInterfaceOrientations_iPhone）。横向き（verticalSizeClass が compact）では、大路のマスを画面の高さに収まる大きさにして入力盤を右端に置く。縦向きのレイアウトのコードも残してある。
- バカラ画面は大路だけが基本（大きめのマス）。「珠盤路・下三路・問路も見る」で残りの罫線と入力盤の問路を出す（`@AppStorage("showAllRoads")`）。過去のシューは全部出す。
- 大路のタイの印は右上の「表示」で「まる」（はじめ）か「斜線」を選ぶ（`@AppStorage("tieStyle")`、`TieStyle`）。2回以上は回数を添える。
- 応援のお願い：「新しいシュー」を2回始めるごとにアラートを出す（「あとで」で閉じる。最後のチップから1年以内の人には出さない。`RoadGameView.maybeNudge`・`TipStore.tippedWithinYear`）。
- 右上のボタンはアイコンだけにせず文字つき（履歴・表示・新しいシュー・応援）。
- 左上の「ルール」（`Views/RulesView.swift`）：「3枚目の判定」（カードを選ぶと PLAYER / BANKER が3枚目を引くかと勝ち負けを出す。計算は `Models/ThirdCard.swift`）と、ルールのまとめ。
- 結果の呼び名は英字（BANKER / PLAYER / TIE、ペアは B PAIR / P PAIR）。
- `Keisen/Models/Hand.swift`：結果（B / P / T）、ペア、シュー、初回に見せる例のシュー。`RoadGame` でバカラとドラゴンタイガーの呼び名を切り替える（ドラゴン＝バンカーの位置、タイガー＝プレイヤーの位置。罫線の計算は同じ）。
- `Keisen/Models/Roads.swift`：罫線の計算。大路（タイは直前のマスに数で付ける、6段を超えたり下が埋まっていたら右へ曲がるドラゴンテール）、下三路（大眼仔・小路・曱甴路 = 1・2・3列前と比べる）、問路（次が B / P のときに付く印）。
- `Keisen/Store/ShoeStore.swift`：いまのシューと過去のシュー。ゲームごとに `Application Support/shoes.json`（バカラ）・`dragon-tiger.json` に保存。読み書きは `FileStore`。
- ブラックジャック（`Models/Blackjack.swift`・`BlackjackStore`・`Views/Blackjack/`）：勝ち・負け・引き分け・BJ（+1.5）・降参（−0.5）・ダブル（×2）を1ベット単位で記録し、収支のグラフ（Swift Charts）と過去のセッション。Hi-Lo カウントの練習（アプリ内で配るカードだけを使う。実際のテーブルで使う道具にはしない）。
- ポーカー（`Models/Poker.swift`・`PokerStore`・`Views/Poker/`）：ホームゲームの参加者ごとのバイインと最後のチップ、受け渡しの少ない精算。ブラインドタイマー（終わる時刻を保存するのでアプリを閉じてもずれない。動いているあいだは画面を消さない）。
- チップ（`Models/ChipTable.swift`・`ChipStore`・`Views/Chips/`）：実物のチップの代わりに、参加者の残高を pt で数える（ポットは v1.1 の途中でやめた。古い保存データの pot や、履歴の "pot" は読み捨てる／「場」として読む）。親の端末がテーブルを持って `chips.json` に保存し、近くの端末とは MultipeerConnectivity（サービス名 `keisen-chips`、4桁の参加番号）で直接つなぐ。子は「渡す」（参加者どうし）を親に送り、親が確かめてから全員にテーブルを配る。1台だけでも使える（アプリのない人は親が参加者として足す）。親とプレイヤーの画面の右上のボタン（`ChipManageSheet`）から、参加番号・近くの人が参加できる・ベットの下限と上限・参加者・持ち点に戻す・テーブルを閉じる／抜ける・渡す・履歴を開く。v1.1 から。
- バカラ×チップ（`Models/ChipBaccarat.swift`・`Views/Chips/DealerView.swift`・`PlayerView.swift`・`ChipBetViews.swift`）：
  - 親（テーブルを作った端末）だけが勝敗を記録する（全員が押せると二重に記録されるため）。親の画面は、上の帯に参加番号と参加者ごとの名前・残高・いまのベット・直前の増減（子の端末から来たベットはすぐ反映。名前を押すと代わりにベットを入れられる＝アプリのない人の分）、左に大路（設定でほかの罫線も）、右に勝敗の入力盤。親は「場」としてベットしない（myID を参加者に入れない）。テーブル作成時に「自分もプレイヤーとしてベットする」（初期値オフ）をオンにすると、記録係として myID を参加者に入れ、勝敗の入力盤とは分けた「あなたのベット」の列（`BetPad`）が出る。親の画面を開くと、近くの人が参加できる状態に自動でする。
  - プレイヤーの画面は、名前を入れて近くのテーブルを選び4桁の番号で参加（`PlayerJoinView`。探しているあいだは同じ MCPeerID を使う）。参加後は上にみんなの残高とベット（自分のカードを明るく）、左に親と同じ大路（`table.hands`、見るだけ）、右に `BetPad`（残高・ベット中・使える額、BANKER / TIE / PLAYER / B PAIR / P PAIR、+10 / +50 / +100 / +500 / 0、前の手と同じ、ベットを消す）。自分のベットは `.bet` で親に送り、親が確かめて全員に配る。接続が切れたら知らせて、参加の画面に戻る（同じテーブルなら残高から続けられる）。
  - ベットの下限・上限（`ChipTable.minBet` / `maxBet`、pt、0 は「なし」、初期値はどちらもなし）：BANKER / PLAYER / TIE / B PAIR / P PAIR のそれぞれが 0 か、下限以上・上限以下。テーブルを作るときに入れ、あとから親が 👥 のシートで変えられる（変えたら全員に配り、外れたベットは消す）。`BetPad` の +10 などは 0 からなら下限まで上げ、上限で止める。親は `limitProblem` で外れたベットをはじく。親とプレイヤーの画面に「下限 10 / 上限 1,000」と出す。
  - 配当：P 1倍、B 1倍（初期値。テーブル作成時に「手数料5%を引く」をオンにすると 0.95倍・端数切り捨て）、T 8倍、ペア 11倍。TIE のとき B/P は戻り（±0）、次の手にも残る。払い戻しは「場」（`ChipParty.bank`）との `ChipMove` で、記録係の残高からは払わない。「1つ戻す」で直前の精算を取り消してベットを戻す（`ChipRound` の手番号とシューIDで確かめる）。ベット中の額は使えない（渡す・ポットに出すも、残高からベットを引いた額で確かめる）。
  - 結果の大きな表示と読み上げ（`Views/ResultSplash.swift`）：親が勝敗を記録すると、親とプレイヤー全員の画面いっぱいに BANKER / PLAYER / TIE を結果の色で出し（ペアは添える、プレイヤーには自分の増減も）、2.5秒かタップで消える。AVSpeechSynthesizer で英語（en-US）の「Banker」「Player, banker pair」などを読み上げる（オーディオセッション .ambient で消音スイッチに従う。親とプレイヤーの画面は「表示」の `@AppStorage("speakResults")`、初期値オン）。罫線画面（`RoadGameView`）は「結果を大きく出して読み上げる」（`@AppStorage(ResultAnnouncement.storageKey)` = "announceResults"、初期値オン）。`ResultSplash.swift` は Hand・Outcome・Theme だけに頼るので、チップのない 1.0 にもそのまま持っていける。
  - 追加（リバイ）：親は帯の名前の下の「追加する」か、名前を押したシートの「ポイントを追加する」で、場から pt を足す（初期値は持ち点と同じ。`ChipMove.kind = .rebuy` で履歴に「追加」と出す）。プレイヤーは使える額が下限（なければ 1 pt）より少なくなると「親に追加をお願いする」（`.rebuyRequest`）を押せ、親の帯に「追加をお願い中」が出る（`ChipTable.rebuyRequests`、足したら消える）。
  - 参加者ごとの成績（`ChipStats`：もらった合計＝はじめの持ち点＋追加、勝った手・ベットした手、追加の回数と合計）。帯には「残高（通算 ±）」、結果には「最後の残高 − もらった合計」を出す。
  - 終了と結果（`ChipSummary`・`Views/Chips/SummaryView.swift`）：親の「終了する」で、結果（参加者ごとの残高・増減・勝った手／ベットした手・追加、増減の大きい順、テーブル名・時間・手の数）を `.ended` で全員に送ってから少し待って切る。親とプレイヤーの画面いっぱいに結果を出し（自分の行を目立たせる）、「閉じる」で使い方を選ぶ画面に戻る。親の端末には直近10回を `chip-results.json` に残し、「テーブルを作る」画面の「これまでの結果」から見られる。プレイヤーが自分で抜けるときもその時点の結果を出す。だれがだれに払うといった精算の表示は出さない。
  - 精算があるので年齢区分は 18+（新しい区分。了承済み、`APPSTORE.md`）。
- 点数表（`ScoreStore`・`Views/Scores/`）：参加者×ラウンドの点数。
- 点数やチップはすべて「pt（ポイント）」で数え、「円」は使わない（日本では仲間内でもお金を賭けると賭博罪になるため）。
- `Keisen/Store/TipStore.swift`：StoreKit 2 のチップ。商品ID は `com.tadahonami.keisen.tip.small / medium / large`（消耗型。¥500 / ¥1,000 / ¥2,000）。`tip.huge`（¥5,000）は 2026-10 にやめた。
- `Keisen/Views/`：罫線画面と入力盤（`RoadGameView`）、罫線の描画（`RoadViews`、Canvas）、過去のシュー、応援画面。
- `docs/`：ブラウザ版（ホーム画面に追加できる PWA）。GitHub Pages で `docs/` を公開する。
- `APPSTORE.md`：App Store 提出の手順。
