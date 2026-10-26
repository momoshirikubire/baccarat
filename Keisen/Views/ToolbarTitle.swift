import SwiftUI

/// ツールバーのボタンの中身：アイコンと短い文字を並べる。
/// ツールバーの中では Label(...).labelStyle(.titleAndIcon) でもアイコンだけになるので、自分で並べる。
struct ToolbarTitle: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
