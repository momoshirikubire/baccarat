import StoreKit
import SwiftUI

/// 応援（チップ）。消耗型のアプリ内課金で、買っても機能は変わらない。
/// 商品は App Store Connect で同じ ID のまま「消耗型」として作る。
@MainActor
@Observable
final class TipStore {
    static let productIDs = [
        "com.tadahonami.keisen.tip.small",
        "com.tadahonami.keisen.tip.medium",
        "com.tadahonami.keisen.tip.large",
        "com.tadahonami.keisen.tip.huge",
    ]

    enum Phase: Equatable {
        case idle
        case purchasing(String)
        case thanks
        case failed(String)
    }

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    var phase: Phase = .idle

    var isPurchasing: Bool {
        if case .purchasing = phase { return true }
        return false
    }

    /// これまでに応援してくれた回数（この端末だけ）
    private(set) var tipCount = UserDefaults.standard.integer(forKey: "tipCount")

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        // ほかの端末や中断した購入の取引も、届いたら完了にしておく
        updates = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }

    func load() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
        }
    }

    func buy(_ product: Product) async {
        phase = .purchasing(product.id)
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                tipCount += 1
                UserDefaults.standard.set(tipCount, forKey: "tipCount")
                phase = .thanks
            case .success(.unverified):
                phase = .failed("購入を確認できませんでした。時間をおいてもう一度お試しください。")
            case .userCancelled, .pending:
                phase = .idle
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed("購入できませんでした。通信状態を確かめてもう一度お試しください。")
        }
    }
}
