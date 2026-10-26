import Foundation

enum BJResult: String, Codable, CaseIterable {
    case win, lose, push, blackjack, surrender

    var title: String {
        switch self {
        case .win: "勝ち"
        case .lose: "負け"
        case .push: "引き分け"
        case .blackjack: "BJ"
        case .surrender: "降参"
        }
    }

    /// 1ベットを 1 としたときの増減
    var units: Double {
        switch self {
        case .win: 1
        case .lose: -1
        case .push: 0
        case .blackjack: 1.5
        case .surrender: -0.5
        }
    }

    var canDouble: Bool { self == .win || self == .lose || self == .push }
}

struct BJHand: Codable, Hashable {
    var result: BJResult
    var doubled = false

    var units: Double { result.units * (doubled && result.canDouble ? 2 : 1) }
}

struct BJSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var startedAt = Date()
    var hands: [BJHand] = []

    var net: Double { hands.reduce(0) { $0 + $1.units } }

    /// 引き分けを除いた勝率
    var winRate: Double? {
        let decided = hands.filter { $0.result != .push }
        guard !decided.isEmpty else { return nil }
        let wins = decided.filter { $0.units > 0 }.count
        return Double(wins) / Double(decided.count)
    }

    /// 1手ごとの累計（グラフ用）
    var runningNet: [Double] {
        var total = 0.0
        return [0] + hands.map { total += $0.units; return total }
    }
}

/// Hi-Lo の数え方：2〜6 は +1、7〜9 は 0、10・絵札・A は −1
enum HiLo {
    static let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    static let suits = ["♠", "♥", "♦", "♣"]

    static func value(_ rank: String) -> Int {
        switch rank {
        case "2", "3", "4", "5", "6": 1
        case "7", "8", "9": 0
        default: -1
        }
    }

    struct Card: Hashable {
        let rank: String
        let suit: String
        var isRed: Bool { suit == "♥" || suit == "♦" }
    }

    static func shoe(decks: Int) -> [Card] {
        var cards: [Card] = []
        for _ in 0..<decks {
            for s in suits { for r in ranks { cards.append(Card(rank: r, suit: s)) } }
        }
        return cards.shuffled()
    }
}

extension Double {
    /// 1.5 → "+1.5"、-2 → "-2"
    var signedUnits: String {
        let text = truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
        return self > 0 ? "+" + text : text
    }
}
