import SwiftUI

/// Hi-Lo カウントの練習。カードを1枚ずつめくり、頭の中で数えた値を答え合わせする。
/// アプリの中で配るカードだけを使う練習用で、実際のテーブルで使うものではない。
struct CountTrainerView: View {
    @State private var decks = 6
    @State private var shoe: [HiLo.Card] = HiLo.shoe(decks: 6)
    @State private var dealt = 0
    @State private var guess = 0
    @State private var revealed = false
    @State private var streak = 0

    private var runningCount: Int {
        shoe.prefix(dealt).reduce(0) { $0 + HiLo.value($1.rank) }
    }

    private var decksLeft: Double {
        max(0.5, Double(shoe.count - dealt) / 52)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("2〜6 は +1、7〜9 は 0、10・絵札・A は −1。カードをめくりながら合計を頭の中で数えて、ときどき答え合わせします。")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("デッキ数", selection: $decks) {
                    ForEach([1, 2, 6, 8], id: \.self) { Text("\($0)デッキ").tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: decks) { reset() }

                cardView
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                Text("\(dealt) / \(shoe.count) 枚")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)

                Button {
                    if dealt < shoe.count { dealt += 1 }
                    revealed = false
                } label: {
                    Text(dealt < shoe.count ? "次のカード" : "シューが終わりました")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.player, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressStyle())
                .disabled(dealt >= shoe.count)

                VStack(spacing: 10) {
                    Stepper(value: $guess, in: -60...60) {
                        HStack {
                            Text("あなたのカウント")
                            Spacer()
                            Text(guess > 0 ? "+\(guess)" : "\(guess)").font(.title3.bold().monospacedDigit())
                        }
                    }
                    Button("答え合わせ") {
                        revealed = true
                        streak = guess == runningCount ? streak + 1 : 0
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ink)
                    .disabled(dealt == 0)

                    if revealed {
                        let ok = guess == runningCount
                        VStack(spacing: 4) {
                            Label(ok ? "正解" : "ちがいます", systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(ok ? Theme.tie : Theme.banker)
                            Text("ランニングカウント \(signed(runningCount))・トゥルーカウント \(String(format: "%+.1f", Double(runningCount) / decksLeft))")
                                .font(.subheadline.monospacedDigit())
                            Text("残り約 \(String(format: "%.1f", decksLeft)) デッキ・連続正解 \(streak)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(12)
                .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 10))

                Button("シャッフルしてやり直す", role: .destructive) { reset() }
                    .font(.footnote)
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("カウントの練習")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var cardView: some View {
        if dealt == 0 {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.player.opacity(0.85))
                .frame(width: 120, height: 168)
                .overlay(Text("めくる").font(.headline).foregroundStyle(.white))
        } else {
            let card = shoe[dealt - 1]
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .frame(width: 120, height: 168)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.5))
                .overlay(
                    VStack(spacing: 4) {
                        Text(card.rank).font(.system(size: 44, weight: .bold))
                        Text(card.suit).font(.system(size: 36))
                    }
                    .foregroundStyle(card.isRed ? Color(uiColor: UIColor(hex: 0xC81E32)) : Color.black)
                )
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .id(dealt)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

    private func reset() {
        shoe = HiLo.shoe(decks: decks)
        dealt = 0
        guess = 0
        revealed = false
        streak = 0
    }
}
