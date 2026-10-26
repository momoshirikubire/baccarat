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
- `Keisen/Models/Hand.swift`：結果（B / P / T）、ペア、シュー、初回に見せる例のシュー。
- `Keisen/Models/Roads.swift`：罫線の計算。大路（タイは直前のマスに数で付ける、6段を超えたり下が埋まっていたら右へ曲がるドラゴンテール）、下三路（大眼仔・小路・曱甴路 = 1・2・3列前と比べる）、問路（次が B / P のときに付く印）。
- `Keisen/Store/ShoeStore.swift`：いまのシューと過去のシュー。`Application Support/shoes.json` に保存。
- `Keisen/Store/TipStore.swift`：StoreKit 2 のチップ。商品ID は `com.tadahonami.keisen.tip.small / medium / large`（消耗型）。
- `Keisen/Views/`：メイン画面と入力盤（`ContentView`）、罫線の描画（`RoadViews`、Canvas）、過去のシュー、応援画面。
- `docs/`：ブラウザ版（ホーム画面に追加できる PWA）。GitHub Pages で `docs/` を公開する。
- `APPSTORE.md`：App Store 提出の手順。
