import AVFoundation
import SwiftUI

// 勝敗を記録したときに、画面いっぱいの結果表示と英語の読み上げを出す部品。
// Hand と Outcome（Models/Hand.swift）と Theme だけを使うので、チップの機能がなくても使える。
//
// 使い方（罫線画面など）：
//   @State private var announcement: ResultAnnouncement?
//   @AppStorage(ResultAnnouncement.storageKey) private var announceResults = true
//   記録したら → if announceResults { announcement = ResultAnnouncement(hand: hand, handNumber: n); ResultVoice.speak(hand) }
//   画面に → .resultSplash($announcement)

/// 勝敗を入れたときに画面いっぱいに出す結果（「BANKER」など）。自分の増減 pt を添えることもできる。
struct ResultAnnouncement: Identifiable, Equatable {
    /// 罫線画面で「結果を大きく出して読み上げる」の設定（初期値オン）
    static let storageKey = "announceResults"

    let id = UUID()
    var hand: Hand
    var handNumber: Int?
    /// プレイヤーの増減。ベットしていなければ nil。
    var net: Int?
}

extension View {
    /// 結果を大きく出す。2.5秒で消え、タップでもすぐ消せる。
    func resultSplash(_ item: Binding<ResultAnnouncement?>) -> some View {
        overlay {
            if let value = item.wrappedValue {
                ResultSplashView(item: value)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { item.wrappedValue = nil } }
                    .task(id: value.id) {
                        try? await Task.sleep(for: .seconds(2.5))
                        if item.wrappedValue?.id == value.id {
                            withAnimation(.easeOut(duration: 0.3)) { item.wrappedValue = nil }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
    }
}

private struct ResultSplashView: View {
    let item: ResultAnnouncement

    var body: some View {
        let color = Theme.color(item.hand.outcome)
        ZStack {
            color.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 6) {
                if let n = item.handNumber {
                    Text("第\(n)手").font(.headline).opacity(0.85)
                }
                Text(Self.title(item.hand.outcome))
                    .font(.system(size: 110, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                let pairs = [item.hand.bankerPair ? "B PAIR" : nil,
                             item.hand.playerPair ? "P PAIR" : nil].compactMap { $0 }
                if !pairs.isEmpty {
                    Text(pairs.joined(separator: "  ·  ")).font(.title2.bold())
                }
                if let net = item.net {
                    Text(net == 0 ? "±0 pt" : "\(net > 0 ? "+" : "")\(net.formatted()) pt")
                        .font(.system(size: 44, weight: .heavy).monospacedDigit())
                        .padding(.horizontal, 18)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.18), in: Capsule())
                        .padding(.top, 6)
                }
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("タップで閉じます")
    }

    static func title(_ outcome: Outcome) -> String {
        switch outcome {
        case .banker: "BANKER"
        case .player: "PLAYER"
        case .tie: "TIE"
        }
    }
}

/// 結果の英語の読み上げ（「Player」「Banker, player pair」など）。消音スイッチがオンなら鳴らない。
enum ResultVoice {
    private static let synthesizer = AVSpeechSynthesizer()
    private static var isPrepared = false

    static func speak(_ hand: Hand) {
        if !isPrepared {
            // ほかのアプリの音を止めず、消音スイッチに従う
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            isPrepared = true
        }
        var phrase: String
        switch hand.outcome {
        case .banker: phrase = "Banker"
        case .player: phrase = "Player"
        case .tie: phrase = "Tie"
        }
        switch (hand.bankerPair, hand.playerPair) {
        case (true, true): phrase += ", banker pair and player pair"
        case (true, false): phrase += ", banker pair"
        case (false, true): phrase += ", player pair"
        case (false, false): break
        }
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }
}
