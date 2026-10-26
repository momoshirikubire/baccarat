import Foundation

/// チップのテーブル。実物のチップの代わりに、参加者の残高とポットをポイントで数える。
/// お金には換えない（円は使わない）。
struct ChipTable: Codable, Hashable {
    var name: String
    var startingChips: Int
    var members: [ChipMember] = []
    var pot = 0
    var moves: [ChipMove] = []

    func member(_ id: UUID) -> ChipMember? {
        members.first { $0.id == id }
    }

    func name(of party: ChipParty) -> String {
        switch party {
        case .member(let id): member(id)?.name ?? "（抜けた人）"
        case .pot: "ポット"
        case .bank: "親"
        }
    }

    /// 動かせるかどうか。だめなときは理由を返す。親（bank）からはいくらでも出せる。
    func problem(with move: ChipMove) -> String? {
        guard move.amount > 0 else { return "1 pt 以上を入れてください。" }
        guard move.from != move.to else { return "同じところには動かせません。" }
        switch move.from {
        case .member(let id):
            guard let m = member(id) else { return "参加者が見つかりません。" }
            if m.balance < move.amount { return "\(m.name)さんのチップが足りません（\(m.balance) pt）。" }
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

    /// 全員の残高とポットを持ち点に戻して、履歴を消す
    mutating func restart() {
        let people = members
        members = []
        pot = 0
        moves = []
        for m in people { join(id: m.id, name: m.name) }
    }
}

struct ChipMember: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var balance: Int
}

/// チップの行き先。bank は親が配ったり回収したりするときの「場の外」。
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
