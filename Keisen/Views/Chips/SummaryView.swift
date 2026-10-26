import SwiftUI

/// 終了したテーブルの結果：参加者ごとの最後の残高・はじめからの増減・勝った手／ベットした手。増減の大きい順。
/// pt の記録として出すだけで、だれがだれに払うといった精算は出さない。
struct SummaryView: View {
    let summary: ChipSummary
    /// 自分の行を目立たせる
    var myID: UUID? = nil
    var closeTitle = "閉じる"
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("テーブル", value: summary.tableName)
                    LabeledContent("時間", value: timeText)
                    LabeledContent("手の数", value: "\(summary.hands) 手")
                }

                Section {
                    if summary.rows.isEmpty {
                        Text("参加者はいませんでした。").foregroundStyle(.secondary)
                    }
                    ForEach(Array(summary.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(index + 1, row)
                            .listRowBackground(row.id == myID ? Theme.sheet.opacity(0.6) : nil)
                    }
                } header: {
                    Text("結果（増減の大きい順）")
                } footer: {
                    Text("増減は、もらった合計（はじめの持ち点＋追加）との差です。チップは pt で数える遊び用の記録で、お金には換えられません。")
                }
            }
            .navigationTitle("結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(closeTitle, action: onClose) }
            }
        }
    }

    private var timeText: String {
        let start = summary.startedAt.formatted(date: .abbreviated, time: .shortened)
        let end = summary.endedAt.formatted(date: .omitted, time: .shortened)
        return "\(start) 〜 \(end)"
    }

    private func rowView(_ rank: Int, _ row: ChipSummary.Row) -> some View {
        let isMe = row.id == myID
        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.muted)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name).font(isMe ? .headline : .body)
                    if isMe {
                        Text("あなた")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.ink, in: Capsule())
                    }
                }
                Text("勝った手 \(row.wins) / ベットした手 \(row.betHands)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                if row.rebuys > 0 {
                    Text("追加 +\(row.rebuyTotal.formatted()) pt（\(row.rebuys)回）")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.net == 0 ? "±0 pt" : "\(signed(row.net)) pt")
                    .font((isMe ? Font.title3 : .headline).bold().monospacedDigit())
                    .foregroundStyle(row.net > 0 ? Theme.tie : row.net < 0 ? Theme.banker : Theme.ink)
                Text("残高 \(row.balance.formatted()) pt")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, isMe ? 6 : 2)
        .overlay(alignment: .leading) {
            if isMe {
                RoundedRectangle(cornerRadius: 2).fill(Theme.ink).frame(width: 4).offset(x: -16)
            }
        }
    }
}

/// 親の端末に残っている、これまでの結果
struct PastSummariesList: View {
    let summaries: [ChipSummary]
    @State private var showing: ChipSummary?

    var body: some View {
        ForEach(summaries) { s in
            Button { showing = s } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.tableName).foregroundStyle(Theme.ink)
                        Text("\(s.endedAt.formatted(date: .abbreviated, time: .shortened))・\(s.hands) 手・\(s.rows.count) 人")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
        .sheet(item: $showing) { s in
            SummaryView(summary: s) { showing = nil }
        }
    }
}
