import Foundation

/// チップのテーブル。実物のチップの代わりに、参加者の残高をポイントで数える。
/// お金には換えない（円は使わない）。
struct ChipTable: Codable, Hashable {
    var name: String
    var startingChips: Int
    var members: [ChipMember] = []
    var moves: [ChipMove] = []
    /// バカラの罫線画面で入れた、次の手へのベット（参加者ごと）
    var bets: [UUID: [BetSpot: Int]] = [:]
    /// バンカーの勝ちから手数料5%を引くか
    var bankerCommission = false
    /// 1か所あたりのベットの下限・上限（pt、0 は「なし」）
    var minBet = 0
    var maxBet = 0
    /// 親の罫線（いまのシュー）。子の端末はこれを表示する。
    var hands: [Hand] = []
    /// 精算した手。新しいものが最後。「1つ戻す」で取り消せるように少し残す。
    var rounds: [ChipRound] = []
    /// 参加者ごとの成績（終了したときの結果に使う）
    var stats: [UUID: ChipStats] = [:]
    /// 精算した手の数
    var settledHands = 0
    var createdAt = Date()
    /// 「親に追加をお願いする」を押した参加者
    var rebuyRequests: Set<UUID> = []
    /// ベットの締め切り（true のあいだはベットを入れられない）。精算すると次の手の受付に戻る。
    var betsClosed = false
    /// 場（親）の収支：精算で場が受け取った pt − 払った pt（持ち点の配布と追加は含めない）
    var bankNet = 0

    init(name: String, startingChips: Int, bankerCommission: Bool = false, minBet: Int = 0, maxBet: Int = 0) {
        self.name = name
        self.startingChips = startingChips
        self.bankerCommission = bankerCommission
        self.minBet = minBet
        self.maxBet = maxBet
    }

    private enum CodingKeys: String, CodingKey {
        case name, startingChips, members, moves, bets, bankerCommission, minBet, maxBet, hands, rounds
        case stats, settledHands, createdAt, rebuyRequests, betsClosed, bankNet
    }

