//
//  CameraEntitlements.swift
//  RetroSnap
//
//  「このカメラは使えるか」を決める部分だけを課金の実装から切り離したもの。
//
//  ★設計の要点:
//   - 所有の**判断**はここ（純粋な関数）。所有の**取得**は StoreClient（RevenueCat）。
//     分けてあるので、判断側は RevenueCat も StoreKit も無しでテストできる。
//   - 判断材料は「有効な entitlement の集合」だけ。UserDefaults の購入フラグは持たない
//     （フラグは復元・払い戻し・家族共有とずれるので、常に entitlement から作り直す）。
//   - UI からは `isUnlocked(_:)` と `hasAnyPurchase` しか呼ばない。
//

import Foundation

// MARK: - 有効な entitlement の供給元

protocol CameraEntitlements {
    /// 現時点で有効な entitlement 識別子（`CameraSpec.entitlementID` と同じ体系）。
    var activeEntitlementIDs: Set<String> { get }
}

extension CameraEntitlements {

    /// このカメラを使ってよいか。
    ///
    /// 無料カメラは常に true。有料カメラは entitlement が有効なときだけ true。
    /// - Important: これは**保存してよいか**の判定であって、プレビューの可否ではない。
    ///   未購入カメラでもライブプレビューは必ず効かせる（買う前に写りが分かることが
    ///   単品売りの肝なので、プレビューを塞いではいけない）。
    func isUnlocked(_ spec: CameraSpec) -> Bool {
        guard spec.isPurchasable else { return true }
        return activeEntitlementIDs.contains(spec.entitlementID)
    }

    /// 1台でも買っているか。広告を全消しにする条件。
    ///
    /// - Note: カタログに無い entitlement（他アプリ由来や廃止済み）は数えない。
    ///   「知らない entitlement が1つあるだけで広告が消える」状態を作らないため。
    func hasAnyPurchase(in catalog: [CameraSpec] = CameraCatalog.all) -> Bool {
        catalog.contains { $0.isPurchasable && activeEntitlementIDs.contains($0.entitlementID) }
    }

    /// まだ買っていない有料カメラ。
    func lockedCameras(in catalog: [CameraSpec] = CameraCatalog.all) -> [CameraSpec] {
        catalog.filter { !isUnlocked($0) }
    }
}

// MARK: - 撮影後の分岐

/// シャッターを切った1枚をどう扱うか。
///
/// 判定の位置に意味がある。プレビューでも撮影でもなく、**保存の直前**に効かせる。
/// - `.save`: そのまま保存する
/// - `.requirePurchase`: 保存はせず、現像結果を見せたうえで購入を求める
enum CaptureDisposition: Equatable {
    case save
    case requirePurchase(CameraID)
}

enum CaptureGate {

    /// 現像済みの1枚を保存してよいかを決める。
    static func disposition(for spec: CameraSpec, entitlements: CameraEntitlements) -> CaptureDisposition {
        entitlements.isUnlocked(spec) ? .save : .requirePurchase(spec.id)
    }
}

// MARK: - テスト・プレビュー用

/// 課金の実装を通さずに所有状態を作るための実装。
struct StaticCameraEntitlements: CameraEntitlements {
    var activeEntitlementIDs: Set<String>

    init(activeEntitlementIDs: Set<String> = []) {
        self.activeEntitlementIDs = activeEntitlementIDs
    }

    /// カメラを直接指定して所有状態を作る。
    init(owned specs: [CameraSpec]) {
        self.activeEntitlementIDs = Set(specs.filter(\.isPurchasable).map(\.entitlementID))
    }
}
