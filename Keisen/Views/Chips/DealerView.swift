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
                DealerSetupView(chips: chips) {
                    // 新しいテーブルは空の罫線から始める（いまのシューは「過去のシュー」へ、例のシューは捨てる）
                    shoe.startNewShoe()
                }
            }
        }
        .modifier(ChipNoticeAlert(store: chips))
        // テーブルを終えたら、そのテーブルの罫線を「過去のシュー」に回す（罫線だけに戻っても続きにならない）
        .onChange(of: chips.table == nil) { _, ended in
            if ended, !shoe.current.hands.isEmpty { shoe.startNewShoe() }
        }
    }
}

// MARK: - テーブルを作る

private struct DealerSetupView: View {
    @Bindable var chips: ChipStore
    /// テーブルを作る直前に呼ぶ（罫線を空にする）
    let onCreate: () -> Void
    @State private var tableName = ""
    @State private var startingChips = 10000
    /// 持ち点を候補から選ばず、自分で入れる
    @State private var customChips = false
    @State private var bankerCommission = false
    /// 親を置かず、記録係も自分のベットを入れる
    @State private var hostBets = false
    /// 1か所あたりのベットの下限・上限（空は「なし」）
    @State private var minBet: Int?
    @State private var maxBet: Int?
    @State private var limitPreset: BetLimitPreset = .normal
    @State private var showPast = false
    @FocusState private var focused: Bool

