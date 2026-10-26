import SwiftUI

/// バカラのルールと、3枚目を引くかの判定。罫線画面の左上の「ルール」から開く。
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rulesTab") private var tab = "judge"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("表示", selection: $tab) {
                        Text("3枚目の判定").tag("judge")
                        Text("ルール").tag("rules")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)

                    if tab == "judge" {
                        ThirdCardJudge()
                    } else {
                        RulesSheet()
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("バカラのルール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

/// 配られたカードを選ぶと、3枚目を引くかと勝ち負けを出す
struct ThirdCardJudge: View {
    @State private var player: [CardRank?] = [nil, nil, nil]
    @State private var banker: [CardRank?] = [nil, nil, nil]

    private var playerTwo: [CardRank]? { first2(player) }
    private var bankerTwo: [CardRank]? { first2(banker) }

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // 横向きでは、カードを左・判定の流れを右に並べて1画面に収める
        if verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: 16) {
                picks.frame(maxWidth: .infinity)
                stepsBox.frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                picks
                stepsBox
            }
        }
    }

    private var picks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配られたカードを順に選ぶと、3枚目を引くかどうかを出します。10・J・Q・K は 0、A は 1 と数えます。")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            handRow("PLAYER", color: Theme.player, cards: $player, showThird: playerNeedsThird)
            handRow("BANKER", color: Theme.banker, cards: $banker, showThird: bankerNeedsThird)

            Button("最初から選び直す") {
                player = [nil, nil, nil]
                banker = [nil, nil, nil]
            }
            .font(.footnote.bold())
            .foregroundStyle(Theme.muted)
        }
    }

    private var stepsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, line in
                Label(line, systemImage: "arrow.right.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    // MARK: 判定

    private var playerNeedsThird: Bool {
        guard let p = playerTwo, let b = bankerTwo else { return false }
        return ThirdCard.playerDraws(player: ThirdCard.total(p), banker: ThirdCard.total(b))
    }

    /// BANKER の3枚目を選ぶ欄を出すか（PLAYER の3枚目が決まってから）
    private var bankerNeedsThird: Bool {
        guard let p = playerTwo, let b = bankerTwo else { return false }
        if playerNeedsThird && player[2] == nil { return false }
        return ThirdCard.bankerDraws(banker: ThirdCard.total(b), player: ThirdCard.total(p),
                                     playerThird: playerNeedsThird ? player[2] : nil)
    }

    private var steps: [String] {
        guard let p = playerTwo, let b = bankerTwo else {
            return ["PLAYER と BANKER の2枚ずつを選んでください"]
        }
        let pt = ThirdCard.total(p), bt = ThirdCard.total(b)
        var lines = ["最初の2枚：PLAYER \(pt)・BANKER \(bt)"]
        if ThirdCard.isNatural(player: pt, banker: bt) {
            lines.append("どちらかが 8 か 9（ナチュラル）なので、どちらも引かずに勝負です")
            lines.append(result(pt, bt))
            return lines
        }
        var playerFinal = pt
        if playerNeedsThird {
            lines.append("PLAYER は \(pt)（0〜5）なので、3枚目を引きます")
            guard let third = player[2] else {
                lines.append("PLAYER の3枚目を選ぶと、BANKER が引くかがわかります")
                return lines
            }
            playerFinal = ThirdCard.total(p + [third])
            lines.append("PLAYER の3枚目は \(third.label)。PLAYER の合計は \(playerFinal)")
        } else {
            lines.append("PLAYER は \(pt)（6・7）なので、スタンドです")
        }
        let playerThird = playerNeedsThird ? player[2] : nil
        lines.append(ThirdCard.bankerReason(banker: bt, playerThird: playerThird))
        var bankerFinal = bt
        if bankerNeedsThird {
            lines.append("→ BANKER は3枚目を引きます")
            guard let third = banker[2] else {
                lines.append("BANKER の3枚目を選ぶと、勝ち負けがわかります")
                return lines
            }
            bankerFinal = ThirdCard.total(b + [third])
            lines.append("BANKER の3枚目は \(third.label)。BANKER の合計は \(bankerFinal)")
        } else {
            lines.append("→ BANKER はスタンドです")
        }
        lines.append(result(playerFinal, bankerFinal))
        return lines
    }

    private func result(_ p: Int, _ b: Int) -> String {
        if p == b { return "PLAYER \(p)・BANKER \(b) で TIE" }
        return p > b ? "PLAYER \(p)・BANKER \(b) で PLAYER の勝ち" : "PLAYER \(p)・BANKER \(b) で BANKER の勝ち"
    }

    private func first2(_ cards: [CardRank?]) -> [CardRank]? {
        guard let a = cards[0], let b = cards[1] else { return nil }
        return [a, b]
    }

    // MARK: 見た目

    private func handRow(_ title: String, color: Color, cards: Binding<[CardRank?]>, showThird: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .frame(width: 76, alignment: .leading)
            cardPicker("1枚目", cards: cards, index: 0, color: color)
            cardPicker("2枚目", cards: cards, index: 1, color: color)
            if showThird {
                cardPicker("3枚目", cards: cards, index: 2, color: color)
            }
            Spacer(minLength: 0)
            let picked = cards.wrappedValue.compactMap { $0 }
            if picked.count >= 2 {
                Text("合計 \(ThirdCard.total(picked))")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(Theme.ink)
            }
        }
        // 3枚目が要らなくなったら消しておく
        .onChange(of: showThird) { if !showThird { cards.wrappedValue[2] = nil } }
    }

    private func cardPicker(_ label: String, cards: Binding<[CardRank?]>, index: Int, color: Color) -> some View {
        Menu {
            ForEach(CardRank.allCases) { rank in
                Button(rank.label) { cards.wrappedValue[index] = rank }
            }
        } label: {
            let rank = cards.wrappedValue[index]
            VStack(spacing: 1) {
                Text(rank?.label ?? "?").font(.title3.bold())
                Text(label).font(.system(size: 9))
            }
            .foregroundStyle(rank == nil ? Theme.muted : color)
            .frame(width: 52, height: 52)
            .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(rank == nil ? Theme.line : color, lineWidth: 1.5))
        }
        .accessibilityLabel("\(label) \(cards.wrappedValue[index]?.label ?? "未選択")")
    }
}

