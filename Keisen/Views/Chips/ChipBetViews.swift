import SwiftUI

// バカラ×チップの画面（親・プレイヤー）で使う部品

/// 「第12手 BANKER　あなた +95 pt」と全員の増減
struct SettlementLine: View {
    let round: ChipRound
    let myID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("第\(round.handNumber)手").font(.caption.bold())
                Text(BetSpot.title(round.hand.outcome))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.color(round.hand.outcome), in: Capsule())
                if round.hand.bankerPair { pairTag(BetSpot.bankerPair.title, Theme.banker) }
                if round.hand.playerPair { pairTag(BetSpot.playerPair.title, Theme.player) }
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

func signed(_ v: Int) -> String {
    v > 0 ? "+\(v.formatted())" : v.formatted()
}

struct MemberBetCard: View {
    let member: ChipMember
    let table: ChipTable
    var isMe = false
    /// 直前の精算での増減（親の帯に出す）
    var lastNet: Int? = nil

    var body: some View {
        let spots = table.bets[member.id] ?? [:]
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(member.name).font(.caption.bold()).lineLimit(1)
                if isMe { Text("あなた").font(.system(size: 9)).opacity(0.7) }
                Spacer(minLength: 4)
                if let lastNet {
                    Text(signed(lastNet))
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(lastNet > 0 ? Color(light: 0x6FD9A8, dark: 0x6FD9A8)
                                         : lastNet < 0 ? Color(light: 0xFF8A96, dark: 0xFF8A96) : Theme.deckInk)
                }
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
        .frame(minWidth: 110, alignment: .leading)
        .background(isMe ? Color(light: 0x3E4C45, dark: 0x2C3A33) : Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isMe ? Theme.deckInk.opacity(0.9) : .clear, lineWidth: 1.5))
    }

    private func color(_ spot: BetSpot) -> Color {
        switch spot {
        case .banker, .bankerPair: Color(light: 0xFF8A96, dark: 0xFF8A96)
        case .player, .playerPair: Color(light: 0x9DB6FF, dark: 0x9DB6FF)
        case .tie: Color(light: 0x6FD9A8, dark: 0x6FD9A8)
        }
    }
}

/// 1人分のベットを入れるシート（親がアプリのない人の代わりに入れる）
struct BetSheet: View {
    let member: ChipMember
    let table: ChipTable
    let onSave: ([BetSpot: Int]) -> Void
    @State private var spots: [BetSpot: Int]
    @Environment(\.dismiss) private var dismiss

    init(member: ChipMember, table: ChipTable, initial: [BetSpot: Int], onSave: @escaping ([BetSpot: Int]) -> Void) {
        self.member = member
        self.table = table
        self.onSave = onSave
        _spots = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                BetPad(spots: spots, balance: member.balance, commission: table.bankerCommission,
                       previous: table.lastRound?.bets[member.id]) { spots = $0 }
                    .padding(16)
                    .background(Theme.deck, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                Text("TIE のときは、BANKER と PLAYER へのベットはそのまま戻り、次の手にも残ります。\(table.bankerCommission ? "BANKER の勝ちは手数料5%を引いて、1 pt 未満は切り捨てます。" : "")")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
            }
            .background(Theme.background)
            .navigationTitle("\(member.name)のベット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決める") {
                        onSave(spots)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// ベットを入れる盤：残高・ベット中・使える額、BANKER / TIE / PLAYER / B PAIR / P PAIR のボタン、金額のボタン。
/// ボタンを押して場所を選び、+10 などで額を足す。残高を超える分は入らない。
struct BetPad: View {
    let spots: [BetSpot: Int]
    let balance: Int
    let commission: Bool
    /// 前の手のベット（「前の手と同じ」）
    let previous: [BetSpot: Int]?
    /// 記録係の画面の横に並べるときは、ボタンを低くする
    var compact = false
    let onChange: ([BetSpot: Int]) -> Void
    @State private var selected: BetSpot = .banker

    private static let steps = [10, 50, 100, 500]

    var body: some View {
        let staked = spots.values.reduce(0, +)
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                figure("残高", balance)
                figure("ベット中", staked)
                figure("使える", balance - staked)
            }
            HStack(spacing: 6) {
                spotButton(.banker, height: compact ? 48 : 64)
                spotButton(.tie, height: compact ? 48 : 64).frame(maxWidth: compact ? 64 : 84)
                spotButton(.player, height: compact ? 48 : 64)
            }
            HStack(spacing: 6) {
                spotButton(.bankerPair, height: compact ? 32 : 40)
                spotButton(.playerPair, height: compact ? 32 : 40)
            }
            HStack(spacing: 6) {
                ForEach(Self.steps, id: \.self) { step in
                    padButton("+\(step)") { change(selected, to: (spots[selected] ?? 0) + step) }
                        .disabled(balance - staked < step)
                }
                padButton("0") { change(selected, to: 0) }
            }
            HStack(spacing: 6) {
                padButton("前の手と同じ") { set(previous ?? [:]) }
                    .disabled(previous?.isEmpty ?? true)
                padButton("ベットを消す") { set([:]) }
                    .disabled(spots.isEmpty)
            }
        }
        .foregroundStyle(Theme.deckInk)
    }

    private func figure(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 10)).opacity(0.7)
            Text("\(value.formatted())").font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
    }

    private func spotButton(_ spot: BetSpot, height: CGFloat) -> some View {
        let amount = spots[spot] ?? 0
        let isSelected = selected == spot
        return Button { selected = spot } label: {
            VStack(spacing: 1) {
                Text(spot.title).font(height > 44 ? .headline : .footnote.bold()).lineLimit(1).minimumScaleFactor(0.7)
                Text(amount > 0 ? "\(amount.formatted()) pt" : spot.odds(commission: commission))
                    .font(.caption2.monospacedDigit())
                    .opacity(amount > 0 ? 1 : 0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Self.color(spot).opacity(amount > 0 || isSelected ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: isSelected ? 3 : 0))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func padButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity, minHeight: compact ? 28 : 34)
                .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressStyle())
    }

    private func change(_ spot: BetSpot, to amount: Int) {
        var d = spots
        d[spot] = amount > 0 ? amount : nil
        set(d)
    }

    private func set(_ new: [BetSpot: Int]) {
        guard new.values.reduce(0, +) <= balance else { return }
        onChange(new)
    }

    static func color(_ spot: BetSpot) -> Color {
        switch spot {
        case .banker, .bankerPair: Theme.banker
        case .player, .playerPair: Theme.player
        case .tie: Theme.tie
        }
    }
}
