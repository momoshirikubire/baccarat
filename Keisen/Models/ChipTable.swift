import Foundation

/// チップのテーブル。実物のチップの代わりに、参加者の残高とポットをポイントで数える。
/// お金には換えない（円は使わない）。
struct ChipTable: Codable, Hashable {
    var name: String
    var startingChips: Int
    var members: [ChipMember] = []
    var pot = 0
    var moves: [ChipMove] = []
    /// バカラの罫線画面で入れた、次の手へのベット（参加者ごと）
    var bets: [UUID: [BetSpot: Int]] = [:]
    /// バンカーの勝ちから手数料5%を引くか
    var bankerCommission = false
    /// 親の罫線（いまのシュー）。子の端末はこれを表示する。
    var hands: [Hand] = []
    /// 精算した手。新しいものが最後。「1つ戻す」で取り消せるように少し残す。
    var rounds: [ChipRound] = []

    init(name: String, startingChips: Int, bankerCommission: Bool = false) {
        self.name = name
        self.startingChips = startingChips
        self.bankerCommission = bankerCommission
    }

    private enum CodingKeys: String, CodingKey {
        case name, startingChips, members, pot, moves, bets, bankerCommission, hands, rounds
    }

    // ベットより前に保存したテーブルも読めるように、足りない項目は既定の値にする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        startingChips = try c.decode(Int.self, forKey: .startingChips)
        members = try c.decodeIfPresent([ChipMember].self, forKey: .members) ?? []
        pot = try c.decodeIfPresent(Int.self, forKey: .pot) ?? 0
        moves = try c.decodeIfPresent([ChipMove].self, forKey: .moves) ?? []
        bets = try c.decodeIfPresent([UUID: [BetSpot: Int]].self, forKey: .bets) ?? [:]
        bankerCommission = try c.decodeIfPresent(Bool.self, forKey: .bankerCommission) ?? false
        hands = try c.decodeIfPresent([Hand].self, forKey: .hands) ?? []
        rounds = try c.decodeIfPresent([ChipRound].self, forKey: .rounds) ?? []
    }

    func member(_ id: UUID) -> ChipMember? {
        members.first { $0.id == id }
    }

    func name(of party: ChipParty) -> String {
        switch party {
        case .member(let id): member(id)?.name ?? "（抜けた人）"
        case .pot: "ポット"
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
        case .pot:
            if pot < move.amount { return "ポットが足りません（\(pot) pt）。" }
        case .bank:
            break
        }
        if case .member(let id) = move.to, member(id) == nil { return "参加者が見つかりません。" }
        return nil
    }

    mutating func apply(_ move: ChipMove) {
        add(-move.amount, to: move.from)
        add(move.amount, to: move.to)
        moves.append(move)
    }

    private mutating func add(_ amount: Int, to party: ChipParty) {
        switch party {
        case .member(let id):
            if let i = members.firstIndex(where: { $0.id == id }) { members[i].balance += amount }
        case .pot:
            pot += amount
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

    /// 全員の残高とポットを持ち点に戻して、履歴を消す
    mutating func restart() {
        let people = members
        members = []
        pot = 0
        moves = []
        bets = [:]
        rounds = []
        for m in people { join(id: m.id, name: m.name) }
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
    case pot
    case bank
}

struct ChipMove: Codable, Hashable, Identifiable {
    var id = UUID()
    var date = Date()
    var from: ChipParty
    var to: ChipParty
    var amount: Int
    /// 操作した人
    var by: UUID
}
