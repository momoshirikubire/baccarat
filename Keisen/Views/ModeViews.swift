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
    @AppStorage("announceInRoadsOnly") private var announceInRoadsOnly = false
    @State private var announcement: ResultAnnouncement?

    var body: some View {
        switch mode {
        case .choose:
            ModePickerView { mode = $0 }
        case .roadsOnly:
            RoadGameView(store: shoe, modeButton: ModeButton(chips: chips)) { hand, number in
                guard announceInRoadsOnly else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    announcement = ResultAnnouncement(hand: hand, handNumber: number)
                }
                ResultVoice.speak(hand)
            }
            .resultSplash($announcement)
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
        VStack(spacing: 14) {
            Text("どう使いますか？")
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                card(.roadsOnly, icon: "square.grid.3x3",
                     title: "罫線だけ",
                     detail: "1人で使う。勝敗を入れて罫線を記録します。")
                card(.dealer, icon: "person.crop.rectangle.stack",
                     title: "テーブルを作る（勝敗を記録する）",
                     detail: "親・記録係になる。勝敗を入れると、みんなのベットを pt で精算します。自分もプレイヤーとしてベットできます。")
                card(.player, icon: "person.2",
                     title: "テーブルに参加する（プレイヤー）",
                     detail: "近くのテーブルに参加して、自分の iPhone でベットします。勝敗は作った人が記録します。")
            }
            Text("あとから画面の左上のボタンで変えられます。チップは pt で数える遊び用の記録で、お金には換えられません。")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func card(_ mode: AppMode, icon: String, title: String, detail: String) -> some View {
        Button { onPick(mode) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
        .buttonStyle(PressStyle())
        .frame(maxHeight: 190)
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
            Label("使い方", systemImage: "rectangle.2.swap").labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("使い方を変える")
        .confirmationDialog(chips.role == .host ? "テーブルを閉じて、使い方を変えますか？" : "テーブルから抜けて、使い方を変えますか？",
                            isPresented: $confirm, titleVisibility: .visible) {
            Button(chips.role == .host ? "テーブルを閉じる" : "テーブルから抜ける", role: .destructive) {
                if chips.role == .host { chips.closeTable() } else { chips.leave() }
                mode = .choose
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(chips.role == .host
                 ? "つながっている人も抜けて、残高と履歴は消えます。"
                 : "あとで同じテーブルに参加し直すと、残りのチップから続けられます。")
        }
    }
}
