import Foundation

enum Outcome: String, Codable, CaseIterable {
    case banker = "B"
    case player = "P"
    case tie = "T"
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
    static func sample(pairs: Bool) -> Shoe {
        let seq = Array("BBPTPPPBBBBPBPPTPBBBPPPPPPPBPBBTBPPBBPB")
        let hands = seq.enumerated().map { i, ch in
            Hand(outcome: Outcome(rawValue: String(ch)) ?? .banker, bankerPair: pairs && i == 5, playerPair: pairs && i == 17)
        }
        return Shoe(hands: hands)
    }
}

/// 罫線を使うゲーム。ドラゴンタイガーはバカラと同じ罫線で、バンカーの位置にドラゴン、プレイヤーの位置にタイガーが入る。
enum RoadGame: String, CaseIterable, Identifiable {
    case baccarat
    case dragonTiger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .baccarat: "バカラ"
        case .dragonTiger: "ドラゴンタイガー"
        }
    }

    var hasPairs: Bool { self == .baccarat }

    /// 保存先。バカラは 1.0 からのファイル名のまま。
    var fileName: String {
        switch self {
        case .baccarat: "shoes.json"
        case .dragonTiger: "dragon-tiger.json"
        }
    }

    func name(_ outcome: Outcome) -> String {
        switch (self, outcome) {
        case (_, .tie): "TIE"
        case (.baccarat, .banker): "BANKER"
        case (.baccarat, .player): "PLAYER"
        case (.dragonTiger, .banker): "DRAGON"
        case (.dragonTiger, .player): "TIGER"
        }
    }

    /// 罫線や集計に出す1文字
    func letter(_ outcome: Outcome) -> String {
        switch (self, outcome) {
        case (.baccarat, .tie): "T"
        case (.dragonTiger, .tie): "和"
        case (.baccarat, .banker): "B"
        case (.baccarat, .player): "P"
        case (.dragonTiger, .banker): "D"
        case (.dragonTiger, .player): "T"
        }
    }

    /// 珠盤路に書く一文字
    func bead(_ outcome: Outcome) -> String {
        switch (self, outcome) {
        case (_, .tie): "和"
        case (.baccarat, .banker): "庄"
        case (.baccarat, .player): "闲"
        case (.dragonTiger, .banker): "龍"
        case (.dragonTiger, .player): "虎"
        }
    }
}
