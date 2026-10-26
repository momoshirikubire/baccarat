import SwiftUI

/// アプリの使い方。起動したら最初に選び、次からはその画面から始める。
enum AppMode: String, CaseIterable, Identifiable {
    /// まだ選んでいない
    case choose
    /// 罫線だけ（1人で使う）
    case roadsOnly
    /// みんなでチップ：親（ディーラー）。勝敗を入れて精算する。
    case dealer
    /// みんなでチップ：プレイヤー。親のテーブルに参加してベットする。
    case player

    var id: String { rawValue }

    var title: String {
        switch self {
        case .choose: "使い方を選ぶ"
        case .roadsOnly: "罫線だけ"
        case .dealer: "テーブルを作る"
        case .player: "テーブルに参加する"
        }
    }
}

/// モードに合わせて画面を切り替える
struct RootView: View {
    let shoe: ShoeStore
    let chips: ChipStore
    @AppStorage("appMode") private var mode: AppMode = .choose

    var body: some View {
        content
            // テーブルを終了した・抜けたときの結果。閉じると使い方を選ぶ画面に戻る。
            .fullScreenCover(item: Binding(get: { chips.summary }, set: { chips.summary = $0 })) { summary in
                SummaryView(summary: summary, myID: chips.myID) {
                    chips.summary = nil
                    mode = .choose
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .choose:
            ModePickerView { mode = $0 }
        case .roadsOnly:
            RoadGameView(store: shoe, modeButton: ModeButton(chips: chips))
        case .dealer:
            DealerView(shoe: shoe, chips: chips)
        case .player:
            PlayerView(chips: chips)
        }
    }
}

/// 最初の「使い方を選ぶ」画面
struct ModePickerView: View {
    let onPick: (AppMode) -> Void

    var body: some View {
        // 小さい画面の横向きでも文字を切らずに全部見せるため、はみ出す分はスクロールする
        ScrollView {
            VStack(spacing: 14) {
                Text("どう使いますか？")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                HStack(alignment: .top, spacing: 12) {
                    card(.roadsOnly, icon: "square.grid.3x3",
                         title: "罫線だけ",
                         role: nil,
                         detail: "勝敗を入れて罫線を記録します。")
                    card(.dealer, icon: "person.crop.rectangle.stack",
                         title: "テーブルを作る",
                         role: "勝敗を記録する親になる",
                         detail: "勝敗を入れると、みんなのベットを pt で精算します。自分もベットできます。")
                    card(.player, icon: "person.2",
                         title: "テーブルに参加する",
                         role: "プレイヤーとしてベットする",
                         detail: "近くのテーブルに入って、自分の iPhone でベットします。")
                }
                Text("あとから画面の左上の「使い方」で変えられます。チップは pt で数える遊び用の記録で、お金には換えられません。")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func card(_ mode: AppMode, icon: String, title: String, role: String?, detail: String) -> some View {
        Button { onPick(mode) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let role {
                    Text(role)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
        .buttonStyle(PressStyle())
    }
}

/// ツールバーに置く「使い方を変える」ボタン。親がテーブルを持っているとき・参加中のときは確かめてから抜ける。
struct ModeButton: View {
    let chips: ChipStore
    @AppStorage("appMode") private var mode: AppMode = .choose
    @State private var confirm = false

    var body: some View {
        Button {
            if chips.role == .none { mode = .choose } else { confirm = true }
        } label: {
            ToolbarTitle("使い方", systemImage: "rectangle.2.swap")
        }
        .accessibilityLabel("使い方を変える")
        .confirmationDialog(chips.role == .host ? "テーブルを終了して、使い方を変えますか？" : "テーブルから抜けて、使い方を変えますか？",
                            isPresented: $confirm, titleVisibility: .visible) {
            Button(chips.role == .host ? "終了する" : "テーブルから抜ける", role: .destructive) {
                // 結果の画面が出て、閉じると使い方を選ぶ画面に戻る
                if chips.role == .host { chips.endTable() } else { chips.leaveWithSummary() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(chips.role == .host
                 ? "全員の画面に結果が出て、テーブルは閉じます。"
                 : "あとで同じテーブルに参加し直すと、残りのチップから続けられます。")
        }
    }
}
