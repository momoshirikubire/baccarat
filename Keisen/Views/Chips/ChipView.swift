import SwiftUI

/// 実物のチップの代わりに使うチップのテーブル。1台でも、近くの全員の iPhone をつないでも使える。
struct ChipView: View {
    @Bindable var store: ChipStore

    var body: some View {
        NavigationStack {
            Group {
                if store.role == .none || (store.role == .guest && store.table == nil) {
                    ChipStartView(store: store)
                } else {
                    ChipTableView(store: store)
                }
            }
            .background(Theme.background)
            .navigationTitle(store.table?.name ?? "チップ")
            .navigationBarTitleDisplayMode(.inline)
            .tipButton()
            .alert(store.notice ?? "", isPresented: Binding(
                get: { store.notice != nil },
                set: { if !$0 { store.notice = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

// MARK: - はじめの画面

private struct ChipStartView: View {
    @Bindable var store: ChipStore
    @State private var tableName = "テーブル"
    @State private var startingChips = 1000
    @State private var hostPlays = true
    @State private var joining: ChipStore.FoundTable?
    @State private var code = ""

    var body: some View {
        List {
            Section {
                TextField("あなたの名前", text: $store.myName)
                    .textContentType(.nickname)
            } header: {
                Text("あなた")
            } footer: {
                Text("みんなの画面に出る名前です。")
            }

            Section {
                TextField("テーブルの名前", text: $tableName)
                HStack {
                    Text("はじめの持ち点")
                    Spacer()
                    TextField("1000", value: $startingChips, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                    Text("pt").foregroundStyle(.secondary)
                }
                Toggle("自分も参加する", isOn: $hostPlays)
                Button("テーブルを作る") {
                    let name = tableName.trimmingCharacters(in: .whitespaces)
                    store.createTable(name: name.isEmpty ? "テーブル" : name, startingChips: startingChips, hostPlays: hostPlays)
                }
            } header: {
                Text("親になる")
            } footer: {
                Text("親の iPhone がテーブルを持ちます。1台だけで全員のぶんを記録することも、近くのみんなの iPhone をつなぐこともできます。")
            }

            Section {
                if store.role == .guest {
                    HStack {
                        ProgressView()
                        Text("参加しています…").padding(.leading, 6)
                    }
                } else if store.found.isEmpty {
                    HStack {
                        ProgressView()
                        Text("近くのテーブルを探しています…")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 6)
                    }
                }
                ForEach(store.found) { table in
                    Button {
                        code = ""
                        joining = table
                    } label: {
                        LabeledContent(table.name, value: table.peer.displayName)
                    }
                    .disabled(store.role == .guest)
                }
            } header: {
                Text("近くのテーブルに参加する")
            } footer: {
                Text("親の画面に出ている4桁の参加番号を入れて参加します。Wi-Fi と Bluetooth をオンにしてください。インターネットはなくても使えます。")
            }

            Section {
                Text("チップはポイント（pt）で数える遊び用の記録です。お金に換えたり、精算に使ったりはしないでください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { store.startBrowsing() }
        .onDisappear { if store.role == .none { store.stopBrowsing() } }
        .alert("参加番号", isPresented: Binding(get: { joining != nil }, set: { if !$0 { joining = nil } })) {
            TextField("4桁の番号", text: $code)
                .keyboardType(.numberPad)
            Button("参加する") {
                if let joining { store.join(joining, code: code) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(joining?.name ?? "")」の親の画面に出ている番号を入れてください。")
        }
    }
}

// MARK: - テーブル

private struct ChipTableView: View {
    let store: ChipStore
    @State private var moving: MoveDraft?
    @State private var addingMember = false
    @State private var newMember = ""
    @State private var confirmRestart = false
    @State private var confirmClose = false

    private var isHost: Bool { store.role == .host }

    var body: some View {
        let table = store.table
        List {
            if let table {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        if let me = table.member(store.myID) {
                            balance("あなた", me.balance)
                        }
                        balance("ポット", table.pot)
                    }
                    .listRowBackground(Theme.sheet)
                }

                if isHost { hostSection }

                Section {
                    ForEach(table.members) { m in
                        Button {
                            moving = draft(toward: m.id)
                        } label: {
                            HStack {
                                Text(m.name).foregroundStyle(Theme.ink)
                                if m.id == store.myID {
                                    Text("あなた").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(m.balance.formatted()) pt")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .deleteDisabled(!isHost)
                    }
                    .onDelete { offsets in
                        for i in offsets { store.removeMember(table.members[i].id) }
                    }
                    if isHost {
                        Button { newMember = ""; addingMember = true } label: {
                            Label("参加者を足す", systemImage: "person.badge.plus")
                        }
                    }
                } header: {
                    Text("参加者")
                } footer: {
                    Text(isHost
                         ? "名前をタップすると、その人のチップを動かせます。アプリを入れていない人も「参加者を足す」で入れられます。"
                         : "名前をタップすると、その人にチップを渡せます。")
                }

                Section("履歴") {
                    if table.moves.isEmpty {
                        Text("まだ動きはありません。").foregroundStyle(.secondary)
                    }
                    ForEach(table.moves.reversed()) { move in
                        MoveRow(move: move, table: table)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    if isHost {
                        Button { confirmRestart = true } label: { Label("持ち点に戻す", systemImage: "arrow.counterclockwise") }
                        Button(role: .destructive) { confirmClose = true } label: { Label("テーブルを閉じる", systemImage: "xmark.circle") }
                    } else {
                        Button(role: .destructive) { store.leave() } label: { Label("テーブルから抜ける", systemImage: "rectangle.portrait.and.arrow.right") }
                    }
                } label: {
                    Label("メニュー", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $moving) { draft in
            if let table = store.table {
                MoveSheet(draft: draft, table: table, sources: sources(table), destinations: destinations(table)) {
                    store.move(from: $0, to: $1, amount: $2)
                }
            }
        }
        .alert("参加者を足す", isPresented: $addingMember) {
            TextField("名前", text: $newMember)
            Button("足す") { store.addLocalMember(newMember) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("はじめの持ち点を配ります。")
        }
        .confirmationDialog("全員を持ち点に戻して、履歴を消しますか？", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("持ち点に戻す", role: .destructive) { store.restart() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("テーブルを閉じますか？", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("テーブルを閉じる", role: .destructive) { store.closeTable() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("つながっている人も抜けて、残高と履歴は消えます。")
        }
    }

    private var hostSection: some View {
        Section {
            Toggle("近くの人が参加できる", isOn: Binding(get: { store.isOpen }, set: { store.setOpen($0) }))
            if store.isOpen {
                LabeledContent("参加番号") {
                    Text(store.code)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                LabeledContent("つながっている人", value: "\(store.connectedCount) 人")
            }
        } header: {
            Text("親")
        } footer: {
            if store.isOpen {
                Text("参加する人は「チップ」タブの「近くのテーブルに参加する」から、この番号を入れます。親のアプリを開いたままにしてください。")
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            action("渡す", "arrow.left.arrow.right") { moving = draft(from: me, to: nil) }
            action("ポットに出す", "arrow.down.circle") { moving = draft(from: me, to: .pot) }
            action("ポットを取る", "arrow.up.circle") {
                moving = draft(from: .pot, to: me, amount: store.table?.pot)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background)
        .disabled(store.table == nil || (!isHost && !store.isMember))
    }

    /// 自分の場所。親で参加していなければ、最初の参加者にしておく。
    private var me: ChipParty? {
        if store.isMember { return .member(store.myID) }
        return store.table?.members.first.map { .member($0.id) }
    }

    private func draft(toward id: UUID) -> MoveDraft {
        // 親は、その人のチップを動かす（ポットへ出すのがいちばん多い）。子は、その人に渡す。
        if isHost || id == store.myID { return draft(from: .member(id), to: .pot) }
        return draft(from: me, to: .member(id))
    }

    private func draft(from: ChipParty?, to: ChipParty?, amount: Int? = nil) -> MoveDraft {
        MoveDraft(from: from, to: to, amount: amount)
    }

    /// 動かせる元。子は自分とポットだけ。
    private func sources(_ table: ChipTable) -> [ChipParty] {
        if isHost { return table.members.map { .member($0.id) } + [.pot, .bank] }
        return [.member(store.myID), .pot]
    }

    private func destinations(_ table: ChipTable) -> [ChipParty] {
        table.members.map { .member($0.id) } + [.pot] + (isHost ? [.bank] : [])
    }

    private func balance(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value.formatted())")
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("pt").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func action(_ title: String, _ icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressStyle())
    }
}

private struct MoveRow: View {
    let move: ChipMove
    let table: ChipTable

    var body: some View {
        HStack {
            Text(table.name(of: move.from)).bold()
            Image(systemName: "arrow.right").foregroundStyle(Theme.muted)
            Text(table.name(of: move.to)).bold()
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(move.amount.formatted()) pt").monospacedDigit()
                Text(move.date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - チップを動かすシート

struct MoveDraft: Identifiable {
    let id = UUID()
    var from: ChipParty?
    var to: ChipParty?
    var amount: Int?
}

private struct MoveSheet: View {
    let table: ChipTable
    let sources: [ChipParty]
    let destinations: [ChipParty]
    let onMove: (ChipParty, ChipParty, Int) -> Void
    @State private var from: ChipParty
    @State private var to: ChipParty
    @State private var amount: Int?
    @Environment(\.dismiss) private var dismiss

    private static let steps = [10, 50, 100, 500, 1000]

    init(draft: MoveDraft, table: ChipTable, sources: [ChipParty], destinations: [ChipParty], onMove: @escaping (ChipParty, ChipParty, Int) -> Void) {
        self.table = table
        self.sources = sources
        self.destinations = destinations
        self.onMove = onMove
        let from = draft.from.flatMap { sources.contains($0) ? $0 : nil } ?? sources.first ?? .bank
        let to = draft.to.flatMap { destinations.contains($0) ? $0 : nil }
            ?? destinations.first { $0 != from } ?? .pot
        _from = State(initialValue: from)
        _to = State(initialValue: to)
        _amount = State(initialValue: draft.amount.flatMap { $0 > 0 ? $0 : nil })
    }

    private var available: Int? {
        switch from {
        case .member(let id): table.member(id)?.balance
        case .pot: table.pot
        case .bank: nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("から", selection: $from) {
                        ForEach(sources, id: \.self) { Text(table.name(of: $0)).tag($0) }
                    }
                    Picker("へ", selection: $to) {
                        ForEach(destinations.filter { $0 != from }, id: \.self) { Text(table.name(of: $0)).tag($0) }
                    }
                } footer: {
                    if let available { Text("\(table.name(of: from))：\(available.formatted()) pt") }
                }

                Section("ポイント") {
                    HStack {
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.numberPad)
                            .font(.title2.bold().monospacedDigit())
                        Text("pt").foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(Self.steps, id: \.self) { step in
                            stepButton("+\(step.formatted())") { amount = (amount ?? 0) + step }
                        }
                        if let available, available > 0 {
                            stepButton("全部") { amount = available }
                        }
                        stepButton("0") { amount = nil }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("チップを動かす")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("動かす") {
                        if let amount { onMove(from, to, amount) }
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0 || from == to)
                }
            }
            .onChange(of: from) {
                if to == from, let other = destinations.first(where: { $0 != from }) { to = other }
            }
        }
        .presentationDetents([.large])
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold().monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
    }
}
