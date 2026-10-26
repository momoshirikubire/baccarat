import StoreKit
import SwiftUI

struct TipJarView: View {
    @Environment(TipStore.self) private var tips
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("広告なしで使い続けられるように")
                            .font(.headline)
                        Text("罫線ノートは広告を出さず、すべての機能を無料で使えます。気に入ったら、開発の応援としてチップを送ってもらえるとうれしいです。チップを送っても機能は変わりません。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("チップを送る") {
                    if tips.isLoading {
                        HStack { ProgressView(); Text("読み込み中…").foregroundStyle(.secondary) }
                    } else if tips.loadFailed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("チップの一覧を読み込めませんでした。通信状態を確かめてください。")
                                .font(.subheadline)
                            Button("もう一度読み込む") { Task { await tips.load() } }
                        }
                    } else {
                        ForEach(tips.products, id: \.id) { product in
                            Button {
                                Task { await tips.buy(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.displayName).foregroundStyle(.primary)
                                        if !product.description.isEmpty {
                                            Text(product.description).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if tips.phase == .purchasing(product.id) {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Theme.banker.opacity(0.12), in: Capsule())
                                            .foregroundStyle(Theme.banker)
                                    }
                                }
                            }
                            .disabled(tips.isPurchasing)
                        }
                    }
                }

                if tips.phase == .thanks {
                    Section {
                        Label("ありがとうございます！とても励みになります。", systemImage: "heart.fill")
                            .foregroundStyle(Theme.banker)
                    }
                }
                if case .failed(let message) = tips.phase {
                    Section {
                        Text(message).foregroundStyle(.secondary)
                    }
                }
                if tips.tipCount > 0 {
                    Section {
                        Text("これまで \(tips.tipCount) 回応援してもらいました。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("応援する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await tips.load() }
            .onDisappear { if tips.phase != .idle { tips.phase = .idle } }
        }
    }
}

/// どの画面の右上にも置く「応援する」ボタン
struct TipButton: ViewModifier {
    @State private var showTips = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTips = true } label: {
                        Label("応援", systemImage: "gift").labelStyle(.titleAndIcon)
                    }
                }
            }
            .sheet(isPresented: $showTips) { TipJarView() }
    }
}

extension View {
    func tipButton() -> some View { modifier(TipButton()) }
}
