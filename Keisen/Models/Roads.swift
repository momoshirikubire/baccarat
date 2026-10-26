import Foundation

/// 下三路の印。赤＝規則的（齐整）、青＝不規則。
enum Mark: Equatable {
    case red, blue
}

/// 下三路の種類。rawValue は大路の何列前と比べるか。
enum DerivedRoad: Int, CaseIterable, Identifiable {
    case bigEye = 1
    case small = 2
    case cockroach = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .bigEye: "大眼仔"
        case .small: "小路"
        case .cockroach: "曱甴路"
        }
    }
}

/// 大路の1マス。タイは直前のマスに数として付く。
struct BigRoadEntry {
    var outcome: Outcome
    var ties = 0
    var bankerPair = false
    var playerPair = false
}

struct PlacedCell<Item> {
    let x: Int
    let y: Int
    let item: Item
}

enum Roads {
    static let rows = 6

    /// 同じ種類が続くあいだを1列にまとめる（論理上の列）
    static func columns<Item, Key: Equatable>(_ items: [Item], key: (Item) -> Key) -> [[Item]] {
        var cols: [[Item]] = []
        for item in items {
            if let head = cols.last?.first, key(head) == key(item) {
                cols[cols.count - 1].append(item)
            } else {
                cols.append([item])
            }
        }
        return cols
    }

    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    /// 論理上の列を6段の罫線に置く。下が埋まっているか6段を超えたら右へ曲がる（ドラゴンテール）。
    static func place<Item>(_ cols: [[Item]]) -> [PlacedCell<Item>] {
        var occupied = Set<Cell>()
        var cells: [PlacedCell<Item>] = []
        var startX = -1
        for col in cols {
            startX += 1
            while occupied.contains(Cell(x: startX, y: 0)) { startX += 1 }
            var x = startX, y = 0, turned = false
            for (i, item) in col.enumerated() {
                if i > 0 {
                    if !turned && y + 1 < rows && !occupied.contains(Cell(x: x, y: y + 1)) {
                        y += 1
                    } else {
                        x += 1
                        turned = true
                    }
                }
                occupied.insert(Cell(x: x, y: y))
                cells.append(PlacedCell(x: x, y: y, item: item))
            }
        }
        return cells
    }

    struct BigRoad {
        let columns: [[BigRoadEntry]]
        /// まだバンカーもプレイヤーも出ていないうちのタイ
        let leadingTies: Int
    }

    static func bigRoad(_ hands: [Hand]) -> BigRoad {
        var entries: [BigRoadEntry] = []
        var leadingTies = 0
        for hand in hands {
            if hand.outcome == .tie {
                if entries.isEmpty { leadingTies += 1 } else { entries[entries.count - 1].ties += 1 }
            } else {
                entries.append(BigRoadEntry(outcome: hand.outcome, bankerPair: hand.bankerPair, playerPair: hand.playerPair))
            }
        }
        if !entries.isEmpty {
            entries[0].ties += leadingTies
            leadingTies = 0
        }
        return BigRoad(columns: columns(entries) { $0.outcome }, leadingTies: leadingTies)
    }

    /// 下三路の印を大路の論理上の列から出す。
    /// 列の頭は「1つ前の列」と「さらに k 列前」の長さがそろえば赤。
    /// 列の途中は k 列前に同じ段があれば赤、ちょうどその段で止まっていれば青、2段以上前に止まっていれば赤。
    static func derived(_ cols: [[BigRoadEntry]], road: DerivedRoad) -> [Mark] {
        let k = road.rawValue
        var marks: [Mark] = []
        for c in cols.indices {
            for r in cols[c].indices {
                if r == 0 {
                    guard c - 1 - k >= 0 else { continue }
                    marks.append(cols[c - 1].count == cols[c - 1 - k].count ? .red : .blue)
                } else {
                    guard c - k >= 0 else { continue }
                    marks.append(cols[c - k].count == r ? .blue : .red)
                }
            }
        }
        return marks
    }

    /// 問路：次が outcome だったら、その下三路に付く印
    static func nextMark(after hands: [Hand], outcome: Outcome, road: DerivedRoad) -> Mark? {
        let before = derived(bigRoad(hands).columns, road: road).count
        let after = derived(bigRoad(hands + [Hand(outcome: outcome)]).columns, road: road)
        return after.count > before ? after.last : nil
    }
}
