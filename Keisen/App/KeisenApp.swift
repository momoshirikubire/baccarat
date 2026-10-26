import SwiftUI

@main
struct KeisenApp: App {
    @State private var baccarat = ShoeStore(game: .baccarat)
    @State private var tips = TipStore()

    // 1.0 はバカラだけ。ドラゴンタイガー・ブラックジャック・ポーカー・点数表のコードは残してあり、
    // あとのアップデートで TabView に戻して出す（RoadGameView(store: ShoeStore(game: .dragonTiger)),
    // BlackjackView, PokerView, ScoreSheetView）。
    var body: some Scene {
        WindowGroup {
            RoadGameView(store: baccarat)
                .tint(Theme.ink)
                .environment(tips)
        }
    }
}
