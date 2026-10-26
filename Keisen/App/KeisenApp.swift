import SwiftUI

@main
struct KeisenApp: App {
    @State private var baccarat = ShoeStore(game: .baccarat)
    @State private var dragonTiger = ShoeStore(game: .dragonTiger)
    @State private var blackjack = BlackjackStore()
    @State private var poker = PokerStore()
    @State private var scores = ScoreStore()
    @State private var chips = ChipStore()
    @State private var tips = TipStore()
    @AppStorage("selectedTab") private var tab = "baccarat"

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                RoadGameView(store: baccarat)
                    .tabItem { Label("バカラ", systemImage: "suit.diamond.fill") }
                    .tag("baccarat")
                RoadGameView(store: dragonTiger)
                    .tabItem { Label("ドラゴン", systemImage: "suit.heart.fill") }
                    .tag("dragonTiger")
                BlackjackView(store: blackjack)
                    .tabItem { Label("BJ", systemImage: "suit.spade.fill") }
                    .tag("blackjack")
                PokerView(store: poker)
                    .tabItem { Label("ポーカー", systemImage: "suit.club.fill") }
                    .tag("poker")
                ChipView(store: chips)
                    .tabItem { Label("チップ", systemImage: "circle.circle.fill") }
                    .tag("chips")
                ScoreSheetView(store: scores)
                    .tabItem { Label("点数表", systemImage: "list.number") }
                    .tag("scores")
            }
            .tint(Theme.ink)
            .environment(tips)
        }
    }
}
