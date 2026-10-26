import SwiftUI

@Observable
final class BlackjackStore {
    private(set) var current: BJSession
    private(set) var archive: [BJSession]

    private struct Saved: Codable {
        var current: BJSession
        var archive: [BJSession]
    }

    private static let file = "blackjack.json"

    init() {
        let saved = FileStore.load(Saved.self, from: Self.file)
        current = saved?.current ?? BJSession()
        archive = saved?.archive ?? []
    }

    func record(_ result: BJResult, doubled: Bool) {
        current.hands.append(BJHand(result: result, doubled: doubled))
        save()
    }

    var canUndo: Bool { !current.hands.isEmpty }

    func undo() {
        guard canUndo else { return }
        current.hands.removeLast()
        save()
    }

    func startNewSession() {
        if !current.hands.isEmpty { archive.insert(current, at: 0) }
        current = BJSession()
        save()
    }

    func deleteArchived(at offsets: IndexSet) {
        archive.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        FileStore.save(Saved(current: current, archive: archive), to: Self.file)
    }
}
