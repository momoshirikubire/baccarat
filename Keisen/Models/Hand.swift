import Foundation

enum Outcome: String, Codable, CaseIterable {
    case banker = "B"
    case player = "P"
    case tie = "T"

    var name: String {
        switch self {
        case .banker: "バンカー"
        case .player: "プレイヤー"
        case .tie: "タイ"
        }
    }

    /// 珠盤路に書く一文字
    var bead: String {
        switch self {
        case .banker: "庄"
        case .player: "闲"
        case .tie: "和"
        }
    }
}

struct Hand: Codable, Hashable {
    var outcome: Outcome
    var bankerPair = false
    var playerPair = false
}

struct Shoe: Codable, Identifiable, Hashable {
    var id = UUID()
    var startedAt = Date()
    var hands: [Hand] = []

    var count: (banker: Int, player: Int, tie: Int, bankerPair: Int, playerPair: Int) {
        var c = (banker: 0, player: 0, tie: 0, bankerPair: 0, playerPair: 0)
        for h in hands {
            switch h.outcome {
            case .banker: c.banker += 1
            case .player: c.player += 1
            case .tie: c.tie += 1
            }
            if h.bankerPair { c.bankerPair += 1 }
            if h.playerPair { c.playerPair += 1 }
        }
        return c
    }

    /// 初回起動時に見せる例のシュー
    static var sample: Shoe {
        let seq = Array("BBPTPPPBBBBPBPPTPBBBPPPPPPPBPBBTBPPBBPB")
        let hands = seq.enumerated().map { i, ch in
            Hand(outcome: Outcome(rawValue: String(ch)) ?? .banker, bankerPair: i == 5, playerPair: i == 17)
        }
        return Shoe(hands: hands)
    }
}
