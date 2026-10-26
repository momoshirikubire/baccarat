import SwiftUI

struct HistoryView: View {
    @Environment(ShoeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.archive.isEmpty {
                    ContentUnavailableView(
                        "過去のシューはまだありません",
                        systemImage: "clock",
                        description: Text("右上の「新しいシュー」を押すと、いまのシューがここに残ります。")
                    )
                } else {
                    List {
                        ForEach(store.archive) { shoe in
                            NavigationLink(value: shoe) { ShoeRow(shoe: shoe) }
                        }
                        .onDelete { store.deleteArchived(at: $0) }
                    }
                }
            }
            .navigationTitle("過去のシュー")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Shoe.self) { shoe in
                ScrollView {
                    VStack(spacing: 10) {
                        StatsBar(shoe: shoe)
                        RoadsBoard(hands: shoe.hands)
                    }
                    .padding(12)
                }
                .background(Theme.background)
                .navigationTitle(shoe.startedAt.formatted(date: .abbreviated, time: .shortened))
                .navigationBarTitleDisplayMode(.inline)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct ShoeRow: View {
    let shoe: Shoe

    var body: some View {
        let c = shoe.count
        VStack(alignment: .leading, spacing: 4) {
            Text(shoe.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.bold())
            HStack(spacing: 10) {
                Text("\(shoe.hands.count)手").foregroundStyle(.secondary)
                Text("B \(c.banker)").foregroundStyle(Theme.banker)
                Text("P \(c.player)").foregroundStyle(Theme.player)
                Text("T \(c.tie)").foregroundStyle(Theme.tie)
            }
            .font(.caption.monospacedDigit())
        }
    }
}
