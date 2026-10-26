import SwiftUI

/// みんなでチップ：親（ディーラー）の画面。テーブルを作ったら、上にプレイヤーの帯、左に罫線、右に勝敗の入力盤。
/// 勝敗を入れると、プレイヤーのベットを自動で精算する。親は自分ではベットしない。
struct DealerView: View {
    let shoe: ShoeStore
    let chips: ChipStore

    var body: some View {
        Group {
            if chips.role == .host, chips.table != nil {
                DealerTableView(shoe: shoe, chips: chips)
            } else {
                DealerSetupView(chips: chips)
            }
        }
        .modifier(ChipNoticeAlert(store: chips))
    }
}

// MARK: - テーブルを作る

private struct DealerSetupView: View {
    @Bindable var chips: ChipStore
    @State private var tableName = "テーブル"
    @State private var startingChips = 1000
    @State private var bankerCommission = false
    /// 親を置かず、記録係も自分のベットを入れる
    @State private var hostBets = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("あなたの名前（みんなの画面に出ます）", text: $chips.myName)
                        .textContentType(.nickname)
                    TextField("テーブルの名前", text: $tableName)
                    HStack {
                        Text("はじめの持ち点")
                        Spacer()
                        TextField("1000", value: $startingChips, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text("pt").foregroundStyle(.secondary)
                    }
                    Toggle("BANKER の勝ちから手数料5%を引く", isOn: $bankerCommission)
                    Toggle("自分もプレイヤーとしてベットする", isOn: $hostBets)
                } footer: {
                    Text("テーブルを作った iPhone で勝敗を記録し、みんなのベットを精算します（払い戻しは「場」から）。ほかの人は自分の iPhone で「テーブルに参加する」を選び、この画面に出る4桁の番号で参加します。アプリのない人は、参加者として足して代わりにベットを入れられます。親を置かずに全員で遊ぶときは「自分もプレイヤーとしてベットする」をオンにすると、記録しながら自分もベットできます。")
                }
                Section {
                    Button("テーブルを作る") {
                        let name = tableName.trimmingCharacters(in: .whitespaces)
                        chips.createTable(name: name.isEmpty ? "テーブル" : name, startingChips: startingChips,
                                          hostPlays: hostBets, bankerCommission: bankerCommission)
                        chips.setOpen(true)
                    }
                    .bold()
                } footer: {
                    Text("チップは pt で数える遊び用の記録です。お金に換えたり、精算に使ったりはしないでください。")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("テーブルを作る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ModeButton(chips: chips) }
            }
        }
    }
}

// MARK: - 親のテーブル

private struct DealerTableView: View {
    let shoe: ShoeStore
    let chips: ChipStore
    @State private var bankerPair = false
    @State private var playerPair = false
    @State private var editing: ChipMember?
    @State private var addingMember = false
    @State private var newMember = ""
    @State private var showManage = false
    @State private var showHistory = false
    @State private var confirmNewShoe = false
    @AppStorage("showAllRoads") private var showAllRoads = false
    @AppStorage("tieStyle") private var tieStyle: TieStyle = .dot
    @AppStorage("speakResults") private var speakResults = true
    @State private var announcement: ResultAnnouncement?

    /// 記録係も自分でベットしているか
    private var isPlaying: Bool { chips.table?.member(chips.myID) != nil }

