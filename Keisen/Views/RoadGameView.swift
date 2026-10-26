import SwiftUI

/// バカラ・ドラゴンタイガーの罫線画面
struct RoadGameView: View {
    let store: ShoeStore
    @State private var bankerPair = false
    @State private var playerPair = false
    @State private var confirmNewShoe = false
    @State private var showHistory = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var game: RoadGame { store.game }

    /// iPhone を横にしたとき（高さが詰まる）は、罫線を大きくして入力盤を右に置く
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    HStack(spacing: 0) {
                        board(scale: 1.35)
                        deck(side: true)
                            .frame(width: 300)
                            .frame(maxHeight: .infinity)
                            .background(Theme.deck.ignoresSafeArea())
                    }
                } else {
                    board(scale: 1)
                        .safeAreaInset(edge: .bottom, spacing: 0) { deck(side: false) }
                }
            }
            // 横向きではタイトルが罫線の真ん中からずれて見えるので出さない
            .navigationTitle(isLandscape ? "" : "\(game.title)・\(store.current.hands.count) 手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        Label("過去のシュー", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { confirmNewShoe = true } label: {
                        Label("新しいシュー", systemImage: "plus.square.on.square")
                    }
                }
            }
            .tipButton()
            .confirmationDialog("新しいシューを始めますか？", isPresented: $confirmNewShoe, titleVisibility: .visible) {
                Button("新しいシューを始める") {
                    store.startNewShoe()
                    bankerPair = false
                    playerPair = false
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(store.isSample || store.current.hands.isEmpty
                     ? "空の罫線から記録を始めます。"
                     : "いまのシューは「過去のシュー」に残ります。")
            }
            .sheet(isPresented: $showHistory) { HistoryView(store: store) }
        }
    }

    private func board(scale: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                if store.isSample {
                    Text("いま表示しているのは例のシューです。1手目を記録すると消えて、あなたの記録が始まります。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 8))
                }
                if isLandscape {
                    Text("\(game.title)・\(store.current.hands.count) 手")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                StatsBar(game: game, shoe: store.current)
                RoadsBoard(game: game, hands: store.current.hands, scale: scale)
            }
            .padding(12)
        }
        .background(Theme.background)
    }

    private func deck(side: Bool) -> some View {
        InputDeck(
            game: game,
            hands: store.current.hands,
            bankerPair: $bankerPair,
            playerPair: $playerPair,
            canUndo: store.canUndo,
            side: side,
            onResult: { outcome in
                store.record(outcome, bankerPair: bankerPair, playerPair: playerPair)
                bankerPair = false
                playerPair = false
            },
            onUndo: { store.undo() }
        )
    }
}

/// 入力盤。問路・結果ボタン・ペア・1つ戻す。縦向きは画面の下、横向きは右端に置く。
struct InputDeck: View {
    let game: RoadGame
    let hands: [Hand]
    @Binding var bankerPair: Bool
    @Binding var playerPair: Bool
    let canUndo: Bool
    var side = false
    let onResult: (Outcome) -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ask(.banker)
                ask(.player)
            }
            HStack(spacing: 8) {
                resultButton(.banker)
                resultButton(.tie).frame(maxWidth: 90)
                resultButton(.player)
            }
            HStack(spacing: 8) {
                if game.hasPairs {
                    toggle("Bペア", isOn: $bankerPair, color: Theme.banker)
                    toggle("Pペア", isOn: $playerPair, color: Theme.player)
                }
                Button(action: onUndo) {
                    Label("1つ戻す", systemImage: "arrow.uturn.backward")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canUndo)
                .opacity(canUndo ? 1 : 0.5)
            }
        }
        .foregroundStyle(Theme.deckInk)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.deck.ignoresSafeArea(edges: side ? [.bottom, .trailing] : .bottom))
        .sensoryFeedback(.impact(weight: .light), trigger: hands.count)
    }

    private func ask(_ outcome: Outcome) -> some View {
        let marks = DerivedRoad.allCases.compactMap { road in
            Roads.nextMark(after: hands, outcome: outcome, road: road).map { (road: road, mark: $0) }
        }
        return HStack(spacing: 6) {
            Text("\(game.letter(outcome))なら").font(.caption.bold()).foregroundStyle(Theme.color(outcome))
            if marks.isEmpty {
                Text("まだ出ません").font(.caption2).foregroundStyle(Theme.deckInk.opacity(0.6))
            } else {
                ForEach(marks, id: \.road) { item in MarkIcon(road: item.road, mark: item.mark) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func resultButton(_ outcome: Outcome) -> some View {
        Button { onResult(outcome) } label: {
            VStack(spacing: 2) {
                Text(game.name(outcome)).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                // ドラゴンタイガーのタイは文字も珠盤路も「和」なので1つだけ出す
                let letter = game.letter(outcome), bead = game.bead(outcome)
                Text(letter == bead ? bead : "\(letter) \(bead)").font(.caption2).opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: side ? 84 : 58)
            .background(Theme.color(outcome), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressStyle())
    }

    private func toggle(_ title: String, isOn: Binding<Bool>, color: Color) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            Text(title)
                .font(.footnote.bold())
                .foregroundStyle(isOn.wrappedValue ? .white : Theme.deckInk)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(isOn.wrappedValue ? color : Theme.deckButton, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview {
    RoadGameView(store: ShoeStore(game: .baccarat))
        .environment(TipStore())
}
