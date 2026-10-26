import SwiftUI

@main
struct KeisenApp: App {
    @State private var shoes = ShoeStore()
    @State private var tips = TipStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(shoes)
                .environment(tips)
        }
    }
}