    // 前に保存したテーブルも読めるように、足りない項目は既定の値にする（ポットがあった頃の pot は読み捨てる）
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        startingChips = try c.decode(Int.self, forKey: .startingChips)
        members = try c.decodeIfPresent([ChipMember].self, forKey: .members) ?? []
        moves = try c.decodeIfPresent([ChipMove].self, forKey: .moves) ?? []
        bets = try c.decodeIfPresent([UUID: [BetSpot: Int]].self, forKey: .bets) ?? [:]
        bankerCommission = try c.decodeIfPresent(Bool.self, forKey: .bankerCommission) ?? false
        minBet = try c.decodeIfPresent(Int.self, forKey: .minBet) ?? 0
        maxBet = try c.decodeIfPresent(Int.self, forKey: .maxBet) ?? 0
        hands = try c.decodeIfPresent([Hand].self, forKey: .hands) ?? []
        rounds = try c.decodeIfPresent([ChipRound].self, forKey: .rounds) ?? []
        stats = try c.decodeIfPresent([UUID: ChipStats].self, forKey: .stats) ?? [:]
        settledHands = try c.decodeIfPresent(Int.self, forKey: .settledHands) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        rebuyRequests = try c.decodeIfPresent(Set<UUID>.self, forKey: .rebuyRequests) ?? []
        betsClosed = try c.decodeIfPresent(Bool.self, forKey: .betsClosed) ?? false
        // 場の収支がなかった頃のデータは、プレイヤー全員の通算の増減から出す
        bankNet = try c.decodeIfPresent(Int.self, forKey: .bankNet) ?? -memberNetTotal
    }

    func member(_ id: UUID) -> ChipMember? {
        members.first { $0.id == id }
    }

    func name(of party: ChipParty) -> String {
        switch party {
        case .member(let id): member(id)?.name ?? "（抜けた人）"
        case .bank: "場"
        }
    }

    /// ベット中の合計
    func betTotal(_ id: UUID) -> Int {
        bets[id]?.values.reduce(0, +) ?? 0
    }

    /// 残高からベット中の分を引いた、使える額
    func available(_ id: UUID) -> Int {
        (member(id)?.balance ?? 0) - betTotal(id)
    }

    /// 動かせるかどうか。だめなときは理由を返す。場（bank）からはいくらでも出せる。
    func problem(with move: ChipMove) -> String? {
        guard move.amount > 0 else { return "1 pt 以上を入れてください。" }
        guard move.from != move.to else { return "同じところには動かせません。" }
        switch move.from {
        case .member(let id):
            guard let m = member(id) else { return "参加者が見つかりません。" }
            let free = available(id)
            if free < move.amount {
                return betTotal(id) > 0
                    ? "\(m.name)さんの使えるチップが足りません（ベット中を除いて \(free) pt）。"
                    : "\(m.name)さんのチップが足りません（\(m.balance) pt）。"
            }
        case .bank:
            break
        }
        if case .member(let id) = move.to, member(id) == nil { return "参加者が見つかりません。" }
        return nil
    }

    /// settlement が false（配る・回収する・渡す）のときは、場とのやり取りを「配られた持ち点」として数える
    mutating func apply(_ move: ChipMove, settlement: Bool = false) {
        add(-move.amount, to: move.from)
        add(move.amount, to: move.to)
        moves.append(move)
        guard !settlement else { return }
        switch (move.from, move.to) {
        case (.bank, .member(let id)): stats[id, default: ChipStats()].dealt += move.amount
        case (.member(let id), .bank): stats[id, default: ChipStats()].dealt -= move.amount
        default: break
        }
    }

    private mutating func add(_ amount: Int, to party: ChipParty) {
        switch party {
        case .member(let id):
            if let i = members.firstIndex(where: { $0.id == id }) { members[i].balance += amount }
        case .bank:
            break
        }
    }

    /// 参加する。はじめてなら持ち点を配る。同じ人がつなぎ直したときは残高をそのままにする。
    mutating func join(id: UUID, name: String) {
        if let i = members.firstIndex(where: { $0.id == id }) {
            members[i].name = name
            return
        }
        members.append(ChipMember(id: id, name: name, balance: 0))
        if startingChips > 0 {
            apply(ChipMove(from: .bank, to: .member(id), amount: startingChips, by: id))
        }
    }

    mutating func removeMember(_ id: UUID, by: UUID) {
        guard let m = member(id) else { return }
        bets[id] = nil
        // 抜ける人の残高は場へ戻す（履歴に残す）
        if m.balance > 0 { apply(ChipMove(from: .member(id), to: .bank, amount: m.balance, by: by)) }
        members.removeAll { $0.id == id }
    }

    /// プレイヤー全員の通算の増減（残高 − もらった合計）の合計
    var memberNetTotal: Int {
        members.reduce(0) { $0 + $1.balance - (stats[$1.id]?.dealt ?? startingChips) }
    }

    /// 追加（リバイ）：場からその人に pt を足す。もらった合計に入り、お願いの印は消える。
    mutating func rebuy(_ id: UUID, amount: Int, by: UUID) {
        guard amount > 0, member(id) != nil else { return }
        apply(ChipMove(from: .bank, to: .member(id), amount: amount, by: by, kind: .rebuy))
        stats[id, default: ChipStats()].rebuys += 1
        stats[id, default: ChipStats()].rebuyTotal += amount
        rebuyRequests.remove(id)
    }

    /// 全員の残高を持ち点に戻して、履歴を消す
    mutating func restart() {
        let people = members
        members = []
        moves = []
        bets = [:]
        rounds = []
        stats = [:]
        bankNet = 0
        rebuyRequests = []
        settledHands = 0
        createdAt = Date()
        for m in people { join(id: m.id, name: m.name) }
    }
}

/// 参加者ごとの成績。配られた持ち点（場から配られた分から、場へ戻した分を引いた額）と、勝った手・ベットした手の数。
struct ChipStats: Codable, Hashable {
    /// もらった合計（はじめの持ち点＋追加。場へ戻した分は引く）
    var dealt = 0
    var wins = 0
    var betHands = 0
    /// 追加（リバイ）の回数と合計
    var rebuys = 0
    var rebuyTotal = 0

    init(dealt: Int = 0) {
        self.dealt = dealt
    }

