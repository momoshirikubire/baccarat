import AVFoundation
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
            HStack(spacing: 4) {
                Text("\(member.balance.formatted()) pt").font(.caption2.monospacedDigit()).opacity(0.8)
                // もらった合計（はじめの持ち点＋追加）からの増減
                let total = member.balance - (table.stats[member.id]?.dealt ?? table.startingChips)
                Text("(\(total == 0 ? "±0" : signed(total)))")
                    .font(.system(size: 9).monospacedDigit())
                    .opacity(0.65)
            }
            if table.rebuyRequests.contains(member.id) {
                Text("追加をお願い中")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.warning, in: Capsule())
            } else if spots.isEmpty {
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
    var onRebuy: (() -> Void)? = nil
    let onSave: ([BetSpot: Int]) -> Void
    @State private var spots: [BetSpot: Int]
    @Environment(\.dismiss) private var dismiss

    init(member: ChipMember, table: ChipTable, initial: [BetSpot: Int], onRebuy: (() -> Void)? = nil,
         onSave: @escaping ([BetSpot: Int]) -> Void) {
        self.member = member
        self.table = table
        self.onRebuy = onRebuy
        self.onSave = onSave
        _spots = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let onRebuy {
                    Button {
                        dismiss()
                        onRebuy()
                    } label: {
                        Label(table.rebuyRequests.contains(member.id) ? "追加する（お願いが来ています）" : "ポイントを追加する（リバイ）",
                              systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(table.rebuyRequests.contains(member.id) ? Theme.warning : Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                BetPad(spots: spots, balance: member.balance, commission: table.bankerCommission,
                       previous: table.lastRound?.bets[member.id],
                       minBet: table.minBet, maxBet: table.maxBet, startingChips: table.startingChips,
                       closed: table.betsClosed) { spots = $0 }
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
                    .disabled(table.betsClosed)
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
    /// 1か所あたりの下限・上限（0 は「なし」）
    var minBet = 0
    var maxBet = 0
    /// テーブルのはじめの持ち点（+100 などの段階を合わせる）
    var startingChips = 1000
    /// 記録係の画面の横に並べるときは、ボタンを低くする
    var compact = false
    /// 締め切り中は押せなくする
    var closed = false
    let onChange: ([BetSpot: Int]) -> Void
    /// 金額を選んでいる場所（押すとシートが開く）
    @State private var editing: BetSpot?

    /// 持ち点の 1/100・1/20・1/10・1/2 をきりのいい数に（持ち点 1,000 なら +10 / +50 / +100 / +500、10,000 なら +100 / +500 / +1,000 / +5,000）
    private var steps: [Int] {
        let s = Double(max(1, startingChips))
        var list: [Int] = []
        for r in [0.01, 0.05, 0.1, 0.5] {
            let v = BetLimitPreset.nice(s * r)
            if !list.contains(v) { list.append(v) }
        }
        return list
    }

    var body: some View {
        let staked = spots.values.reduce(0, +)
        VStack(spacing: 8) {
            if minBet > 0 || maxBet > 0 {
                Text("1か所あたり　下限 \(minBet > 0 ? minBet.formatted() : "なし") / 上限 \(maxBet > 0 ? maxBet.formatted() : "なし")")
                    .font(.caption2)
                    .opacity(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if closed {
                // 狭い列でも切れないように、見出しと説明を2行に分ける
                VStack(spacing: 1) {
                    Label("締め切り中", systemImage: "lock.fill").font(.caption.bold())
                    Text("勝敗を記録すると受付に戻ります")
                        .font(.caption2)
                        .opacity(0.85)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(Theme.banker, in: RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 6) {
                figure("残高", balance)
                figure("ベット中", staked)
                figure("使える", balance - staked)
            }
            Group {
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
                    padButton("前の手と同じ") { set(previous ?? [:]) }
                        .disabled(previous?.isEmpty ?? true)
                    padButton("ベットを消す") { set([:]) }
                        .disabled(spots.isEmpty)
                }
            }
            // 締め切り中は薄くして、押せないことが分かるようにする
            .opacity(closed ? 0.4 : 1)
        }
        .foregroundStyle(Theme.deckInk)
        .disabled(closed)
        .sheet(item: $editing) { spot in
            SpotAmountSheet(spot: spot, current: spots[spot] ?? 0,
                            available: balance - staked + (spots[spot] ?? 0),
                            minBet: minBet, maxBet: maxBet, steps: steps, commission: commission) { amount in
                change(spot, to: amount)
            }
            // 盤の明るい文字の色を引き継がないように
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
        }
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
        return Button { editing = spot } label: {
            VStack(spacing: 1) {
                Text(spot.title).font(height > 44 ? .headline : .footnote.bold()).lineLimit(1).minimumScaleFactor(0.7)
                Text(amount > 0 ? "\(amount.formatted()) pt" : spot.odds(commission: commission))
                    .font(.caption2.monospacedDigit())
                    .opacity(amount > 0 ? 1 : 0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Self.color(spot).opacity(amount > 0 ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: amount > 0 ? 2 : 0))
        }
        .buttonStyle(PressStyle())
        .accessibilityHint("押すと金額を選べます")
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

    private func clamp(_ amount: Int) -> Int {
        BetPad.clamp(amount, minBet: minBet, maxBet: maxBet)
    }

    /// 0 でなければ、下限以上・上限以下にそろえる（+10 を押しても下限に届くように、上限で止まるように）
    static func clamp(_ amount: Int, minBet: Int, maxBet: Int) -> Int {
        guard amount > 0 else { return 0 }
        var a = amount
        if minBet > 0 { a = max(a, minBet) }
        if maxBet > 0 { a = min(a, maxBet) }
        return a
    }

    private func set(_ new: [BetSpot: Int]) {
        guard new.values.reduce(0, +) <= balance else { return }
        // 「前の手と同じ」で、あとから変わった下限・上限から外れるものは入れない
        guard new.values.allSatisfy({ $0 <= 0 || clamp($0) == $0 }) else { return }
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

/// BANKER などを押したときに開く、その場所の金額を選ぶシート。「決定」で送り、「やめる」では何も変えない。
private struct SpotAmountSheet: View {
    let spot: BetSpot
    let current: Int
    /// この場所に置ける最大（使える額＋いまこの場所に置いている額）
    let available: Int
    let minBet: Int
    let maxBet: Int
    let steps: [Int]
    let commission: Bool
    let onDecide: (Int) -> Void
    @State private var amount: Int
    @Environment(\.dismiss) private var dismiss

    init(spot: BetSpot, current: Int, available: Int, minBet: Int, maxBet: Int, steps: [Int], commission: Bool,
         onDecide: @escaping (Int) -> Void) {
        self.spot = spot
        self.current = current
        self.available = available
        self.minBet = minBet
        self.maxBet = maxBet
        self.steps = steps
        self.commission = commission
        self.onDecide = onDecide
        _amount = State(initialValue: current)
    }

    /// 置ける上限（上限と使える額の小さいほう）
    private var cap: Int { maxBet > 0 ? min(maxBet, available) : available }

    var body: some View {
        NavigationStack {
            HStack(alignment: .center, spacing: 20) {
                // 左：場所と金額
                VStack(spacing: 8) {
                    Text(spot.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(BetPad.color(spot), in: Capsule())
                    Text("勝つと \(spot.odds(commission: commission))").font(.caption).foregroundStyle(Theme.muted)
                    Text("\(amount.formatted()) pt")
                        .font(.system(size: 44, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("使える \(available.formatted())\(minBet > 0 ? "・下限 \(minBet.formatted())" : "")\(maxBet > 0 ? "・上限 \(maxBet.formatted())" : "")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if amount > 0, minBet > 0, amount < minBet {
                        Text("下限より少ないので置けません").font(.caption.bold()).foregroundStyle(Theme.banker)
                    }
                }
                .frame(maxWidth: .infinity)

                // 右：金額のボタン
                VStack(spacing: 8) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(steps, id: \.self) { step in
                            let next = BetPad.clamp(amount + step, minBet: minBet, maxBet: maxBet)
                            amountButton("+\(step.formatted())") { amount = min(next, cap) }
                                .disabled(min(next, cap) <= amount)
                        }
                    }
                    HStack(spacing: 8) {
                        amountButton("0 にする") { amount = 0 }
                            .disabled(amount == 0)
                        amountButton("置けるだけ") { amount = cap }
                            .disabled(cap <= amount || (minBet > 0 && cap < minBet))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .frame(maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("\(spot.title) のベット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        onDecide(amount)
                        dismiss()
                    }
                    .bold()
                    .disabled(amount == current || (amount > 0 && minBet > 0 && amount < minBet))
                }
            }
        }
    }

    private func amountButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - ベットの締め切り

/// 「受付中」「締め切り」の札
struct BetStatusPill: View {
    let closed: Bool

    var body: some View {
        Label(closed ? "締め切り" : "受付中", systemImage: closed ? "lock.fill" : "circle.fill")
            .font(.caption.bold())
            .foregroundStyle(closed ? .white : .black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(closed ? Theme.banker : Theme.warning, in: Capsule())
            .accessibilityLabel(closed ? "ベットは締め切り" : "ベットを受け付け中")
    }
}

/// 締め切ったときに短く大きく出す「NO MORE BETS」と、英語の読み上げ
struct NoMoreBets {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak() {
        // 結果の読み上げと同じく、ほかの音を止めず消音スイッチに従う
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        let utterance = AVSpeechUtterance(string: "No more bets")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }
}

extension View {
    /// 1.5秒だけ「NO MORE BETS」を出す。タップでもすぐ消える。
    func noMoreBetsBanner(_ isShown: Binding<Bool>) -> some View {
        overlay {
            if isShown.wrappedValue {
                ZStack {
                    Color.black.opacity(0.82).ignoresSafeArea()
                    VStack(spacing: 6) {
                        Text("NO MORE BETS")
                            .font(.system(size: 72, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Text("ベットは締め切りました").font(.headline).opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { isShown.wrappedValue = false } }
                .task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeOut(duration: 0.3)) { isShown.wrappedValue = false }
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - ベットの下限・上限

/// ベットの下限・上限を選ぶ欄（テーブルを作る画面と、テーブルのシートで使う）
struct BetLimitPicker: View {
    let startingChips: Int
    @Binding var preset: BetLimitPreset
    @Binding var minBet: Int?
    @Binding var maxBet: Int?

    var body: some View {
        // 押しやすいように、大きめのボタンを並べる
        HStack(spacing: 6) {
            ForEach(BetLimitPreset.allCases) { p in
                Button { preset = p } label: {
                    Text(p.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(preset == p ? .white : Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(preset == p ? Theme.ink : Theme.background, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(preset == p ? .isSelected : [])
            }
        }
        if preset == .custom {
            field("下限（1か所あたり）", value: $minBet)
            field("上限（1か所あたり）", value: $maxBet)
        } else {
            LabeledContent("1か所あたり", value: text)
                .monospacedDigit()
        }
    }

    /// 選んでいる範囲の下限・上限（0 は「なし」）
    var limits: (min: Int, max: Int) {
        preset.limits(startingChips: startingChips) ?? (minBet ?? 0, maxBet ?? 0)
    }

    private var text: String {
        let l = limits
        if l.min == 0 && l.max == 0 { return "下限・上限なし" }
        return "下限 \(l.min.formatted()) / 上限 \(l.max.formatted())"
    }

    private func field(_ title: String, value: Binding<Int?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("なし", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            Text("pt").foregroundStyle(.secondary)
        }
    }
}
