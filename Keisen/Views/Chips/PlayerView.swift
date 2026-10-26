import SwiftUI

/// みんなでチップ：プレイヤーの画面。近くの親のテーブルに参加して、自分の分だけベットを入れる。
/// 勝敗は親が入れる。左に親と同じ罫線（見るだけ）、右に大きなベットのボタン。
struct PlayerView: View {
    let chips: ChipStore

    var body: some View {
        Group {
            if chips.role == .guest, chips.table != nil {
                PlayerTableView(chips: chips)
            } else {
                PlayerJoinView(chips: chips)
            }
        }
        .modifier(ChipNoticeAlert(store: chips))
    }
}

// MARK: - 参加する

private struct PlayerJoinView: View {
    @Bindable var chips: ChipStore
    @State private var joining: ChipStore.FoundTable?
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("あなたの名前", text: $chips.myName)
                        .textContentType(.nickname)
                } header: {
                    Text("あなた")
                } footer: {
                    Text("みんなの画面に出る名前です。")
                }

                Section {
                    if chips.role == .guest {
                        HStack {
                            ProgressView()
                            Text("参加しています…").padding(.leading, 6)
                        }
                    } else if chips.found.isEmpty {
                        HStack {
                            ProgressView()
                            Text("近くのテーブルを探しています…")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 6)
                        }
                    }
                    ForEach(chips.found) { table in
                        Button {
                            code = ""
                            joining = table
                        } label: {
                            LabeledContent(table.name, value: "作った人：\(table.peer.displayName)")
                        }
                        .disabled(chips.role == .guest)
                    }
                } header: {
                    Text("近くのテーブル")
                } footer: {
                    Text("テーブルを作った人の画面の左上に出ている4桁の参加番号を入れて参加します。Wi-Fi と Bluetooth をオンにしてください。インターネットはなくても使えます。前に参加したテーブルなら、残りのチップから続けられます。")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("プレイヤーで参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ModeButton(chips: chips) }
            }
        }
        .onAppear { if chips.role == .none { chips.startBrowsing() } }
        // 親との接続が切れて戻ってきたら、また探す
        .onChange(of: chips.role) { if chips.role == .none { chips.startBrowsing() } }
        .alert("参加番号", isPresented: Binding(get: { joining != nil }, set: { if !$0 { joining = nil } })) {
            TextField("4桁の番号", text: $code)
                .keyboardType(.numberPad)
            Button("参加する") {
                if let joining { chips.join(joining, code: code) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(joining?.name ?? "")」の親の画面に出ている番号を入れてください。")
        }
    }
}

// MARK: - 参加中

private struct PlayerTableView: View {
    let chips: ChipStore
    /// 自分のベット。親に送ってから届くまでのあいだも、押した分がすぐ見えるように手元に持つ。
    @State private var draft: [BetSpot: Int] = [:]
    @State private var announcement: ResultAnnouncement?
    /// 最後に大きく出した精算の時刻。親が「1つ戻す」で前の精算に戻ったときは出さない。
    @State private var shownUntil = Date.distantPast
    @State private var showManage = false
    @State private var showRules = false
    @AppStorage("showAllRoads") private var showAllRoads = false
    @AppStorage("tieStyle") private var tieStyle: TieStyle = .dot
    @AppStorage("speakResults") private var speakResults = true

    var body: some View {
        let table = chips.table
        let me = table?.member(chips.myID)
        let balance = me?.balance ?? 0
        NavigationStack {
            VStack(spacing: 0) {
                if let table { membersBand(table) }
                HStack(spacing: 0) {
                    GeometryReader { geo in
                        RoadBoardColumn(hands: table?.hands ?? [], height: geo.size.height, showAll: $showAllRoads)
                    }
                    VStack(spacing: 8) {
                        if let table, needsRebuy(table, balance: balance) {
                            rebuyRequestButton(table)
                        }
                        BetPad(spots: draft, balance: balance, commission: table?.bankerCommission ?? false,
                               previous: table?.lastRound?.bets[chips.myID],
                               minBet: table?.minBet ?? 0, maxBet: table?.maxBet ?? 0,
                               // お願いのボタンが出ているあいだは、高さに収まるようにボタンを低くする
                               compact: table.map { needsRebuy($0, balance: balance) } ?? false) { spots in
                            draft = spots
                            chips.placeBet(spots, for: chips.myID)
                        }
                        if let last = table?.lastRound {
                            SettlementLine(round: last, myID: chips.myID)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .foregroundStyle(Theme.deckInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 340)
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
                    Button { showRules = true } label: {
                        ToolbarTitle("ルール", systemImage: "book")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(table?.name ?? "テーブル")・\(table?.hands.count ?? 0) 手").font(.headline).fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showManage = true } label: {
                        ToolbarTitle("テーブル", systemImage: "person.3")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("大路のタイの印", selection: $tieStyle) {
                            ForEach(TieStyle.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Toggle("珠盤路・下三路も見る", isOn: $showAllRoads)
                        Toggle("結果を英語で読み上げる", isOn: $speakResults)
                    } label: {
                        ToolbarTitle("表示", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .tipButton()
        }
        .resultSplash($announcement)
        .sheet(isPresented: $showManage) { ChipManageSheet(store: chips) }
        .sheet(isPresented: $showRules) { RulesView() }
        .onAppear {
            draft = table?.bets[chips.myID] ?? [:]
            shownUntil = table?.lastRound?.date ?? .distantPast
        }
        // 精算されたら（TIE で残ったベットも含めて）親のベットに合わせ直し、結果を大きく出す
        .onChange(of: table?.lastRound?.id) {
            draft = chips.table?.bets[chips.myID] ?? [:]
            guard let round = chips.table?.lastRound, round.date > shownUntil else { return }
            shownUntil = round.date
            withAnimation(.easeOut(duration: 0.15)) {
                announcement = ResultAnnouncement(hand: round.hand, handNumber: round.handNumber,
                                                  net: round.results.first { $0.member == chips.myID }?.net)
            }
            if speakResults { ResultVoice.speak(round.hand) }
        }
        // 親に断られたら、親の持っているベットに戻す
        .onChange(of: chips.notice) { if chips.notice != nil { draft = chips.table?.bets[chips.myID] ?? [:] } }
        .sensoryFeedback(.success, trigger: table?.lastRound?.id)
    }

    /// 使える額が下限（なければ 1 pt）より少なくなったら、親に追加をお願いできる
    private func needsRebuy(_ table: ChipTable, balance: Int) -> Bool {
        balance - draft.values.reduce(0, +) < max(1, table.minBet)
    }

    private func rebuyRequestButton(_ table: ChipTable) -> some View {
        let requested = table.rebuyRequests.contains(chips.myID)
        return Button { chips.requestRebuy() } label: {
            Label(requested ? "追加をお願いしました" : "親に追加をお願いする", systemImage: "hand.raised.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Theme.warning.opacity(requested ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(requested)
    }

    /// 上の帯：みんなの残高とベット（見るだけ）。自分のカードは明るくする。
    private func membersBand(_ table: ChipTable) -> some View {
        let last = table.lastRound
        let members = table.members.filter { $0.id == chips.myID } + table.members.filter { $0.id != chips.myID }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(members) { m in
                    MemberBetCard(member: m, table: table, isMe: m.id == chips.myID,
                                  lastNet: last?.results.first { $0.member == m.id }?.net)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Theme.deck)
    }
}
