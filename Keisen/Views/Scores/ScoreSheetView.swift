import SwiftUI

/// おいちょかぶなど、どんなゲームにも使える点数表
struct ScoreSheetView: View {
    let store: ScoreStore
    @State private var addingRound = false
    @State private var editingPlayers = false
    @State private var confirmClear = false

    private var sheet: ScoreSheet { store.sheet }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    totalsRow
                } header: {
                    Text("合計")
                } footer: {
                    if !sheet.rounds.isEmpty {
                        let sum = sheet.players.indices.reduce(0) { $0 + sheet.total($1) }
                        Text(sum == 0 ? "全員の合計は 0 です。" : "全員の合計は \(sum) です。")
                    }
                }

                Section("ラウンド") {
                    if sheet.rounds.isEmpty {
                        Text("「ラウンドを追加」で、1回ごとの点を入れていきます。マイナスも入れられます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(sheet.rounds.enumerated()), id: \.offset) { i, round in
                        HStack(spacing: 0) {
                            Text("\(i + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            ForEach(sheet.players.indices, id: \.self) { p in
                                let v = round.indices.contains(p) ? round[p] : 0
                                Text(v > 0 ? "+\(v)" : "\(v)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(v > 0 ? Theme.tie : v < 0 ? Theme.banker : Theme.muted)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .onDelete { store.deleteRounds(at: $0) }
                }
            }
            .navigationTitle("点数表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { editingPlayers = true } label: { Label("参加者を編集", systemImage: "person.2") }
                        Button(role: .destructive) { confirmClear = true } label: { Label("点を全部消す", systemImage: "trash") }
                    } label: {
                        Label("メニュー", systemImage: "ellipsis.circle")
                    }
                }
            }
            .tipButton()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { addingRound = true } label: {
                    Label("ラウンドを追加", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.background)
            }
            .sheet(isPresented: $addingRound) {
                RoundEntry(players: sheet.players) { store.addRound($0) }
            }
            .sheet(isPresented: $editingPlayers) {
                PlayersEditor(names: sheet.players) { store.setPlayers($0) }
            }
            .confirmationDialog("点を全部消しますか？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("全部消す", role: .destructive) { store.clearRounds() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("参加者の名前は残ります。")
            }
        }
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 28)
            ForEach(sheet.players.indices, id: \.self) { p in
                let t = sheet.total(p)
                VStack(spacing: 2) {
                    Text(sheet.players[p]).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                    Text(t > 0 ? "+\(t)" : "\(t)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(t > 0 ? Theme.tie : t < 0 ? Theme.banker : Theme.ink)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct RoundEntry: View {
    let players: [String]
    let onSave: ([Int]) -> Void
    @State private var points: [Int?] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ForEach(players.indices, id: \.self) { i in
                    HStack {
                        Text(players[i])
                        Spacer()
                        TextField("0", value: binding(i), format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }
                let sum = points.compactMap { $0 }.reduce(0, +)
                Text("このラウンドの合計 \(sum)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("ラウンドを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onSave(points.map { $0 ?? 0 })
                        dismiss()
                    }
                }
            }
            .onAppear { if points.count != players.count { points = Array(repeating: nil, count: players.count) } }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding(_ i: Int) -> Binding<Int?> {
        Binding(
            get: { points.indices.contains(i) ? points[i] : nil },
            set: { if points.indices.contains(i) { points[i] = $0 } }
        )
    }
}

private struct PlayersEditor: View {
    private struct Entry: Identifiable {
        let id = UUID()
        var name: String
    }

    @State private var entries: [Entry]
    let onSave: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    init(names: [String], onSave: @escaping ([String]) -> Void) {
        _entries = State(initialValue: names.map { Entry(name: $0) })
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($entries) { $entry in
                    TextField("名前", text: $entry.name)
                }
                .onDelete { entries.remove(atOffsets: $0) }
                Button("参加者を追加") { entries.append(Entry(name: "参加者\(entries.count + 1)")) }
                    .disabled(entries.count >= 8)
            }
            .navigationTitle("参加者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(entries.map { $0.name.trimmingCharacters(in: .whitespaces) }.map { $0.isEmpty ? "?" : $0 })
                        dismiss()
                    }
                    .disabled(entries.isEmpty)
                }
            }
        }
    }
}
