import SwiftUI

/// バカラ・ドラゴンタイガーの罫線画面
struct RoadGameView: View {
    let store: ShoeStore
    /// 使い方を変えるボタン（罫線だけのモードで左上に出す）
    var modeButton: ModeButton? = nil
    @State private var bankerPair = false
    @State private var playerPair = false
    @State private var confirmNewShoe = false
    @State private var showHistory = false
    @State private var showNudge = false
    @State private var showTips = false
    @State private var showRules = false
    @Environment(TipStore.self) private var tips
    /// 「新しいシュー」を押した回数（応援のお願いを出す間かくに使う）
    @AppStorage("newShoeCount") private var newShoeCount = 0
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 珠盤路・下三路・問路も出すか（はじめは大路だけ）
    @AppStorage("roads.showAll") private var showAllRoads = false
    @AppStorage("tieStyle") private var tieStyle: TieStyle = .dot
    /// 結果を記録したら大きく出して読み上げる（ResultSplash.swift、はじめはオン）
    @AppStorage(ResultAnnouncement.storageKey) private var announceResults = true
    @State private var announcement: ResultAnnouncement?

    private var game: RoadGame { store.game }
    private var title: String { "\(store.current.hands.count) 手" }

    /// iPhone を横にしたとき（高さが詰まる）は、罫線を大きくして入力盤を右に置く
    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    // 大路だけのときは、集計を右の列に移して入力盤を細くし、そのぶん大路を大きくする
                    let roadsOnly = !showAllRoads
                    HStack(spacing: 0) {
                        // 大路の6段が画面の高さに収まるマスの大きさにする（集計の段・見出し・余白を引く）
                        GeometryReader { geo in
                            // ツールバーの下にもぐる部分があれば、それも引く
                            let height = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
                            board(scale: 1.35,
                                  fitCell: max(22, min(roadsOnly ? 80 : 42, (height - (roadsOnly ? 64 : 130)) / CGFloat(Roads.rows))),
                                  compact: roadsOnly)
                        }
                        deck(side: true)
                            .frame(width: roadsOnly ? 200 : 300)
                            .frame(maxHeight: .infinity)
                            .background(Theme.deck.ignoresSafeArea())
                    }
                } else {
                    board(scale: 1)
                        .safeAreaInset(edge: .bottom, spacing: 0) { deck(side: false) }
                }
            }
            // 横向きでは真ん中のタイトルが罫線からずれて見えるので、履歴ボタンの横に出す
            .navigationTitle(isLandscape ? "" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 使い方はいつでも見えるように、いちばん左に置く
                if let modeButton {
                    ToolbarItem(placement: .topBarLeading) { modeButton }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        ToolbarTitle("履歴", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showRules = true } label: {
                        ToolbarTitle("ルール", systemImage: "book")
                    }
                }
                if isLandscape {
                    // ボタンが入りきるように、横向きでは手の数だけを短く出す
                    ToolbarItem(placement: .topBarLeading) {
                        Text(title).font(.headline).fixedSize()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // サブメニューにして、何を選ぶのかを行の名前で見せる
                        Picker("大路のタイの印", selection: $tieStyle) {
                            ForEach(TieStyle.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Toggle("珠盤路・下三路・問路も見る", isOn: $showAllRoads)
                        Toggle("結果を大きく出して読み上げる", isOn: $announceResults)
                    } label: {
                        ToolbarTitle("表示", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { confirmNewShoe = true } label: {
                        ToolbarTitle("新しいシュー", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
            }
            .tipButton()
            .confirmationDialog("新しいシューを始めますか？", isPresented: $confirmNewShoe, titleVisibility: .visible) {
                Button("新しいシューを始める") {
                    store.startNewShoe()
                    maybeNudge()
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
            .alert("バカラノートを応援しませんか？", isPresented: $showNudge) {
                Button("応援する") { showTips = true }
                Button("あとで", role: .cancel) {}
            } message: {
                Text("広告なしで使い続けられるように、よければチップで応援してください。チップを送っても機能は変わりません。")
            }
            .sheet(isPresented: $showTips) { TipJarView() }
            .sheet(isPresented: $showRules) { RulesView() }
        }
        .resultSplash($announcement)
    }

    /// 新しいシューを2回始めるごとに、応援のお願いを出す（「あとで」の1タップで閉じる）。
    /// 応援してくれた人には、最後のチップから1年たつまで出さない。
    private func maybeNudge() {
        newShoeCount += 1
        guard newShoeCount % 2 == 0, !tips.tippedWithinYear else { return }
        // 確認のダイアログが閉じきってから出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showNudge = true }
    }

    /// compact：横向きで大路だけのとき。集計と「も見る」ボタンは右の列と「表示」に任せて、大路だけを置く
    private func board(scale: CGFloat, fitCell: CGFloat? = nil, compact: Bool = false) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                // 横向きで大路だけのときは、例のシューのお知らせは右の列に短く出す（大路を高さいっぱいにするため）
                if store.isSample && !compact {
                    Text("いま表示しているのは例のシューです。1手目を記録すると消えて、あなたの記録が始まります。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 8))
                }
                if !compact {
                    StatsBar(game: game, shoe: store.current)
                }
                RoadsBoard(game: game, hands: store.current.hands, scale: scale, showAll: showAllRoads, fitCell: fitCell)
                if !compact {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showAllRoads.toggle() }
                    } label: {
                        Label(showAllRoads ? "大路だけにする" : "珠盤路・下三路・問路も見る",
                              systemImage: showAllRoads ? "chevron.up" : "chevron.down")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .foregroundStyle(Theme.muted)
                }
            }
            .padding(compact ? 8 : 12)
        }
        .background(Theme.background)
    }

    private func deck(side: Bool) -> some View {
        VStack(spacing: 0) {
            if side { Spacer(minLength: 0) }
            inputDeck(side: side)
        }
    }

    private func inputDeck(side: Bool) -> some View {
        InputDeck(
            game: game,
            hands: store.current.hands,
            bankerPair: $bankerPair,
            playerPair: $playerPair,
            canUndo: store.canUndo,
            side: side,
            showAsk: showAllRoads,
            narrowShoe: side && !showAllRoads ? store.current : nil,
            isSample: store.isSample,
            onResult: { outcome in
                store.record(outcome, bankerPair: bankerPair, playerPair: playerPair)
                bankerPair = false
                playerPair = false
                if announceResults, let hand = store.current.hands.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        announcement = ResultAnnouncement(hand: hand, handNumber: store.current.hands.count)
                    }
                    ResultVoice.speak(hand)
                }
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
    /// 問路（次が B / P のときに下三路に付く印）を出すか
    var showAsk = true
    /// 横向きで大路だけのときは細い列にする。集計をここに出し、結果のボタンは縦に並べる
    var narrowShoe: Shoe? = nil
    var isSample = false
    let onResult: (Outcome) -> Void
    let onUndo: () -> Void

    var body: some View {
        Group {
            if let narrowShoe {
                narrowBody(narrowShoe)
            } else {
                wideBody
            }
        }
        .foregroundStyle(Theme.deckInk)
        .padding(.horizontal, narrowShoe == nil ? 12 : 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.deck.ignoresSafeArea(edges: side ? [.bottom, .trailing] : .bottom))
        .sensoryFeedback(.impact(weight: .light), trigger: hands.count)
    }

    private func narrowBody(_ shoe: Shoe) -> some View {
        // 画面の低い機種でも収まるように、結果のボタンは 36〜64pt のあいだで伸び縮みさせる
        VStack(spacing: 6) {
            MiniStats(game: game, shoe: shoe)
            if isSample {
                Text("いまは例のシューです。1手目を記録すると消えます。")
                    .font(.caption2)
                    .opacity(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            resultButton(.banker)
            resultButton(.player)
            resultButton(.tie)
            HStack(spacing: 6) {
                if game.hasPairs {
                    toggle("B PAIR", isOn: $bankerPair, color: Theme.banker)
                    toggle("P PAIR", isOn: $playerPair, color: Theme.player)
                }
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canUndo)
                .opacity(canUndo ? 1 : 0.5)
                .accessibilityLabel("1つ戻す")
            }
        }
    }

    private var wideBody: some View {
        VStack(spacing: 8) {
            if showAsk {
                HStack(spacing: 8) {
                    ask(.banker)
                    ask(.player)
                }
            }
            HStack(spacing: 8) {
                resultButton(.banker)
                resultButton(.tie).frame(maxWidth: 90)
                resultButton(.player)
            }
            HStack(spacing: 8) {
                if game.hasPairs {
                    toggle("B PAIR", isOn: $bankerPair, color: Theme.banker)
                    toggle("P PAIR", isOn: $playerPair, color: Theme.player)
                }
                undoButton
            }
        }
    }

    private var undoButton: some View {
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
            .frame(maxWidth: .infinity, minHeight: narrowShoe != nil ? 36 : side ? 84 : 58,
                   maxHeight: narrowShoe != nil ? 64 : nil)
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

/// 細い入力盤の上に出す集計（BANKER・PLAYER・TIE の回数と割合、ペアの回数）
struct MiniStats: View {
    let game: RoadGame
    let shoe: Shoe

    var body: some View {
        let c = shoe.count
        let n = shoe.hands.count
        VStack(spacing: 2) {
            row(game.name(.banker), c.banker, n, Theme.banker)
            row(game.name(.player), c.player, n, Theme.player)
            row(game.name(.tie), c.tie, n, Theme.tie)
            if game.hasPairs {
                HStack {
                    Text("B PAIR \(c.bankerPair)")
                    Spacer()
                    Text("P PAIR \(c.playerPair)")
                }
                .font(.caption2.monospacedDigit())
                .opacity(0.8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func row(_ name: String, _ v: Int, _ n: Int, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.caption.bold())
            Spacer()
            Text("\(v)").font(.subheadline.monospacedDigit().bold())
            Text(n == 0 ? "–" : "\(Int((Double(v) / Double(n) * 100).rounded()))%")
                .font(.caption2.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
                .opacity(0.8)
        }
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
