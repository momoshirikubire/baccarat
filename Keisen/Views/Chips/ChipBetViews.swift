import SwiftUI

/// バカラのタブ。チップのテーブルに子として参加しているあいだは、親の罫線とベット欄を出す。
struct BaccaratView: View {
    let shoe: ShoeStore
    let chips: ChipStore

    var body: some View {
        if chips.role == .guest, chips.table != nil {
            GuestBaccaratView(chips: chips)
        } else {
            RoadGameView(store: shoe, chips: chips)
        }
    }
}

/// 子の端末のバカラ画面。罫線は親が入れたものを表示するだけで、入力盤は出さない。
private struct GuestBaccaratView: View {
    let chips: ChipStore
    @State private var showChips = false

    var body: some View {
        let hands = chips.table?.hands ?? []
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Text("結果は親の iPhone で入れます。ここには親の罫線が出ます。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StatsBar(game: .baccarat, shoe: Shoe(hands: hands))
                    RoadsBoard(game: .baccarat, hands: hands)
                }
                .padding(12)
            }
            .background(Theme.background)
            .navigationTitle("バカラ・\(hands.count) 手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ChipScreenButton(isPresented: $showChips) }
            }
            .tipButton()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChipBetBar(chips: chips)
                    .background(Theme.deck.ignoresSafeArea(edges: .bottom))
            }
            .sheet(isPresented: $showChips) { ChipView(store: chips) }
        }
    }
}

/// ツールバーからチップの画面を開くボタン
struct ChipScreenButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button { isPresented = true } label: {
            Label("チップ", systemImage: "circle.circle")
        }
    }
}

/// 入力盤の上に出すベット欄。参加者ごとのベットと、最後の精算。
struct ChipBetBar: View {
    let chips: ChipStore
    @State private var editing: ChipMember?

    var body: some View {
        if let table = chips.table {
            VStack(alignment: .leading, spacing: 6) {
                if let round = table.lastRound {
                    SettlementLine(round: round, myID: chips.myID)
                        .id(round.id)
                        .transition(.opacity)
                } else {
                    Text("名前をタップしてベットを入れます。勝敗を押すと精算します。")
                        .font(.caption2)
                        .foregroundStyle(Theme.deckInk.opacity(0.7))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(table.members) { m in
                            Button { editing = m } label: {
                                MemberBetCard(member: m, table: table, isMe: m.id == chips.myID)
                            }
                            .buttonStyle(PressStyle())
                            .disabled(!canEdit(m))
                        }
                        if table.members.isEmpty {
                            Text("チップの画面で参加者を足してください。")
                                .font(.caption)
                                .foregroundStyle(Theme.deckInk.opacity(0.7))
                        }
                    }
                }
            }
            .foregroundStyle(Theme.deckInk)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .animation(.easeOut(duration: 0.2), value: table.lastRound?.id)
            .sensoryFeedback(.success, trigger: table.lastRound?.id)
            .sheet(item: $editing) { m in
                BetSheet(member: m, table: table, initial: table.bets[m.id] ?? [:]) { spots in
                    chips.placeBet(spots, for: m.id)
                }
            }
        }
    }

    /// 親は全員分、子は自分の分だけ
    private func canEdit(_ m: ChipMember) -> Bool {
        chips.role == .host || m.id == chips.myID
    }
}

/// 「第12手 バンカー　あなた +95 pt」と全員の増減
private struct SettlementLine: View {
    let round: ChipRound
    let myID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("第\(round.handNumber)手").font(.caption.bold())
                Text(RoadGame.baccarat.name(round.hand.outcome))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.color(round.hand.outcome), in: Capsule())
                if round.hand.bankerPair { pairTag("Bペア", Theme.banker) }
                if round.hand.playerPair { pairTag("Pペア", Theme.player) }
                if let mine = round.results.first(where: { $0.member == myID }) {
                    Text("あなた \(signed(mine.net)) pt")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(color(mine.net))
                }
                Spacer(minLength: 0)
            }
            let others = round.results.filter { $0.member != myID }
            if round.results.isEmpty {
                Text("ベットはありませんでした。").font(.caption2).opacity(0.7)
            } else if !others.isEmpty {
                Text(others.map { "\($0.name) \(signed($0.net))" }.joined(separator: "　"))
                    .font(.caption2.monospacedDigit())
                    .opacity(0.85)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func pairTag(_ title: String, _ color: Color) -> some View {
        Text(title).font(.caption2.bold()).foregroundStyle(color)
    }

    private func color(_ net: Int) -> Color {
        net > 0 ? Theme.tie : net < 0 ? Theme.banker : Theme.deckInk
    }
}

