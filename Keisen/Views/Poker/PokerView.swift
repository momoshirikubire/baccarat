import SwiftUI

/// ポーカーのホームゲーム：チップの出入りと精算、ブラインドタイマー
struct PokerView: View {
    let store: PokerStore
    @AppStorage("pokerTab") private var tab = "ledger"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $tab) {
                    Text("チップと精算").tag("ledger")
                    Text("ブラインドタイマー").tag("timer")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                if tab == "ledger" {
                    PokerLedgerView(store: store)
                } else {
                    BlindTimerView(store: store)
                }
            }
            .background(Theme.background)
            .navigationTitle("ポーカー")
            .navigationBarTitleDisplayMode(.inline)
            .tipButton()
        }
    }
}

struct PokerLedgerView: View {
    @Bindable var store: PokerStore
    @State private var newName = ""
    @State private var confirmReset = false
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                ForEach($store.players) { $player in
                    PlayerRow(player: $player, defaultBuyIn: store.defaultBuyIn)
                }
                .onDelete { store.players.remove(atOffsets: $0) }
                HStack {
                    TextField("参加者の名前", text: $newName)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("追加", action: add).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("参加者")
            } footer: {
                Text("「＋」でバイイン（チップの買い足し）を1回ぶん足します。終わったら、手元に残ったチップを「最後」に入れてください。単位はポイントです。")
            }

            Section("設定") {
                HStack {
                    Text("1回のバイイン")
                    Spacer()
                    TextField("1000", value: $store.defaultBuyIn, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
            }

            if !store.players.isEmpty {
                Section("精算") {
                    LabeledContent("バイインの合計", value: "\(store.totalIn.formatted()) pt")
                    LabeledContent("最後のチップの合計", value: "\(store.totalOut.formatted()) pt")
                    if !store.everyoneCashedOut {
                        Text("全員の「最後」を入れると、だれがだれに何ポイント渡すかが出ます。")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if store.totalIn != store.totalOut {
                        Label("合計が \((store.totalOut - store.totalIn).formatted()) pt ずれています。数え直してください。", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(Theme.banker)
                    } else {
                        let transfers = Settlement.transfers(store.players)
                        if transfers.isEmpty {
                            Text("受け渡しはありません。").foregroundStyle(.secondary)
                        }
                        ForEach(transfers, id: \.self) { t in
                            HStack {
                                Text(t.from).bold()
                                Image(systemName: "arrow.right").foregroundStyle(Theme.muted)
                                Text(t.to).bold()
                                Spacer()
                                Text("\(t.amount) pt").monospacedDigit()
                            }
                        }
                    }
                }
                Section {
                    Button("同じメンバーで次のゲームを始める", role: .destructive) { confirmReset = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: store.players) { store.save() }
        .onChange(of: store.defaultBuyIn) { store.save() }
        .confirmationDialog("チップの記録を消して、次のゲームを始めますか？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("次のゲームを始める", role: .destructive) { store.resetGame() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func add() {
        store.addPlayer(newName)
        newName = ""
    }
}

private struct PlayerRow: View {
    @Binding var player: PokerPlayer
    let defaultBuyIn: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(player.name).font(.headline)
                Spacer()
                if let net = player.net {
                    Text(net > 0 ? "+\(net)" : "\(net)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(net > 0 ? Theme.tie : net < 0 ? Theme.banker : Theme.muted)
                }
            }
            HStack(spacing: 12) {
                Text("バイイン \(player.totalIn) pt（\(player.buyIns.count)回）")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if !player.buyIns.isEmpty { player.buyIns.removeLast() }
                } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .disabled(player.buyIns.isEmpty)
                    .accessibilityLabel("バイインを1回減らす")
                Button {
                    player.buyIns.append(defaultBuyIn)
                } label: { Image(systemName: "plus.circle.fill") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("バイインを1回足す")
            }
            HStack {
                Text("最後").font(.caption)
                TextField("手元のチップ", value: $player.cashOut, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.vertical, 2)
    }
}
