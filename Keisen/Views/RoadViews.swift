import SwiftUI

/// 罫線の描き方（丸・塗り・斜線）
enum Pen {
    static func ring(_ ctx: inout GraphicsContext, _ center: CGPoint, radius: CGFloat, color: Color, width: CGFloat) {
        ctx.stroke(Path(ellipseIn: box(center, radius)), with: .color(color), lineWidth: width)
    }

    static func dot(_ ctx: inout GraphicsContext, _ center: CGPoint, radius: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: box(center, radius)), with: .color(color))
    }

    static func slash(_ ctx: inout GraphicsContext, _ center: CGPoint, radius: CGFloat, color: Color, width: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: center.x - radius, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y - radius))
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// 大眼仔は白抜きの丸、小路は塗りの丸、曱甴路は斜線
    static func mark(_ ctx: inout GraphicsContext, _ center: CGPoint, cell: CGFloat, road: DerivedRoad, mark: Mark) {
        let color = Theme.color(mark)
        switch road {
        case .bigEye: ring(&ctx, center, radius: cell / 2 - 2.2, color: color, width: max(1.6, cell / 8))
        case .small: dot(&ctx, center, radius: cell / 2 - 2.2, color: color)
        case .cockroach: slash(&ctx, center, radius: cell / 2 - 2.6, color: color, width: max(1.8, cell / 7))
        }
    }

    private static func box(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }
}

/// 6段の方眼。横にスクロールでき、新しい列が増えると右端へ寄る。
struct RoadGrid: View {
    let cellSize: CGFloat
    let usedColumns: Int
    let draw: (inout GraphicsContext) -> Void

    var body: some View {
        let height = CGFloat(Roads.rows) * cellSize
        GeometryReader { geo in
            let columns = max(usedColumns + 3, Int((geo.size.width / cellSize).rounded(.up)))
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Canvas { ctx, size in
                            var lines = Path()
                            for i in 0...columns {
                                let x = CGFloat(i) * cellSize
                                lines.move(to: CGPoint(x: x, y: 0))
                                lines.addLine(to: CGPoint(x: x, y: height))
                            }
                            for j in 0...Roads.rows {
                                let y = CGFloat(j) * cellSize
                                lines.move(to: CGPoint(x: 0, y: y))
                                lines.addLine(to: CGPoint(x: size.width, y: y))
                            }
                            ctx.stroke(lines, with: .color(Theme.line), lineWidth: 1)
                            draw(&ctx)
                        }
                        .frame(width: CGFloat(columns) * cellSize, height: height)
                        Color.clear.frame(width: 1, height: 1).id("end")
                    }
                }
                .onAppear { proxy.scrollTo("end", anchor: .trailing) }
                .onChange(of: usedColumns) { proxy.scrollTo("end", anchor: .trailing) }
            }
        }
        .frame(height: height)
    }
}

struct BigRoadView: View {
    let road: Roads.BigRoad
    var cell: CGFloat = 22

    var body: some View {
        let cells = Roads.place(road.columns)
        let used = (cells.map(\.x).max() ?? -1) + 1
        let leadingTies = road.leadingTies
        RoadGrid(cellSize: cell, usedColumns: used) { ctx in
            for c in cells {
                let center = CGPoint(x: (CGFloat(c.x) + 0.5) * cell, y: (CGFloat(c.y) + 0.5) * cell)
                Pen.ring(&ctx, center, radius: cell / 2 - 3.5, color: Theme.color(c.item.outcome), width: 2.6)
                if c.item.ties > 0 {
                    Pen.slash(&ctx, center, radius: cell / 2 - 5, color: Theme.tie, width: 2.2)
                    if c.item.ties > 1 {
                        ctx.draw(Text("\(c.item.ties)").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.ink), at: center)
                    }
                }
                if c.item.bankerPair {
                    Pen.dot(&ctx, CGPoint(x: CGFloat(c.x) * cell + 4.5, y: CGFloat(c.y) * cell + 4.5), radius: 2.6, color: Theme.banker)
                }
                if c.item.playerPair {
                    Pen.dot(&ctx, CGPoint(x: CGFloat(c.x + 1) * cell - 4.5, y: CGFloat(c.y + 1) * cell - 4.5), radius: 2.6, color: Theme.player)
                }
            }
            if leadingTies > 0 {
                Pen.slash(&ctx, CGPoint(x: cell / 2, y: cell / 2), radius: cell / 2 - 5, color: Theme.tie, width: 2.2)
            }
        }
    }
}

struct BeadPlateView: View {
    let hands: [Hand]
    var cell: CGFloat = 26

