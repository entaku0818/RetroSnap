//
//  StoreClient.swift
//  RetroSnap
//
//  購入・所有判定・復元をまとめた唯一の入口。中身は RevenueCat。
//  UI からは「このカメラは使えるか」（`isUnlocked`）と「買う」「復元する」しか触らない。
//
//  ★設計の要点:
//   - 所有は必ず RevenueCat の `CustomerInfo.entitlements` から作り直す。
//     **UserDefaults に購入フラグを持たない**（払い戻し・家族共有・復元でずれるため）。
//   - `customerInfoStream` を購読し続ける。別端末での購入や、アプリ外で完了した
//     保留中の購入も、アプリを再起動せずに反映される。
//   - 失敗は握り潰さない。すべての経路が `PurchaseOutcome` / `RestoreOutcome` を返し、
//     UI が必ず何かを表示できるようにしてある（黙って無反応が一番まずい）。
//   - product ID / entitlement ID は `CameraSpec` から導出する。文字列をここに書かない。
//   - **API キーが未設定でもクラッシュさせない。** 未設定なら課金は「使えない」状態に留め、
//     理由を UI に出す。無料カメラは今までどおり使える。
//

import Foundation
import RevenueCat

// MARK: - 結果

/// 購入の結末。呼び出し側はこれを必ず画面に反映する。
enum PurchaseOutcome: Equatable {
    /// 購入できた（または既に所有していた）。
    case purchased
    /// もともと無料のカメラだった。
    case free
    /// ユーザーが自分でやめた。
    case cancelled
    /// 承認待ち（ファミリー共有の「承認と購入のリクエスト」など）。後から反映される。
    case pending
    /// 商品情報が取れなかった（通信断 / RevenueCat 未設定 / 商品未登録）。
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

    /// 有効な entitlement。ここが唯一の所有の真実。
    @Published private(set) var activeEntitlementIDs: Set<String> = []

    /// 取得済みの商品。キーは product ID。
    @Published private(set) var packages: [String: Package] = [:]

    /// 商品情報の取得中か。カメラストアのスピナー表示に使う。
    @Published private(set) var isLoadingProducts = false

    /// 購入処理中の product ID。二重タップの抑止とボタンの表示に使う。
    @Published private(set) var purchasingProductIDs: Set<String> = []

    /// 商品情報が取れなかったときの理由。取れていれば nil。
    @Published private(set) var productLoadFailure: String?

    private let catalog: [CameraSpec]
    private var customerInfoTask: Task<Void, Never>?

    init(catalog: [CameraSpec] = CameraCatalog.all, startsListening: Bool = true) {
        self.catalog = catalog
        guard startsListening, StoreConfiguration.isConfigured else { return }

        customerInfoTask = makeCustomerInfoTask()
        Task { await refresh() }
    }

    deinit {
        customerInfoTask?.cancel()
    }

    // MARK: - 読み込み

    /// 商品情報と所有状態をまとめて取り直す。起動時とカメラストアを開いたときに呼ぶ。
    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    /// 所有状態を entitlement から作り直す。
    func refreshEntitlements() async {
        guard StoreConfiguration.isConfigured else { return }

        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            // 取れなかったときに所有を空にしてはいけない。
            // 通信断で「買ったのに使えない」が起きるより、直前の状態を保つほうが害が小さい。
            print("所有状態を取得できなかった: \(error)")
        }
    }

    /// カタログの有料カメラぶんの商品情報を取る。
    func loadProducts() async {
        let identifiers = catalog.filter(\.isPurchasable).map(\.productID)
        guard !identifiers.isEmpty else { return }

        guard StoreConfiguration.isConfigured else {
            productLoadFailure = String(localized: "store.error.notConfigured")
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            // Offering の構成に依存しないよう、全 offering の package を product ID で引けるようにする。
            // ダッシュボードで offering をどう組んでも、カタログ側の product ID で解決できる。
            var found: [String: Package] = [:]
            for offering in offerings.all.values {
                for package in offering.availablePackages {
                    found[package.storeProduct.productIdentifier] = package
                }
            }
            packages = found

            let missing = identifiers.filter { found[$0] == nil }
            productLoadFailure = missing.isEmpty
                ? nil
                : String(localized: "store.error.productsUnavailable")
        } catch {
            productLoadFailure = error.localizedDescription
        }
    }

    // MARK: - 購入

    /// カメラを1台買う。
    func purchase(_ spec: CameraSpec) async -> PurchaseOutcome {
        guard spec.isPurchasable else { return .free }
        guard !activeEntitlementIDs.contains(spec.entitlementID) else { return .purchased }
        guard !purchasingProductIDs.contains(spec.productID) else { return .cancelled }
        guard StoreConfiguration.isConfigured else { return .unavailable }

        // 通信断で商品を取れていないことがあるので、買う直前に一度だけ取り直す。
        if packages[spec.productID] == nil {
            await loadProducts()
        }
        guard let package = packages[spec.productID] else { return .unavailable }

        purchasingProductIDs.insert(spec.productID)
        defer { purchasingProductIDs.remove(spec.productID) }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }

            apply(result.customerInfo)
            // 課金は通ったのに entitlement が付いてこない場合は、ダッシュボードの
            // 商品と entitlement の紐づけが漏れている。黙って成功にしない。
            guard activeEntitlementIDs.contains(spec.entitlementID) else {
                return .failed(String(localized: "store.error.entitlementMissing"))
            }
            return .purchased
        } catch {
            return classify(error)
        }
    }

    // MARK: - 復元

    /// 購入を復元する（App Review Guideline 3.1.1 で必須）。
    func restore() async -> RestoreOutcome {
        guard StoreConfiguration.isConfigured else {
            return .failed(String(localized: "store.error.notConfigured"))
        }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            let count = catalog.filter { $0.isPurchasable && activeEntitlementIDs.contains($0.entitlementID) }.count
            return count == 0 ? .nothingToRestore : .restored(count)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - 反映

    /// `CustomerInfo` から所有状態を作り直す。所有を触るのはここだけ。
    private func apply(_ info: CustomerInfo) {
        activeEntitlementIDs = Set(info.entitlements.active.keys)
    }

    /// RevenueCat のエラーを、UI が出せる結末に落とす。
    private func classify(_ error: Error) -> PurchaseOutcome {
        guard let rcError = error as? RevenueCat.ErrorCode else {
            return .failed(error.localizedDescription)
        }

        switch rcError {
        case .purchaseCancelledError:
            return .cancelled
        case .paymentPendingError:
            // ここで終わりではない。承認されたら customerInfoStream 経由で所有に入る。
            return .pending
        case .productNotAvailableForPurchaseError, .productAlreadyPurchasedError:
            // 「既に買っている」は失敗ではない。所有を取り直して判断させる。
            return .unavailable
        default:
            return .failed(rcError.localizedDescription)
        }
    }

    // MARK: - 監視

    /// 別端末での購入、保留中の購入の承認、払い戻しを取りこぼさないための購読。
    private func makeCustomerInfoTask() -> Task<Void, Never> {
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }
}
