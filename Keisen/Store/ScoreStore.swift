import SwiftUI

/// ゲームを選ばない点数表。参加者ごとに、ラウンドの点を足していく。
struct ScoreSheet: Codable, Hashable {
    var title = "点数表"
    var players: [String] = ["Aさん", "Bさん", "Cさん"]
    var rounds: [[Int]] = []

    func total(_ index: Int) -> Int {
        rounds.reduce(0) { $0 + ($1.indices.contains(index) ? $1[index] : 0) }
    }
}

@Observable
final class ScoreStore {
    var sheet: ScoreSheet

    private static let file = "scores.json"

    init() {
        sheet = FileStore.load(ScoreSheet.self, from: Self.file) ?? ScoreSheet()
    }

    func addRound(_ points: [Int]) {
        sheet.rounds.append(points)
        save()
    }

    func deleteRounds(at offsets: IndexSet) {
        sheet.rounds.remove(atOffsets: offsets)
        save()
    }

    func setPlayers(_ names: [String]) {
        sheet.players = names
        // 人数が変わったら、各ラウンドの点の数を合わせる
        sheet.rounds = sheet.rounds.map { r in
            (0..<names.count).map { r.indices.contains($0) ? r[$0] : 0 }
        }
        save()
    }

    func clearRounds() {
        sheet.rounds = []
        save()
    }

    func save() {
        FileStore.save(sheet, to: Self.file)
    }
}
