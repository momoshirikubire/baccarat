import Charts
import SwiftUI

/// ブラックジャックの勝敗と収支の記録
struct BlackjackView: View {
    let store: BlackjackStore
    @State private var doubled = false
    @State private var confirmNew = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    SessionSummary(session: store.current)
                    RoadCard(title: "収支の推移", detail: "1ベット = 1") {
                        NetChart(session: store.current).padding(10)
                    }
                    RoadCard(title: "最近の手", detail: "\(store.current.hands.count) 手") {
                        RecentHands(hands: store.current.hands).padding(10)
                    }
                    NavigationLink {
                        CountTrainerView()
                    } label: {
                        HStack {
                            Label("Hi-Lo カウントの練習", systemImage: "brain.head.profile")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        .font(.subheadline.bold())
                        .padding(12)
                        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                    }
                    .foregroundStyle(Theme.ink)
                }
                .padding(12)
            }
            .background(Theme.background)
            .navigationTitle("ブラックジャック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        Label("過去のセッション", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { confirmNew = true } label: {
                        Label("新しいセッション", systemImage: "plus.square.on.square")
                    }
                }
            }
            .tipButton()
            .safeAreaInset(edge: .bottom, spacing: 0) { deck }
            .confirmationDialog("新しいセッションを始めますか？", isPresented: $confirmNew, titleVisibility: .visible) {
                Button("新しいセッションを始める") {
                    store.startNewSession()
                    doubled = false
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("いまのセッションは「過去のセッション」に残ります。")
            }
            .sheet(isPresented: $showHistory) { BlackjackHistoryView(store: store) }
        }
    }

    private var deck: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                result(.win, color: Theme.tie)
                result(.lose, color: Theme.banker)
                result(.push, color: Theme.muted)
            }
            HStack(spacing: 8) {
                result(.blackjack, color: Theme.player)
                result(.surrender, color: Theme.deckButton)
                Button { doubled.toggle() } label: {
                    Text("ダブル")
                        .font(.footnote.bold())
                        .foregroundStyle(doubled ? Theme.deck : Theme.deckInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(doubled ? Theme.warning : Theme.deckButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityAddTraits(doubled ? .isSelected : [])
                Button { store.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.deckButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("1つ戻す")
                .disabled(!store.canUndo)
                .opacity(store.canUndo ? 1 : 0.5)
            }
        }
        .foregroundStyle(Theme.deckInk)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.deck.ignoresSafeArea(edges: .bottom))
        .sensoryFeedback(.impact(weight: .light), trigger: store.current.hands.count)
    }

    private func result(_ r: BJResult, color: Color) -> some View {
        Button {
            store.record(r, doubled: doubled)
            doubled = false
        } label: {
            VStack(spacing: 1) {
                Text(r.title).font(.headline)
                Text((r.units * (doubled && r.canDouble ? 2 : 1)).signedUnits).font(.caption2.monospacedDigit()).opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressStyle())
    }
}

struct SessionSummary: View {
    let session: BJSession

    var body: some View {
        let counts = Dictionary(grouping: session.hands, by: \.result).mapValues(\.count)
        HStack(spacing: 6) {
            tile(session.net.signedUnits, "収支", session.net >= 0 ? Theme.tie : Theme.banker)
            tile(session.winRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–", "勝率", Theme.ink)
            tile("\(counts[.win, default: 0] + counts[.blackjack, default: 0])", "勝ち", Theme.tie)
            tile("\(counts[.lose, default: 0] + counts[.surrender, default: 0])", "負け", Theme.banker)
            tile("\(counts[.push, default: 0])", "引き分け", Theme.muted)
        }
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.sheet)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
    }
}

struct NetChart: View {
    let session: BJSession

    var body: some View {
        let points = Array(session.runningNet.enumerated())
        if session.hands.isEmpty {
            Text("下のボタンで1手ずつ記録すると、ここに収支の推移が出ます。")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart {
                RuleMark(y: .value("0", 0)).foregroundStyle(Theme.line)
                ForEach(points, id: \.offset) { p in
                    LineMark(x: .value("手", p.offset), y: .value("収支", p.element))
                        .foregroundStyle(Theme.ink)
                        .interpolationMethod(.linear)
                }
                if let last = points.last {
                    PointMark(x: .value("手", last.offset), y: .value("収支", last.element))
                        .foregroundStyle(last.element >= 0 ? Theme.tie : Theme.banker)
                        .annotation(position: .top) {
                            Text(last.element.signedUnits).font(.caption2.bold().monospacedDigit())
                        }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .frame(height: 150)
        }
    }
}

struct RecentHands: View {
    let hands: [BJHand]

    var body: some View {
        if hands.isEmpty {
            Text("まだ記録がありません。").font(.footnote).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(hands.enumerated()), id: \.offset) { i, h in
                            Text(h.result.title + (h.doubled && h.result.canDouble ? "×2" : ""))
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(color(h), in: Capsule())
                                .id(i)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(hands.count - 1, anchor: .trailing) }
                .onChange(of: hands.count) { proxy.scrollTo(hands.count - 1, anchor: .trailing) }
            }
        }
    }

    private func color(_ h: BJHand) -> Color {
        h.units > 0 ? Theme.tie : h.units < 0 ? Theme.banker : Theme.muted
    }
}

struct BlackjackHistoryView: View {
    let store: BlackjackStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.archive.isEmpty {
                    ContentUnavailableView(
                        "過去のセッションはまだありません",
                        systemImage: "clock",
                        description: Text("右上の「新しいセッション」を押すと、いまのセッションがここに残ります。")
                    )
                } else {
                    List {
                        ForEach(store.archive) { s in
                            NavigationLink(value: s) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.bold())
                                        Text("\(s.hands.count)手").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(s.net.signedUnits)
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(s.net >= 0 ? Theme.tie : Theme.banker)
                                }
                            }
                        }
                        .onDelete { store.deleteArchived(at: $0) }
                    }
                }
            }
            .navigationTitle("過去のセッション")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BJSession.self) { s in
                ScrollView {
                    VStack(spacing: 10) {
                        SessionSummary(session: s)
                        RoadCard(title: "収支の推移") { NetChart(session: s).padding(10) }
                    }
                    .padding(12)
                }
                .background(Theme.background)
                .navigationTitle(s.startedAt.formatted(date: .abbreviated, time: .shortened))
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
