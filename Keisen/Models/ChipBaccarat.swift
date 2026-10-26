import Foundation

/// バカラの罫線とチップのテーブルをつなぐ：参加者ごとのベットと、勝敗が決まったときの精算。
/// 精算は「場」（ChipParty.bank）との ChipMove として履歴に残す。
extension ChipTable {
    /// ベットを入れられるかどうか。だめなときは理由を返す。ベットは入れ直すので、残高まで入れられる。
    func problem(withBet spots: [BetSpot: Int], for id: UUID) -> String? {
        guard let m = member(id) else { return "参加者が見つかりません。" }
        if spots.values.contains(where: { $0 < 0 }) { return "0 pt 以上を入れてください。" }
        let total = spots.values.reduce(0, +)
        if total > m.balance { return "\(m.name)さんのチップが足りません（\(m.balance) pt）。" }
        return nil
    }

    mutating func setBet(_ spots: [BetSpot: Int], for id: UUID) {
        let kept = spots.filter { $0.value > 0 }
        bets[id] = kept.isEmpty ? nil : kept
    }

    var lastRound: ChipRound? { rounds.last }

    /// 勝敗が決まったら、ベットを精算する。勝った分は場から受け取り、負けた分は場へ払う。
    /// handNumber は親の罫線でその手が何手目か（「1つ戻す」で取り消すときに確かめる）。
    mutating func settle(_ hand: Hand, handNumber: Int, shoeID: UUID, by: UUID) {
        var round = ChipRound(handNumber: handNumber, shoeID: shoeID, hand: hand, bets: bets)
        for m in members {
            guard let spots = bets[m.id], !spots.isEmpty else { continue }
            let staked = spots.values.reduce(0, +)
            var net = spots.reduce(0) { $0 + $1.key.net($1.value, on: hand, commission: bankerCommission) }
            // 残高より多くは負けない（ベットは残高までしか入れられないので、ふつうは起きない）
            net = max(net, -m.balance)
            if net != 0 {
                let move = net > 0
                    ? ChipMove(from: .bank, to: .member(m.id), amount: net, by: by)
                    : ChipMove(from: .member(m.id), to: .bank, amount: -net, by: by)
                apply(move)
                round.moveIDs.append(move.id)
            }
            round.results.append(ChipResult(member: m.id, name: m.name, staked: staked, net: net))
        }
        bets = [:]
        rounds.append(round)
        if rounds.count > 100 { rounds.removeFirst(rounds.count - 100) }
    }

    /// 直前の精算を取り消して、そのときのベットに戻す。シューと手番号が合わなければ何もしない。
    @discardableResult
    mutating func undoRound(handNumber: Int, shoeID: UUID) -> Bool {
        guard let round = rounds.last, round.handNumber == handNumber, round.shoeID == shoeID else { return false }
        rounds.removeLast()
        for id in round.moveIDs.reversed() {
            guard let i = moves.lastIndex(where: { $0.id == id }) else { continue }
            let move = moves.remove(at: i)
            // 逆向きに動かして戻す（精算は場とのあいだだけなので、参加者の残高だけを直す。履歴には残さない）
            if case .member(let to) = move.to, let j = members.firstIndex(where: { $0.id == to }) {
                members[j].balance -= move.amount
            }
            if case .member(let from) = move.from, let j = members.firstIndex(where: { $0.id == from }) {
                members[j].balance += move.amount
            }
        }
        bets = round.bets.filter { member($0.key) != nil }
        return true
    }
}

/// バカラで賭けられるところ
enum BetSpot: String, Codable, CaseIterable, Identifiable {
    case banker, player, tie, bankerPair, playerPair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .banker: "BANKER"
        case .player: "PLAYER"
        case .tie: "TIE"
        case .bankerPair: "B PAIR"
        case .playerPair: "P PAIR"
        }
    }

    var short: String {
        switch self {
        case .banker: "B"
        case .player: "P"
        case .tie: "T"
        case .bankerPair: "BP"
        case .playerPair: "PP"
        }
    }

    /// 払い戻しの説明
    func odds(commission: Bool) -> String {
        switch self {
        case .banker: commission ? "0.95倍" : "1倍"
        case .player: "1倍"
        case .tie: "8倍"
        case .bankerPair, .playerPair: "11倍"
        }
    }

    /// この手での増減（負けはマイナス）。タイのときはバンカー・プレイヤーへのベットはそのまま戻る（0）。
    /// 手数料ありのバンカーの勝ちは 0.95 倍で、1 pt 未満は切り捨てる。
    func net(_ amount: Int, on hand: Hand, commission: Bool) -> Int {
        switch self {
        case .banker:
            switch hand.outcome {
            case .banker: commission ? amount * 95 / 100 : amount
            case .tie: 0
            case .player: -amount
            }
        case .player:
            switch hand.outcome {
            case .player: amount
            case .tie: 0
            case .banker: -amount
            }
        case .tie: hand.outcome == .tie ? amount * 8 : -amount
        case .bankerPair: hand.bankerPair ? amount * 11 : -amount
        case .playerPair: hand.playerPair ? amount * 11 : -amount
        }
    }
}

/// 精算した1手
struct ChipRound: Codable, Hashable, Identifiable {
    var id = UUID()
    var date = Date()
    /// 親の罫線で何手目か（1から）
    var handNumber: Int
    var shoeID: UUID
    var hand: Hand
    /// 精算したときのベット（「1つ戻す」で元に戻す）
    var bets: [UUID: [BetSpot: Int]]
    var results: [ChipResult] = []
    /// 精算で作った ChipMove の id
    var moveIDs: [UUID] = []
}

struct ChipResult: Codable, Hashable {
    var member: UUID
    var name: String
    var staked: Int
    var net: Int
}
