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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.banker.opacity(0.8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ひとりで作っています").font(.headline)
                    Text("作った人：桃尻くびれちゃん").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("はじめまして、バカラノートを作っている桃尻くびれちゃんです。ふだんは筋トレの発信をしながら、ひとりでアプリを作っています。もともとは、自分がテーブルで使いたくて作りました。")
            Text("App Store に出すための年間の登録料やテスト用の端末は、ぜんぶ自費です。画面をすっきり使ってほしいので、広告は入れていません。気に入ってもらえたら、応援してもらえるとすごくうれしいです。")
            Text("チップを送らなくても、すべての機能を使えます。チップを送っても機能は変わりません。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
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
