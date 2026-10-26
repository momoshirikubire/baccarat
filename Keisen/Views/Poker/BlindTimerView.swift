import AudioToolbox
import SwiftUI

struct BlindTimerView: View {
    @Bindable var store: PokerStore
    @State private var editing = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let clock = store.clock
            let remaining = clock.remaining(at: context.date)
            let level = clock.levels.indices.contains(clock.level) ? clock.levels[clock.level] : nil
            let next = clock.levels.indices.contains(clock.level + 1) ? clock.levels[clock.level + 1] : nil
            ScrollView {
                VStack(spacing: 16) {
                    Text("レベル \(clock.level + 1) / \(clock.levels.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.muted)
                    Text(level?.label ?? "–")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(timeText(remaining))
                        .font(.system(size: 72, weight: .semibold, design: .monospaced))
                        .foregroundStyle(remaining <= 60 && clock.isRunning ? Theme.banker : Theme.ink)
                        .contentTransition(.numericText())
                    ProgressView(value: clock.levelLength - remaining, total: max(1, clock.levelLength))
                        .tint(Theme.ink)
                    Text(next.map { "次：\($0.label)" } ?? "最後のレベルです")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)

                    HStack(spacing: 12) {
                        control("backward.end.fill", "前のレベル") { store.clock.go(to: clock.level - 1, at: .now) }
                            .disabled(clock.level == 0)
                        Button {
                            if clock.isRunning { store.clock.pause(at: .now) } else { store.clock.start(at: .now) }
                        } label: {
                            Label(clock.isRunning ? "一時停止" : "スタート", systemImage: clock.isRunning ? "pause.fill" : "play.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(clock.isRunning ? Theme.banker : Theme.tie, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(PressStyle())
                        control("forward.end.fill", "次のレベル") { store.clock.go(to: clock.level + 1, at: .now) }
                            .disabled(next == nil)
                    }

                    Button("レベルと時間を編集") { editing = true }
                        .font(.subheadline)
                        .disabled(clock.isRunning)
                    Text("動いているあいだは画面が消えないようにしています。")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .onChange(of: context.date) {
                if store.clock.advanceIfNeeded(at: context.date) {
                    AudioServicesPlaySystemSound(1005)
                    store.save()
                }
            }
        }
        .onChange(of: store.clock) { store.save() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = store.clock.isRunning }
        .onChange(of: store.clock.isRunning) { UIApplication.shared.isIdleTimerDisabled = store.clock.isRunning }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sensoryFeedback(.warning, trigger: store.clock.level)
        .sheet(isPresented: $editing) { BlindLevelEditor(clock: $store.clock) }
    }

    private func control(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 56, height: 56)
                .background(Theme.sheet, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
        .foregroundStyle(Theme.ink)
        .accessibilityLabel(label)
    }

    private func timeText(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct BlindLevelEditor: View {
    @Binding var clock: BlindClock
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper("1レベル \(clock.minutesPerLevel) 分", value: $clock.minutesPerLevel, in: 1...120)
                }
                Section("レベル（SB / BB / アンティ）") {
                    ForEach($clock.levels) { $level in
                        HStack {
                            number($level.small)
                            Text("/")
                            number($level.big)
                            Text("/")
                            number($level.ante)
                        }
                    }
                    .onDelete { clock.levels.remove(atOffsets: $0) }
                    .onMove { clock.levels.move(fromOffsets: $0, toOffset: $1) }
                    Button("レベルを追加") {
                        let last = clock.levels.last ?? BlindLevel(small: 25, big: 50)
                        clock.levels.append(BlindLevel(small: last.small * 2, big: last.big * 2, ante: last.ante * 2))
                    }
                    Button("最初の設定に戻す") { clock.levels = BlindLevel.defaults }
                }
            }
            .navigationTitle("ブラインドの設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        clock.go(to: clock.level, at: .now)
                        dismiss()
                    }
                }
            }
        }
    }

    private func number(_ value: Binding<Int>) -> some View {
        TextField("0", value: value, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
    }
}
