import SwiftUI

enum Theme {
    static let banker = Color(light: 0xC81E32, dark: 0xFF5A6A)
    static let player = Color(light: 0x1F4FD1, dark: 0x6D95FF)
    static let tie = Color(light: 0x128A55, dark: 0x3FC58A)
    static let background = Color(light: 0xEEF1EE, dark: 0x0D1210)
    static let sheet = Color(light: 0xFFFFFF, dark: 0x151C18)
    static let ink = Color(light: 0x18201C, dark: 0xE8EEEA)
    static let muted = Color(light: 0x5D6A63, dark: 0x94A39A)
    static let line = Color(light: 0xDFE5E1, dark: 0x243029)
    static let deck = Color(light: 0x18201C, dark: 0x050806)
    static let deckButton = Color(light: 0x2A332E, dark: 0x1C2520)
    static let deckInk = Color(light: 0xF3F6F4, dark: 0xE8EEEA)
    static let warning = Color(light: 0xF5C542, dark: 0xF5C542)

    static func color(_ outcome: Outcome) -> Color {
        switch outcome {
        case .banker: banker
        case .player: player
        case .tie: tie
        }
    }

    static func color(_ mark: Mark) -> Color {
        mark == .red ? banker : player
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
