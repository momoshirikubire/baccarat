import SwiftUI

/// いまのシューと、終わったシューの控え。端末の中の JSON に保存する。
@Observable
final class ShoeStore {
    private(set) var current: Shoe
    private(set) var archive: [Shoe]
    /// 初回の例を表示しているあいだは true。1手目を記録すると消える。
    private(set) var isSample: Bool

    private struct Saved: Codable {
        var current: Shoe
        var archive: [Shoe]
        var isSample: Bool
    }

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shoes.json")
    }()

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            current = saved.current
            archive = saved.archive
            isSample = saved.isSample
        } else {
            current = .sample
            archive = []
            isSample = true
        }
    }

    func record(_ outcome: Outcome, bankerPair: Bool, playerPair: Bool) {
        if isSample {
            current = Shoe()
            isSample = false
        }
        current.hands.append(Hand(outcome: outcome, bankerPair: bankerPair, playerPair: playerPair))
        save()
    }

    var canUndo: Bool { !isSample && !current.hands.isEmpty }

    func undo() {
        guard canUndo else { return }
        current.hands.removeLast()
        save()
    }

    /// いまのシューを控えに回して、空のシューを始める
    func startNewShoe() {
        if !isSample && !current.hands.isEmpty {
            archive.insert(current, at: 0)
        }
        current = Shoe()
        isSample = false
        save()
    }

    func deleteArchived(at offsets: IndexSet) {
        archive.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        let saved = Saved(current: current, archive: archive, isSample: isSample)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
