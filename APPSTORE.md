# App Store 提出の手順（罫線ノート）

YAHHO と同じ Apple Developer アカウント（個人）で出す前提です。個人登録なので、App Store の開発者名は本名で表示されます。

## 1. Mac でビルドして確かめる
1. `Keisen.xcodeproj` を Xcode で開く。
2. ターゲット Keisen → Signing & Capabilities → Team で自分のチームを選ぶ。
3. 同じ画面の「+ Capability」から **In-App Purchase** を追加する。
4. チップを試すとき：Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration で `Keisen.storekit` を選ぶ。
5. シミュレータか実機で動かし、記録・1つ戻す・新しいシュー・過去のシュー・応援を一通り触る。

## 2. App Store Connect でアプリを作る
1. 「マイApp」→「＋」→「新規App」。
   - プラットフォーム：iOS
   - 名前の案：`罫線ノート - バカラ記録`（使われていたら `罫線ノート` の後ろを変える）
   - 主言語：日本語
   - バンドルID：`com.tadahonami.keisen`（一覧になければ Certificates, Identifiers & Profiles で先に作る）
   - SKU：`keisen`
2. カテゴリ：ユーティリティ（サブにエンターテインメント）。

## 3. チップ（アプリ内課金）を作る
「収益化」→「App内課金」で **消耗型** を3つ作る。製品IDはアプリと同じにすること。

| 参照名 | 製品ID | 価格の目安 | 表示名 | 説明 |
| --- | --- | --- | --- | --- |
| Tip Small | com.tadahonami.keisen.tip.small | ¥160 | ちょっと応援 | コーヒー1杯ぶんの応援 |
| Tip Medium | com.tadahonami.keisen.tip.medium | ¥480 | しっかり応援 | ランチ1回ぶんの応援 |
| Tip Large | com.tadahonami.keisen.tip.large | ¥980 | めっちゃ応援 | 開発をがっつり応援 |

- 審査用のスクリーンショットには応援画面を撮って使う。
- 初回は、App内課金をアプリのバージョンと**一緒に**審査へ出す（バージョンのページの「App内課金」欄で3つを選ぶ）。
- 有料アプリ契約（「ビジネス」→ 契約、税務、口座情報）が済んでいないと課金は動かない。

## 4. 審査で気をつけること
- 年齢制限の質問票：実際のお金を賭ける機能も、シミュレートされたギャンブルもないので「ギャンブル」は「なし」。ただし Apple から 17+ などに上げるよう言われたら従う。
- 説明文やスクリーンショットに「必勝」「当たる」「稼げる」などを書かない。「バカラの罫線を記録・整理するアプリ」と説明する。
- 「寄付」ではなく「応援（チップ）」と書く。寄付として集められるのは認定された非営利団体だけ。
- App のプライバシー：「データの収集なし」。
- 審査メモの例：「バカラの出目（結果）を手で記録して、大路・珠盤路・大眼仔・小路・曱甴路の罫線を表示するツールです。賭けや課金によるゲームはなく、アプリ内課金は機能の変わらないチップのみです。」

## 5. アップロード
YAHHO と同じ流れ：
1. Xcode の Product → Archive（Any iOS Device）。
2. Organizer で Distribute App → App Store Connect → Upload。
3. App Store Connect で TestFlight で確かめてから、バージョンにビルドを選んで審査へ提出。

## スクリーンショット
6.9インチ（iPhone 16 Pro Max など）のシミュレータで、例のシューが出ている状態のメイン画面、過去のシュー、応援画面を撮る。