    private enum CodingKeys: String, CodingKey {
        case dealt, wins, betHands, rebuys, rebuyTotal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dealt = try c.decodeIfPresent(Int.self, forKey: .dealt) ?? 0
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        betHands = try c.decodeIfPresent(Int.self, forKey: .betHands) ?? 0
        rebuys = try c.decodeIfPresent(Int.self, forKey: .rebuys) ?? 0
        rebuyTotal = try c.decodeIfPresent(Int.self, forKey: .rebuyTotal) ?? 0
    }
}

/// 終了したテーブルの結果（全員に配り、親の端末には直近の分を残す）
struct ChipSummary: Codable, Hashable, Identifiable {
    var id = UUID()
    var tableName: String
    var startedAt: Date
    var endedAt: Date
    var hands: Int
    /// 増減の大きい順
    var rows: [Row]
    /// 場（親）の収支。前に残した結果にはない。
    var bankNet: Int? = nil

    struct Row: Codable, Hashable, Identifiable {
        var id: UUID
        var name: String
        var balance: Int
        /// はじめからの増減（残高 − 配られた持ち点）
        var net: Int
        var wins: Int
        var betHands: Int
        var rebuys = 0
        var rebuyTotal = 0

        init(id: UUID, name: String, balance: Int, net: Int, wins: Int, betHands: Int, rebuys: Int = 0, rebuyTotal: Int = 0) {
            self.id = id
            self.name = name
            self.balance = balance
            self.net = net
            self.wins = wins
            self.betHands = betHands
            self.rebuys = rebuys
            self.rebuyTotal = rebuyTotal
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, balance, net, wins, betHands, rebuys, rebuyTotal
        }

        // 追加（リバイ）より前に残した結果も読めるように
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            balance = try c.decode(Int.self, forKey: .balance)
            net = try c.decode(Int.self, forKey: .net)
            wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
            betHands = try c.decodeIfPresent(Int.self, forKey: .betHands) ?? 0
            rebuys = try c.decodeIfPresent(Int.self, forKey: .rebuys) ?? 0
            rebuyTotal = try c.decodeIfPresent(Int.self, forKey: .rebuyTotal) ?? 0
        }
    }
}

extension ChipTable {
    func summary(endedAt: Date = Date()) -> ChipSummary {
        let rows = members.map { m in
            let s = stats[m.id] ?? ChipStats(dealt: startingChips)
            return ChipSummary.Row(id: m.id, name: m.name, balance: m.balance, net: m.balance - s.dealt,
                                   wins: s.wins, betHands: s.betHands, rebuys: s.rebuys, rebuyTotal: s.rebuyTotal)
        }
        .sorted { $0.net != $1.net ? $0.net > $1.net : $0.balance > $1.balance }
        return ChipSummary(tableName: name, startedAt: createdAt, endedAt: endedAt, hands: settledHands, rows: rows,
                           bankNet: bankNet)
    }
}

struct ChipMember: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var balance: Int
}

/// チップの行き先。bank は配ったり、バカラの精算で払ったり受け取ったりする「場」。
enum ChipParty: Codable, Hashable {
    case member(UUID)
    case bank

    private enum CodingKeys: String, CodingKey {
        case member, bank, pot
    }

    private enum MemberKeys: String, CodingKey {
        case _0
    }

    // 書き方は自動で作られる形（{"member":{"_0":…}} / {"bank":{}}）に合わせる。
    // ポットがあった頃の履歴の "pot" は「場」として読む。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.member) {
            let m = try c.nestedContainer(keyedBy: MemberKeys.self, forKey: .member)
            self = .member(try m.decode(UUID.self, forKey: ._0))
        } else {
            self = .bank
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .member(let id):
            var m = c.nestedContainer(keyedBy: MemberKeys.self, forKey: .member)
            try m.encode(id, forKey: ._0)
        case .bank:
            _ = c.nestedContainer(keyedBy: MemberKeys.self, forKey: .bank)
        }
    }
}

struct ChipMove: Codable, Hashable, Identifiable {
    var id = UUID()
    var date = Date()
    var from: ChipParty
    var to: ChipParty
    var amount: Int
    /// 操作した人
    var by: UUID
    /// 追加（リバイ）など、履歴に分かるように出す種類。前の保存データにはない。
    var kind: Kind? = nil

    enum Kind: String, Codable {
        case rebuy
    }
}
