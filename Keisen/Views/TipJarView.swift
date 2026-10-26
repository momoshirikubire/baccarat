import StoreKit
import SwiftUI

struct TipJarView: View {
    @Environment(TipStore.self) private var tips
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeveloperNote()
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

/// 応援画面のいちばん上に出す、作っている人からのひとこと
struct DeveloperNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("DeveloperIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.line))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("広告なしで続けたい！").font(.headline)
                    Text("作った人：桃尻くびれちゃん").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("画面をすっきり使ってほしくて、広告は入れていません。App Store の登録料は毎年自費なので、応援してもらえると、続ける力と次のアップデートの力になります🍑")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("チップを送らなくても、すべての機能を使えます。")
                .font(.caption)
                .foregroundStyle(.secondary)
            // SNS のプロフィールだけにつなぐ（投げ銭などアプリの外での支払いには案内しない）
            Link(destination: URL(string: "https://www.instagram.com/momoshiri_kubire/")!) {
                Label("Instagram を見る　@momoshiri_kubire", systemImage: "camera.fill")
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color(red: 0.88, green: 0.19, blue: 0.47))
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
                        ToolbarTitle("応援", systemImage: "gift")
                    }
                }
            }
            .sheet(isPresented: $showTips) { TipJarView() }
    }
}

extension View {
    func tipButton() -> some View { modifier(TipButton()) }
}
