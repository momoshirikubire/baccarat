import Foundation

/// ホームゲームの参加者。チップはポイントで数える（お金の精算には使わない）。
struct PokerPlayer: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var buyIns: [Int] = []
    var cashOut: Int?

    var totalIn: Int { buyIns.reduce(0, +) }
    var net: Int? { cashOut.map { $0 - totalIn } }
}

struct Transfer: Hashable {
    let from: String
    let to: String
    let amount: Int
}

enum Settlement {
    /// 負けた人から勝った人へ、受け渡しの回数が少なくなるように組む
    static func transfers(_ players: [PokerPlayer]) -> [Transfer] {
        var debtors: [(String, Int)] = []
        var creditors: [(String, Int)] = []
        for p in players {
            guard let net = p.net else { continue }
            if net < 0 { debtors.append((p.name, -net)) }
            if net > 0 { creditors.append((p.name, net)) }
        }
        debtors.sort { $0.1 > $1.1 }
        creditors.sort { $0.1 > $1.1 }
        var result: [Transfer] = []
        var i = 0, j = 0
        while i < debtors.count, j < creditors.count {
            let amount = min(debtors[i].1, creditors[j].1)
            if amount > 0 { result.append(Transfer(from: debtors[i].0, to: creditors[j].0, amount: amount)) }
            debtors[i].1 -= amount
            creditors[j].1 -= amount
            if debtors[i].1 == 0 { i += 1 }
            if creditors[j].1 == 0 { j += 1 }
        }
        return result
    }
}

struct BlindLevel: Codable, Hashable, Identifiable {
    var id = UUID()
    var small: Int
    var big: Int
    var ante = 0

    var label: String {
        ante > 0 ? "\(small) / \(big)（アンティ \(ante)）" : "\(small) / \(big)"
    }

    static let defaults: [BlindLevel] = [
        (25, 50, 0), (50, 100, 0), (75, 150, 0), (100, 200, 0), (150, 300, 0),
        (200, 400, 50), (300, 600, 75), (400, 800, 100), (500, 1000, 100),
        (700, 1400, 200), (1000, 2000, 300), (1500, 3000, 400),
    ].map { BlindLevel(small: $0.0, big: $0.1, ante: $0.2) }
}

/// ブラインドタイマー。動いているあいだは終わる時刻、止めているあいだは残り秒数を持つ。
struct BlindClock: Codable, Hashable {
    var levels = BlindLevel.defaults
    var minutesPerLevel = 15
    var level = 0
    var endsAt: Date?
    var pausedRemaining: TimeInterval?

    var isRunning: Bool { endsAt != nil }
    var levelLength: TimeInterval { TimeInterval(minutesPerLevel * 60) }

    func remaining(at now: Date) -> TimeInterval {
        if let endsAt { return max(0, endsAt.timeIntervalSince(now)) }
        return pausedRemaining ?? levelLength
    }

    mutating func start(at now: Date) {
        guard endsAt == nil else { return }
        endsAt = now.addingTimeInterval(pausedRemaining ?? levelLength)
        pausedRemaining = nil
    }

    mutating func pause(at now: Date) {
        guard endsAt != nil else { return }
        pausedRemaining = remaining(at: now)
        endsAt = nil
    }

    mutating func go(to index: Int, at now: Date) {
        level = min(max(0, index), max(0, levels.count - 1))
        if isRunning { endsAt = now.addingTimeInterval(levelLength) } else { pausedRemaining = nil }
    }

    /// 時間切れなら次のレベルへ進める。進んだら true。
    mutating func advanceIfNeeded(at now: Date) -> Bool {
        guard let endsAt, now >= endsAt else { return false }
        if level + 1 < levels.count {
            level += 1
            self.endsAt = endsAt.addingTimeInterval(levelLength)
            return true
        }
        self.endsAt = nil
        pausedRemaining = 0
        return false
    }
}
