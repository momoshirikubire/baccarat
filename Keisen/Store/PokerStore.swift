import SwiftUI

@Observable
final class PokerStore {
    // 画面で直接書き換えるので、変わったら画面側から save() を呼ぶ
    var players: [PokerPlayer]
    var defaultBuyIn: Int
    var clock: BlindClock

    private struct Saved: Codable {
        var players: [PokerPlayer]
        var defaultBuyIn: Int
        var clock: BlindClock
    }

    private static let file = "poker.json"

    init() {
        let saved = FileStore.load(Saved.self, from: Self.file)
        players = saved?.players ?? []
        defaultBuyIn = saved?.defaultBuyIn ?? 1000
        clock = saved?.clock ?? BlindClock()
    }

    func addPlayer(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        players.append(PokerPlayer(name: trimmed, buyIns: [defaultBuyIn]))
        save()
    }

    func resetGame() {
        players = players.map { PokerPlayer(name: $0.name, buyIns: [defaultBuyIn]) }
        save()
    }

    var totalIn: Int { players.reduce(0) { $0 + $1.totalIn } }
    var totalOut: Int { players.reduce(0) { $0 + ($1.cashOut ?? 0) } }
    var everyoneCashedOut: Bool { !players.isEmpty && players.allSatisfy { $0.cashOut != nil } }

    func save() {
        FileStore.save(Saved(players: players, defaultBuyIn: defaultBuyIn, clock: clock), to: Self.file)
    }
}