    /// プレイヤーに配る罫線（例のシューは配らない）
    private var sharedHands: [Hand] { shoe.isSample ? [] : shoe.current.hands }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let table = chips.table { band(table) }
                HStack(spacing: 0) {
                    GeometryReader { geo in
                        RoadBoardColumn(hands: shoe.current.hands, isSample: shoe.isSample,
                                        height: geo.size.height, showAll: $showAllRoads)
                    }
                    if let table = chips.table, let me = table.member(chips.myID) {
                        myBetColumn(table, me)
                    }
                    VStack(spacing: 0) {
                        Text("勝敗を記録")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.deckInk.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        Spacer(minLength: 0)
                        InputDeck(
                            game: .baccarat,
                            hands: shoe.current.hands,
                            bankerPair: $bankerPair,
                            playerPair: $playerPair,
                            canUndo: shoe.canUndo,
                            side: true,
                            showAsk: showAllRoads,
                            onResult: { outcome in
                                shoe.record(outcome, bankerPair: bankerPair, playerPair: playerPair)
                                bankerPair = false
                                playerPair = false
                                chips.handRecorded(shoe.current)
                                if let hand = shoe.current.hands.last {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        announcement = ResultAnnouncement(
                                            hand: hand, handNumber: shoe.current.hands.count,
                                            net: chips.table?.lastRound?.results.first { $0.member == chips.myID }?.net)
                                    }
                                    if speakResults { ResultVoice.speak(hand) }
                                }
                            },
                            onUndo: {
                                shoe.undo()
                                chips.handUndone(shoe.current)
                            }
                        )
                    }
                    .frame(width: isPlaying ? 240 : 300)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .background(Theme.deck.ignoresSafeArea())
                }
            }
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ModeButton(chips: chips) }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        Label("過去のシュー", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(isPlaying ? "記録係" : "親")・\(sharedHands.count) 手").font(.headline).fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showManage = true } label: {
                        Label("テーブル", systemImage: "person.3")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("大路のタイの印", selection: $tieStyle) {
                            ForEach(TieStyle.allCases) { Text($0.title).tag($0) }
                        }
                        Toggle("珠盤路・下三路・問路も見る", isOn: $showAllRoads)
                        Toggle("結果を英語で読み上げる", isOn: $speakResults)
                    } label: {
                        Label("表示の設定", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { confirmNewShoe = true } label: {
                        Label("新しいシュー", systemImage: "plus.square.on.square")
                    }
                }
            }
            .tipButton()
        }
        .resultSplash($announcement)
        .onAppear {
            chips.syncHands(sharedHands)
            // アプリを開き直したときも、近くのプレイヤーが参加し直せるようにする
            if !chips.isOpen { chips.setOpen(true) }
        }
        .sheet(item: $editing) { m in
            if let table = chips.table {
                BetSheet(member: m, table: table, initial: table.bets[m.id] ?? [:]) { spots in
                    chips.placeBet(spots, for: m.id)
                }
            }
        }
        .sheet(isPresented: $showManage) { ChipManageSheet(store: chips) }
        .sheet(isPresented: $showHistory) { HistoryView(store: shoe) }
        .alert("参加者を足す", isPresented: $addingMember) {
            TextField("名前", text: $newMember)
            Button("足す") { chips.addLocalMember(newMember) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("アプリを入れていない人のぶんです。はじめの持ち点を配ります。")
        }
        .confirmationDialog("新しいシューを始めますか？", isPresented: $confirmNewShoe, titleVisibility: .visible) {
            Button("新しいシューを始める") {
                shoe.startNewShoe()
                bankerPair = false
                playerPair = false
                chips.syncHands(sharedHands)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("いまのシューは「過去のシュー」に残ります。チップの残高はそのままです。")
        }
    }

    /// 記録係が自分でもベットするときの列。勝敗のボタンと取り違えないように、明るい背景と見出しで分ける。
    private func myBetColumn(_ table: ChipTable, _ me: ChipMember) -> some View {
        VStack(spacing: 6) {
            Text("あなたのベット")
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            BetPad(spots: table.bets[me.id] ?? [:], balance: me.balance, commission: table.bankerCommission,
                   previous: table.lastRound?.bets[me.id], compact: true) { spots in
                chips.placeBet(spots, for: me.id)
            }
        }
        .foregroundStyle(Theme.deckInk)
        .padding(10)
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color(light: 0x2F3A34, dark: 0x1A2420))
    }

    /// 上の帯：参加番号・直前の結果・プレイヤーごとの残高とベットと増減
    private func band(_ table: ChipTable) -> some View {
        let last = table.lastRound
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if chips.isOpen {
                    Text("参加番号").font(.system(size: 9)).opacity(0.7)
                    Text(chips.code).font(.title3.bold().monospacedDigit())
                    Text("\(chips.connectedCount) 台つながっている").font(.system(size: 9)).opacity(0.7)
                } else {
                    Text("近くの人は\n参加できません").font(.caption2).opacity(0.7)
                }
            }
            .frame(width: 92, alignment: .leading)
            if let last {
                VStack(alignment: .leading, spacing: 2) {
                    Text("第\(last.handNumber)手").font(.caption2.bold())
                    Text(BetSpot.title(last.hand.outcome))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.color(last.hand.outcome), in: Capsule())
                }
                .id(last.id)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(table.members) { m in
                        Button { editing = m } label: {
                            MemberBetCard(member: m, table: table,
                                          lastNet: last?.results.first { $0.member == m.id }?.net)
                        }
                        .buttonStyle(PressStyle())
                    }
                    Button { newMember = ""; addingMember = true } label: {
                        Label("参加者を足す", systemImage: "person.badge.plus")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .frame(maxHeight: .infinity)
                            .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.deckInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.deck)
        .animation(.easeOut(duration: 0.2), value: last?.id)
        .sensoryFeedback(.success, trigger: last?.id)
    }
}

/// 親とプレイヤーの画面の左側：集計と罫線（大路だけが基本。設定でほかの罫線も）。罫線だけのモードと同じ描き方。
struct RoadBoardColumn: View {
    let hands: [Hand]
    var isSample = false
    let height: CGFloat
    @Binding var showAll: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                StatsBar(game: .baccarat, shoe: Shoe(hands: isSample ? [] : hands))
                RoadsBoard(game: .baccarat, hands: isSample ? [] : hands, scale: 1.35, showAll: showAll,
                           fitCell: max(20, min(42, (height - 130) / CGFloat(Roads.rows))))
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showAll.toggle() }
                } label: {
                    Label(showAll ? "大路だけにする" : "珠盤路・下三路・問路も見る",
                          systemImage: showAll ? "chevron.up" : "chevron.down")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .foregroundStyle(Theme.muted)
            }
            .padding(12)
        }
        .background(Theme.background)
    }
}