    var body: some View {
        RoadGrid(cellSize: cell, usedColumns: (hands.count + Roads.rows - 1) / Roads.rows) { ctx in
            for (i, h) in hands.enumerated() {
                let x = CGFloat(i / Roads.rows), y = CGFloat(i % Roads.rows)
                let center = CGPoint(x: (x + 0.5) * cell, y: (y + 0.5) * cell)
                Pen.dot(&ctx, center, radius: cell / 2 - 2.5, color: Theme.color(h.outcome))
                ctx.draw(Text(h.outcome.bead).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Color.white), at: center)
                if h.bankerPair {
                    Pen.dot(&ctx, CGPoint(x: x * cell + 5, y: y * cell + 5), radius: 3.2, color: Theme.sheet)
                    Pen.dot(&ctx, CGPoint(x: x * cell + 5, y: y * cell + 5), radius: 2.4, color: Theme.banker)
                }
                if h.playerPair {
                    Pen.dot(&ctx, CGPoint(x: (x + 1) * cell - 5, y: (y + 1) * cell - 5), radius: 3.2, color: Theme.sheet)
                    Pen.dot(&ctx, CGPoint(x: (x + 1) * cell - 5, y: (y + 1) * cell - 5), radius: 2.4, color: Theme.player)
                }
            }
        }
    }
}

struct DerivedRoadView: View {
    let columns: [[BigRoadEntry]]
    let road: DerivedRoad
    var cell: CGFloat = 13

    var body: some View {
        let marks = Roads.derived(columns, road: road)
        let cells = Roads.place(Roads.columns(marks) { $0 })
        let used = (cells.map(\.x).max() ?? -1) + 1
        RoadGrid(cellSize: cell, usedColumns: used) { ctx in
            for c in cells {
                let center = CGPoint(x: (CGFloat(c.x) + 0.5) * cell, y: (CGFloat(c.y) + 0.5) * cell)
                Pen.mark(&ctx, center, cell: cell, road: road, mark: c.item)
            }
        }
    }
}

/// 問路や凡例に使う小さな印
struct MarkIcon: View {
    let road: DerivedRoad
    let mark: Mark
    var size: CGFloat = 16

    var body: some View {
        Canvas { ctx, _ in
            Pen.mark(&ctx, CGPoint(x: size / 2, y: size / 2), cell: size, road: road, mark: mark)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(road.title) \(mark == .red ? "赤" : "青")")
    }
}

struct RoadCard<Content: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.caption.bold()).tracking(1)
                Spacer()
                if let detail { Text(detail).font(.caption) }
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            Divider().overlay(Theme.line)
            content
        }
        .background(Theme.sheet)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
    }
}

/// 1つのシューの罫線一式（いまのシューにも、過去のシューにも使う）
struct RoadsBoard: View {
    let hands: [Hand]

    var body: some View {
        let big = Roads.bigRoad(hands)
        VStack(spacing: 10) {
            RoadCard(title: "大路", detail: streak(big)) { BigRoadView(road: big) }
            RoadCard(title: "珠盤路") { BeadPlateView(hands: hands) }
            ForEach(DerivedRoad.allCases) { road in
                RoadCard(title: road.title) { DerivedRoadView(columns: big.columns, road: road) }
            }
        }
    }

    private func streak(_ big: Roads.BigRoad) -> String? {
        guard let current = big.columns.last, let head = current.first else { return nil }
        let longest = big.columns.map(\.count).max() ?? 0
        return "いま \(head.outcome.rawValue)\(current.count)連・最長 \(longest)連"
    }
}

struct StatsBar: View {
    let shoe: Shoe

    var body: some View {
        let c = shoe.count
        let n = shoe.hands.count
        HStack(spacing: 6) {
            tile("\(c.banker)", "バンカー", percent(c.banker, n), Theme.banker)
            tile("\(c.player)", "プレイヤー", percent(c.player, n), Theme.player)
            tile("\(c.tie)", "タイ", percent(c.tie, n), Theme.tie)
            tile("\(c.bankerPair)", "Bペア", nil, Theme.banker)
            tile("\(c.playerPair)", "Pペア", nil, Theme.player)
        }
    }

    private func percent(_ v: Int, _ n: Int) -> String {
        n == 0 ? "–" : "\(Int((Double(v) / Double(n) * 100).rounded()))%"
    }

    private func tile(_ value: String, _ label: String, _ sub: String?, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
            Text(sub ?? " ").font(.system(size: 10, design: .monospaced))
        }
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.sheet)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
    }
}