    private static let chipChoices = [10000, 30000, 50000, 100000]

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 14) {
                // 左：入力（カードごとにまとめる）
                ScrollView {
                    VStack(spacing: 12) {
                        card("名前") {
                            field("あなた", placeholder: "みんなの画面に出る名前", text: $chips.myName)
                            field("テーブル", placeholder: "\(defaultTableName)（空のままでよい）", text: $tableName)
                        }
                        card("はじめの持ち点") {
                            HStack(spacing: 6) {
                                ForEach(Self.chipChoices, id: \.self) { amount in
                                    choice(amount.formatted(), selected: !customChips && startingChips == amount) {
                                        customChips = false
                                        startingChips = amount
                                        focused = false
                                    }
                                }
                                choice("自分で決める", selected: customChips) { customChips = true }
                            }
                            if customChips {
                                HStack {
                                    TextField("1000", value: $startingChips, format: .number)
                                        .keyboardType(.numberPad)
                                        .focused($focused)
                                        .font(.title3.bold().monospacedDigit())
                                        .padding(.horizontal, 10)
                                        .frame(height: 40)
                                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
                                    Text("pt").foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        card("ベットの範囲（1か所あたり）") {
                            BetLimitPicker(startingChips: max(1, startingChips), preset: $limitPreset,
                                           minBet: $minBet, maxBet: $maxBet)
                        }
                        card("ルール") {
                            toggle("BANKER の手数料 5%", detail: "オンにすると BANKER の勝ちは 0.95倍", isOn: $bankerCommission)
                            Divider()
                            toggle("自分もプレイヤーとしてベットする", detail: "親を置かずに、みんなで遊ぶとき", isOn: $hostBets)
                        }
                        if !chips.pastSummaries.isEmpty {
                            Button { showPast = true } label: {
                                Label("これまでの結果（\(chips.pastSummaries.count)）", systemImage: "list.number")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                // 右：こんなテーブルになります（要約）と、いつも見える「テーブルを作る」
                VStack(spacing: 10) {
                    ScrollView { summary }
                    Button(action: create) {
                        Label("テーブルを作る", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.vertical, 12)
                .frame(width: 270)
            }
            .padding(.horizontal, 16)
            .background(Theme.background)
            .navigationTitle("テーブルを作る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ModeButton(chips: chips) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = false }
                }
            }
            .sheet(isPresented: $showPast) {
                NavigationStack {
                    List { PastSummariesList(summaries: chips.pastSummaries) }
                        .navigationTitle("これまでの結果")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("閉じる") { showPast = false } }
                        }
                }
            }
        }
    }

    // MARK: 右の要約

    private var summary: some View {
        let l = chosenLimits
        return VStack(alignment: .leading, spacing: 10) {
            Text("こんなテーブルになります").font(.caption.bold()).foregroundStyle(Theme.deckInk.opacity(0.7))
            Text(finalTableName).font(.title3.bold()).lineLimit(2)
            row("持ち点", "\(max(1, startingChips).formatted()) pt")
            row("ベットの範囲", l.min == 0 && l.max == 0 ? "なし" : "\(l.min.formatted())〜\(l.max.formatted()) pt")
            row("BANKER", bankerCommission ? "0.95倍" : "1倍")
            row("親のベット", hostBets ? "する" : "しない")
            Text("作ると4桁の参加番号が出ます。pt は遊び用で、お金には換えられません。")
                .font(.caption2)
                .foregroundStyle(Theme.deckInk.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.deckInk)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.deck, in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline).opacity(0.75)
            Spacer()
            Text(value).font(.headline.monospacedDigit())
        }
    }

    // MARK: 部品

    private var defaultTableName: String {
        let me = chips.myName.trimmingCharacters(in: .whitespaces)
        return me.isEmpty ? "テーブル" : "\(me)のテーブル"
    }

    private var finalTableName: String {
        let name = tableName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? defaultTableName : name
    }

    private func create() {
        focused = false
        onCreate()
        chips.createTable(name: finalTableName, startingChips: max(1, startingChips),
                          hostPlays: hostBets, bankerCommission: bankerCommission,
                          minBet: chosenLimits.min, maxBet: chosenLimits.max)
        chips.setOpen(true)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.bold()).foregroundStyle(Theme.muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.subheadline).frame(width: 72, alignment: .leading)
            TextField(placeholder, text: text)
                .focused($focused)
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(selected ? .white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? Theme.ink : Theme.background, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressStyle())
    }

    /// 行のどこを押しても切り替わるトグル（スイッチだけだと小さくて押しにくい）
    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(Theme.ink)
                    Text(detail).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: isOn).labelsHidden().allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn.wrappedValue ? "オン" : "オフ")
        .accessibilityAddTraits(.isToggle)
    }

    private var chosenLimits: (min: Int, max: Int) {
        BetLimitPicker(startingChips: max(1, startingChips), preset: .constant(limitPreset),
                       minBet: .constant(minBet), maxBet: .constant(maxBet)).limits
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
    /// 新しいシューを始めた回数（応援のお願いを出すきっかけ）
    @State private var nudgeTrigger = 0
    @AppStorage("roads.showAll") private var showAllRoads = false
    @AppStorage("tieStyle") private var tieStyle: TieStyle = .dot
    @AppStorage("speakResults") private var speakResults = true
    @State private var announcement: ResultAnnouncement?
    @State private var showRules = false
    @State private var showNoMoreBets = false
    @State private var rebuyTarget: ChipMember?
    @State private var rebuyAmount: Int?

    private func startRebuy(_ m: ChipMember) {
        rebuyAmount = chips.table?.startingChips ?? 1000
        rebuyTarget = m
    }

    /// ベットの受付と締め切り。受付中は大きな「締め切る」、締め切り中はそのことを出す（勝敗で次の手の受付に戻る）。
    @ViewBuilder private var closeBar: some View {
        let closed = chips.table?.betsClosed ?? false
        if closed {
            HStack(spacing: 6) {
                BetStatusPill(closed: true)
                Text("勝敗で次の手へ").font(.caption2).foregroundStyle(Theme.deckInk.opacity(0.7))
                Spacer(minLength: 0)
            }
        } else {
            Button {
                chips.closeBets()
                withAnimation(.easeOut(duration: 0.15)) { showNoMoreBets = true }
                if speakResults { NoMoreBets.speak() }
            } label: {
                Label("締め切る（NO MORE BETS）", systemImage: "lock.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Theme.warning, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressStyle())
        }
    }

    /// 記録係も自分でベットしているか
    private var isPlaying: Bool { chips.table?.member(chips.myID) != nil }

    /// プレイヤーに配る罫線（例のシューは配らない）
    private var sharedHands: [Hand] { shoe.isSample ? [] : shoe.current.hands }

    var body: some View {
        NavigationStack {
                HStack(spacing: 0) {
                    GeometryReader { geo in
                        // 上に参加者の帯があって高さが足りないので、罫線画面のような細い入力盤にはしない
                        RoadBoardColumn(hands: shoe.current.hands, isSample: shoe.isSample,
                                        height: geo.size.height, showAll: $showAllRoads)
                    }
                    if let table = chips.table, let me = table.member(chips.myID) {
                        myBetColumn(table, me)
                    }
                    VStack(spacing: 0) {
                        closeBar
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
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
                            smallButtonHeight: 44,
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
                    // ペアのボタンがホームインジケータに寄りすぎないように、下に余白をとる
                    .padding(.bottom, 10)
                    .frame(width: isPlaying ? 240 : 300)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .background(Theme.deck.ignoresSafeArea())
                }
            // 参加者の帯はツールバーのすぐ下に固定する（中身が高くなっても重ならない）
            .safeAreaInset(edge: .top, spacing: 0) {
                if let table = chips.table { band(table) }
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
                    // ボタンが入りきるように、手の数だけを短く出す
                    Text("\(sharedHands.count) 手").font(.headline).fixedSize()
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
                        Toggle("珠盤路・下三路・問路も見る", isOn: $showAllRoads)
                        Toggle("結果を英語で読み上げる", isOn: $speakResults)
                    } label: {
                        ToolbarTitle("表示", systemImage: "slider.horizontal.3")
                    }
                }
                // 横向きでもボタンが全部見えるように、シューのことは1つのメニューにまとめる
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { confirmNewShoe = true } label: {
                            Label("新しいシューを始める", systemImage: "plus.rectangle.on.rectangle")
                        }
                        Button { showHistory = true } label: {
                            Label("過去のシュー", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        ToolbarTitle("シュー", systemImage: "rectangle.stack")
                    }
                }
            }
            .tipButton()
        }
        .resultSplash($announcement)
        .noMoreBetsBanner($showNoMoreBets)
        .onAppear {
            chips.syncHands(sharedHands)
            // アプリを開き直したときも、近くのプレイヤーが参加し直せるようにする
            if !chips.isOpen { chips.setOpen(true) }
        }
        .sheet(item: $editing) { m in
            if let table = chips.table {
                BetSheet(member: m, table: table, initial: table.bets[m.id] ?? [:],
                         onRebuy: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { startRebuy(m) } }) { spots in
                    chips.placeBet(spots, for: m.id)
                }
            }
        }
        .sheet(isPresented: $showManage) { ChipManageSheet(store: chips) }
        .sheet(isPresented: $showHistory) { HistoryView(store: shoe) }
        .sheet(isPresented: $showRules) { RulesView() }
        .alert("追加（リバイ）", isPresented: Binding(get: { rebuyTarget != nil }, set: { if !$0 { rebuyTarget = nil } })) {
            TextField("pt", value: $rebuyAmount, format: .number).keyboardType(.numberPad)
            Button("追加する") {
                if let m = rebuyTarget, let amount = rebuyAmount, amount > 0 { chips.rebuy(m.id, amount: amount) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(rebuyTarget?.name ?? "")さんに、場から pt を足します。")
        }
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
                nudgeTrigger += 1
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("いまのシューは「過去のシュー」に残ります。チップの残高はそのままです。")
        }
        .tipNudge(trigger: nudgeTrigger)
    }

    /// 記録係が自分でもベットするときの列。勝敗のボタンと取り違えないように、明るい背景と見出しで分ける。
    private func myBetColumn(_ table: ChipTable, _ me: ChipMember) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("あなたのベット").font(.caption.bold())
                Spacer(minLength: 4)
                // 親は自分の分の追加（リバイ）をお願いせずにそのまま入れられる
                Button { startRebuy(me) } label: {
                    Label("ポイントを追加", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.warning, in: Capsule())
                }
            }
            // 締め切りの札などで高くなっても上の帯を押し上げないように、盤だけスクロールできるようにして下に寄せる
            ScrollView {
                BetPad(spots: table.bets[me.id] ?? [:], balance: me.balance, commission: table.bankerCommission,
                       previous: table.lastRound?.bets[me.id],
                       minBet: table.minBet, maxBet: table.maxBet, startingChips: table.startingChips,
                       compact: true, closed: table.betsClosed) { spots in
                    chips.placeBet(spots, for: me.id)
                }
            }
            .defaultScrollAnchor(.bottom)
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(Theme.deckInk)
        .padding(10)
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(Color(light: 0x2F3A34, dark: 0x1A2420))
    }

    /// 上の帯：参加番号・直前の結果・プレイヤーごとの残高とベットと増減
    private func band(_ table: ChipTable) -> some View {
        let last = table.lastRound
        return HStack(spacing: 8) {
            // 縦に高くならないように、横に2列で並べる（高いとツールバーの下にもぐる）
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    if chips.isOpen {
                        Text("参加番号").font(.system(size: 9)).opacity(0.7)
                        Text(chips.code).font(.title3.bold().monospacedDigit())
                        Text("\(chips.connectedCount) 台つながっている").font(.system(size: 9)).opacity(0.7)
                    } else {
                        Text("近くの人は\n参加できません").font(.caption2).opacity(0.7)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    BetStatusPill(closed: table.betsClosed)
                    Text("場 \(table.bankNet == 0 ? "±0" : signed(table.bankNet)) pt")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(table.bankNet > 0 ? Color(light: 0x6FD9A8, dark: 0x6FD9A8)
                                         : table.bankNet < 0 ? Color(light: 0xFF8A96, dark: 0xFF8A96) : Theme.deckInk)
                    if let limits = table.limitText {
                        Text(limits).font(.system(size: 9)).opacity(0.7)
                    }
                }
            }
            .fixedSize()
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
                        VStack(spacing: 3) {
                            Button { editing = m } label: {
                                MemberBetCard(member: m, table: table,
                                              lastNet: last?.results.first { $0.member == m.id }?.net)
                            }
                            .buttonStyle(PressStyle())
                            if table.rebuyRequests.contains(m.id) {
                                Button { startRebuy(m) } label: {
                                    Text("追加する")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity, minHeight: 22)
                                        .background(Theme.warning, in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
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
        .padding(.top, 10)
        .padding(.bottom, 6)
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
    /// 大路だけを大きく置く（集計とボタンは出さない。集計は右の入力盤に出る）
    var compact = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !compact {
                    StatsBar(game: .baccarat, shoe: Shoe(hands: isSample ? [] : hands))
                }
                RoadsBoard(game: .baccarat, hands: isSample ? [] : hands, scale: 1.35, showAll: showAll,
                           fitCell: max(20, min(compact ? 80 : 42, (height - (compact ? 52 : 130)) / CGFloat(Roads.rows))))
                if !compact {
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
            }
            .padding(compact ? 8 : 12)
        }
        .background(Theme.background)
    }
}