/// バカラのルールのまとめ
struct RulesSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("勝ち負け") {
                Text("PLAYER と BANKER に2枚ずつ配り、合計の下1けたが 9 に近いほうが勝ちです。同じなら TIE（引き分け）です。")
            }
            section("カードの数え方") {
                Text("A は 1、2〜9 はそのまま、10・J・Q・K は 0。合計が 10 を超えたら下1けただけを見ます（7 + 8 = 15 → 5）。")
            }
            section("ナチュラル") {
                Text("最初の2枚でどちらかが 8 か 9 なら、どちらも3枚目を引かずに勝負が決まります。")
            }
            section("PLAYER の3枚目") {
                VStack(alignment: .leading, spacing: 4) {
                    row("0〜5", "引く")
                    row("6・7", "スタンド（引かない）")
                }
            }
            section("BANKER の3枚目") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAYER がスタンドしたとき：BANKER は 0〜5 で引き、6・7 でスタンド。")
                        .padding(.bottom, 4)
                    Text("PLAYER が3枚目を引いたときは、BANKER の合計と PLAYER の3枚目で決まります。")
                        .padding(.bottom, 2)
                    row("0〜2", "いつも引く")
                    row("3", "PLAYER の3枚目が 8 以外なら引く")
                    row("4", "PLAYER の3枚目が 2〜7 なら引く")
                    row("5", "PLAYER の3枚目が 4〜7 なら引く")
                    row("6", "PLAYER の3枚目が 6・7 なら引く")
                    row("7", "いつもスタンド")
                }
            }
            section("ペア") {
                Text("最初の2枚が同じ数字（例：7 と 7）のとき、B PAIR・P PAIR として記録します。")
            }
            Text("ルールの細かいところは、お店やテーブルによってちがうことがあります。")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            content().font(.subheadline).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private func row(_ total: String, _ action: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(total).font(.subheadline.monospacedDigit().bold()).frame(width: 44, alignment: .leading)
            Text(action)
        }
    }
}

#Preview {
    RulesView()
}