private func signed(_ v: Int) -> String {
    v > 0 ? "+\(v.formatted())" : v.formatted()
}

private struct MemberBetCard: View {
    let member: ChipMember
    let table: ChipTable
    let isMe: Bool

    var body: some View {
        let spots = table.bets[member.id] ?? [:]
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(member.name).font(.caption.bold()).lineLimit(1)
                if isMe { Text("あなた").font(.system(size: 9)).opacity(0.7) }
            }
            Text("\(member.balance.formatted()) pt").font(.caption2.monospacedDigit()).opacity(0.8)
            if spots.isEmpty {
                Text("ベットなし").font(.caption2).opacity(0.6)
            } else {
                HStack(spacing: 4) {
                    ForEach(BetSpot.allCases.filter { (spots[$0] ?? 0) > 0 }) { spot in
                        Text("\(spot.short) \(spots[spot]!.formatted())")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(color(spot))
                    }
                }
            }
        }
        .foregroundStyle(Theme.deckInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minWidth: 96, alignment: .leading)
        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isMe ? Theme.deckInk.opacity(0.5) : .clear))
    }

    private func color(_ spot: BetSpot) -> Color {
        switch spot {
        case .banker, .bankerPair: Color(light: 0xFF8A96, dark: 0xFF8A96)
        case .player, .playerPair: Color(light: 0x9DB6FF, dark: 0x9DB6FF)
        case .tie: Color(light: 0x6FD9A8, dark: 0x6FD9A8)
        }
    }
}

/// 1人分のベットを入れるシート
private struct BetSheet: View {
    let member: ChipMember
    let table: ChipTable
    let onSave: ([BetSpot: Int]) -> Void
    @State private var spots: [BetSpot: Int]
    @Environment(\.dismiss) private var dismiss

    private static let steps = [10, 50, 100, 500]

    init(member: ChipMember, table: ChipTable, initial: [BetSpot: Int], onSave: @escaping ([BetSpot: Int]) -> Void) {
        self.member = member
        self.table = table
        self.onSave = onSave
        _spots = State(initialValue: initial)
    }

    private var total: Int { spots.values.reduce(0, +) }
    private var previous: [BetSpot: Int]? { table.lastRound?.bets[member.id] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("持ち点", value: "\(member.balance.formatted()) pt")
                    LabeledContent("ベットの合計") {
                        Text("\(total.formatted()) pt")
                            .foregroundStyle(total > member.balance ? Theme.banker : Theme.ink)
                    }
                } footer: {
                    if total > member.balance { Text("持ち点より多くは入れられません。") }
                }

                ForEach(BetSpot.allCases) { spot in
                    Section {
                        HStack {
                            TextField("0", value: amount(spot), format: .number)
                                .keyboardType(.numberPad)
                                .font(.title3.bold().monospacedDigit())
                            Text("pt").foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            ForEach(Self.steps, id: \.self) { step in
                                Button("+\(step)") { spots[spot, default: 0] += step }
                                    .buttonStyle(.bordered)
                            }
                            Button("0") { spots[spot] = nil }.buttonStyle(.bordered)
                        }
                        .font(.footnote)
                    } header: {
                        Text("\(spot.title)（勝つと \(spot.odds(commission: table.bankerCommission))）")
                    }
                }

                Section {
                    if let previous, !previous.isEmpty {
                        Button("前の手と同じにする") { spots = previous }
                    }
                    Button("ベットをすべて消す", role: .destructive) { spots = [:] }
                } footer: {
                    Text("タイのときは、バンカーとプレイヤーへのベットはそのまま戻ります。\(table.bankerCommission ? "バンカーの勝ちは手数料5%を引いて、1 pt 未満は切り捨てます。" : "")")
                }
            }
            .navigationTitle("\(member.name)のベット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決める") {
                        onSave(spots)
                        dismiss()
                    }
                    .disabled(total > member.balance)
                }
            }
        }
    }

    private func amount(_ spot: BetSpot) -> Binding<Int?> {
        Binding(
            get: { spots[spot].flatMap { $0 > 0 ? $0 : nil } },
            set: { spots[spot] = $0.flatMap { $0 > 0 ? $0 : nil } }
        )
    }
}
