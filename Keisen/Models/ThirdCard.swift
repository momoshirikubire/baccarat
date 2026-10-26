import Foundation

/// トランプの数字。バカラでは 10・J・Q・K は 0、A は 1 と数える。
enum CardRank: Int, CaseIterable, Identifiable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    var id: Int { rawValue }

    var value: Int { rawValue >= 10 ? 0 : rawValue }

    var label: String {
        switch self {
        case .ace: "A"
        case .ten: "10"
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        default: "\(rawValue)"
        }
    }
}

/// バカラ（プント・バンコ）の3枚目のルール
enum ThirdCard {
    /// 合計の下1けた
    static func total(_ cards: [CardRank]) -> Int {
        cards.reduce(0) { $0 + $1.value } % 10
    }

    /// どちらかが最初の2枚で 8 か 9 なら、どちらも引かずに勝負が決まる
    static func isNatural(player: Int, banker: Int) -> Bool {
        player >= 8 || banker >= 8
    }

    /// PLAYER は 0〜5 で引き、6・7 でスタンド（ナチュラルのときは引かない）
    static func playerDraws(player: Int, banker: Int) -> Bool {
        !isNatural(player: player, banker: banker) && player <= 5
    }

    /// BANKER が引くか。playerThird は PLAYER の3枚目（PLAYER がスタンドしたときは nil）。
    static func bankerDraws(banker: Int, player: Int, playerThird: CardRank?) -> Bool {
        if isNatural(player: player, banker: banker) { return false }
        guard let third = playerThird?.value else {
            // PLAYER がスタンドしたときは、BANKER も 0〜5 で引き、6・7 でスタンド
            return banker <= 5
        }
        switch banker {
        case 0...2: return true
        case 3: return third != 8
        case 4: return (2...7).contains(third)
        case 5: return (4...7).contains(third)
        case 6: return (6...7).contains(third)
        default: return false
        }
    }

    /// BANKER が引く・引かないの理由（画面に出す説明）
    static func bankerReason(banker: Int, playerThird: CardRank?) -> String {
        guard let third = playerThird else {
            return banker <= 5 ? "PLAYER がスタンドしたので、BANKER は 0〜5 なら引きます" : "PLAYER がスタンドしたので、BANKER は 6・7 ならスタンドです"
        }
        let p = "PLAYER の3枚目が \(third.label)（\(third.value)）"
        switch banker {
        case 0...2: return "BANKER が 0〜2 のときは、いつも引きます"
        case 3: return "\(p)。BANKER 3 は、PLAYER の3枚目が 8 のときだけスタンド"
        case 4: return "\(p)。BANKER 4 は、PLAYER の3枚目が 2〜7 なら引きます"
        case 5: return "\(p)。BANKER 5 は、PLAYER の3枚目が 4〜7 なら引きます"
        case 6: return "\(p)。BANKER 6 は、PLAYER の3枚目が 6・7 なら引きます"
        default: return "BANKER が 7 のときは、いつもスタンドです"
        }
    }
}
