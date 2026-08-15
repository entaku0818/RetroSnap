//
//  StoreClient.swift
//  RetroSnap
//
//  購入・所有判定・復元をまとめた唯一の入口。UI からは「このカメラは使えるか」
//  （`isUnlocked`）と「買う」「復元する」しか触らない。
//
//  ★設計の要点:
//   - 所有は必ず `Transaction.currentEntitlements` から作り直す。
//     **UserDefaults に購入フラグを持たない**（払い戻し・家族共有・復元でずれるため）。
//   - `Transaction.updates` を購読し続ける。別端末での購入や、アプリ外で完了した
//     保留中の購入も、アプリを再起動せずに反映される。
//   - 失敗は握り潰さない。すべての経路が `PurchaseOutcome` / `RestoreOutcome` を返し、
//     UI が必ず何かを表示できるようにしてある（黙って無反応が一番まずい）。
//   - product ID は `CameraSpec.productID` から導出する。文字列をここに書かない。
//

import Foundation
import StoreKit

// MARK: - 結果

/// 購入の結末。呼び出し側はこれを必ず画面に反映する。
enum PurchaseOutcome: Equatable {
    /// 購入できた（または既に所有していた）。
    case purchased
    /// もともと無料のカメラだった。
    case free
    /// ユーザーが自分でやめた。
    case cancelled
    /// 承認待ち（ファミリー共有の「承認と購入のリクエスト」など）。後から `Transaction.updates` で届く。
    case pending
    /// 商品情報が取れなかった（通信断 / ASC 未登録 / .storekit 未設定）。
    case unavailable
    /// それ以外の失敗。
    case failed(String)
}

/// 復元の結末。
enum RestoreOutcome: Equatable {
    /// 復元できた（件数は所有しているカメラの数）。
    case restored(Int)
    /// このアカウントに買ったものが無かった。「失敗」と区別して伝える。
    case nothingToRestore
    case failed(String)
}

// MARK: - StoreClient

@MainActor
final class StoreClient: ObservableObject, CameraEntitlements {

    static let shared = StoreClient()

    /// 所有している product ID。ここが唯一の所有の真実。
    @Published private(set) var ownedProductIDs: Set<String> = []

    /// 取得済みの商品。キーは product ID。
    @Published private(set) var products: [String: Product] = [:]

    /// 商品情報の取得中か。カメラストアのスピナー表示に使う。
    @Published private(set) var isLoadingProducts = false

    /// 購入処理中の product ID。二重タップの抑止とボタンの表示に使う。
    @Published private(set) var purchasingProductIDs: Set<String> = []

    /// 商品情報が取れなかったときの理由。取れていれば nil。
    @Published private(set) var productLoadFailure: String?

    private let catalog: [CameraSpec]
    private var updatesTask: Task<Void, Never>?

    init(catalog: [CameraSpec] = CameraCatalog.all, startsListening: Bool = true) {
        self.catalog = catalog
        guard startsListening else { return }
        updatesTask = makeUpdatesTask()
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - 読み込み

    /// 商品情報と所有状態をまとめて取り直す。起動時とカメラストアを開いたときに呼ぶ。
    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    /// 所有状態を entitlements から作り直す。
    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // 払い戻し済み・取り消し済みは所有に数えない。
            guard transaction.revocationDate == nil else { continue }
            owned.insert(transaction.productID)
        }
        ownedProductIDs = owned
    }

    /// カタログの有料カメラぶんの商品情報を取る。
    func loadProducts() async {
        let identifiers = catalog.filter(\.isPurchasable).map(\.productID)
        guard !identifiers.isEmpty else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: identifiers)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            // 1つも取れないのは通信断か、商品が未登録かのどちらか。UI に出すために残す。
            productLoadFailure = loaded.isEmpty ? String(localized: "store.error.productsUnavailable") : nil
        } catch {
            productLoadFailure = error.localizedDescription
        }
    }

    // MARK: - 購入

    /// カメラを1台買う。
    func purchase(_ spec: CameraSpec) async -> PurchaseOutcome {
        guard spec.isPurchasable else { return .free }
        guard !ownedProductIDs.contains(spec.productID) else { return .purchased }
        guard !purchasingProductIDs.contains(spec.productID) else { return .cancelled }

        // 通信断で商品を取れていないことがあるので、買う直前に一度だけ取り直す。
        if products[spec.productID] == nil {
            await loadProducts()
        }
        guard let product = products[spec.productID] else { return .unavailable }

        purchasingProductIDs.insert(spec.productID)
        defer { purchasingProductIDs.remove(spec.productID) }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return .purchased
                case .unverified(_, let error):
                    // 署名が検証できないものは所有に数えない。黙って通さない。
                    return .failed(error.localizedDescription)
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                // ここで終わりではない。承認されたら Transaction.updates 経由で所有に入る。
                return .pending
            @unknown default:
                return .failed(String(localized: "store.error.unknown"))
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - 復元

    /// 購入を復元する（App Review Guideline 3.1.1 で必須）。
    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return ownedProductIDs.isEmpty ? .nothingToRestore : .restored(ownedProductIDs.count)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - 監視

    /// 別端末での購入、保留中の購入の承認、払い戻しを取りこぼさないための購読。
    private func makeUpdatesTask() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }
}
