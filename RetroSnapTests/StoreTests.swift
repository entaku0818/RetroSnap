//
//  StoreTests.swift
//  RetroSnapTests
//
//  課金まわりのうち、**課金の実装（RevenueCat）を起動しなくても決まる部分**の保証。
//  - 所有判定（無料は常に使える / 有料は entitlement があるときだけ）
//  - 保存時ゲートの分岐（保存する / 購入を求める）
//  - 広告を全消しにする条件
//  - entitlement 識別子の規約（RevenueCat のダッシュボードに入れる文字列）
//  - .storekit の中身がカタログとずれていないこと
//
//  実際に買う・復元するところは、RevenueCat のサーバと API キーが要るため
//  ここでは見ない（キーが入ってからの実機 / Sandbox 確認に回す）。
//

import XCTest
@testable import RetroSnap

final class StoreTests: XCTestCase {

    private var freeCameras: [CameraSpec] { CameraCatalog.all.filter { !$0.isPurchasable } }
    private var paidCameras: [CameraSpec] { CameraCatalog.all.filter(\.isPurchasable) }

    override func setUpWithError() throws {
        // 前提が崩れるとこのファイルのテストが全部意味を失うので、先に確かめる
        XCTAssertFalse(freeCameras.isEmpty)
        XCTAssertFalse(paidCameras.isEmpty)
    }

    // MARK: - 所有判定

    func testFreeCamerasAreUsableWithoutAnyPurchase() {
        let entitlements = StaticCameraEntitlements()

        for spec in freeCameras {
            XCTAssertTrue(entitlements.isUnlocked(spec), "\(spec.id.rawValue) は無料なのに使えない")
        }
    }

    func testPaidCamerasAreLockedWithoutPurchase() {
        let entitlements = StaticCameraEntitlements()

        for spec in paidCameras {
            XCTAssertFalse(entitlements.isUnlocked(spec), "\(spec.id.rawValue) が買わずに使える")
        }
    }

    func testPurchasingOneCameraUnlocksOnlyThatCamera() throws {
        let bought = try XCTUnwrap(paidCameras.first)
        let entitlements = StaticCameraEntitlements(owned: [bought])

        XCTAssertTrue(entitlements.isUnlocked(bought))
        for other in paidCameras where other.id != bought.id {
            XCTAssertFalse(entitlements.isUnlocked(other), "\(other.id.rawValue) まで開いてしまっている")
        }
    }

    func testUnrelatedEntitlementDoesNotUnlockAnything() {
        // 他アプリや廃止済みの entitlement を持っていても開かないこと
        let entitlements = StaticCameraEntitlements(activeEntitlementIDs: ["camera_other", "unlock_all", "pro"])

        for spec in paidCameras {
            XCTAssertFalse(entitlements.isUnlocked(spec))
        }
    }

    func testLockedCamerasListsOnlyUnpurchasedPaidCameras() throws {
        let bought = try XCTUnwrap(paidCameras.first)
        let entitlements = StaticCameraEntitlements(owned: [bought])

        let locked = entitlements.lockedCameras()
        XCTAssertEqual(Set(locked.map(\.id)), Set(paidCameras.dropFirst().map(\.id)))
    }

    // MARK: - 保存時ゲート

    func testCaptureWithAFreeCameraIsSaved() throws {
        let spec = try XCTUnwrap(freeCameras.first)

        XCTAssertEqual(
            CaptureGate.disposition(for: spec, entitlements: StaticCameraEntitlements()),
            .save
        )
    }

    func testCaptureWithAnUnpurchasedCameraRequiresPurchase() throws {
        let spec = try XCTUnwrap(paidCameras.first)

        XCTAssertEqual(
            CaptureGate.disposition(for: spec, entitlements: StaticCameraEntitlements()),
            .requirePurchase(spec.id)
        )
    }

    func testCaptureWithAPurchasedCameraIsSaved() throws {
        let spec = try XCTUnwrap(paidCameras.first)

        XCTAssertEqual(
            CaptureGate.disposition(for: spec, entitlements: StaticCameraEntitlements(owned: [spec])),
            .save
        )
    }

    func testEveryCameraIsEitherSavableOrPurchasableNeverBlocked() {
        // 「撮ったのに何も起きない」カメラが1台も無いこと
        let entitlements = StaticCameraEntitlements()

        for spec in CameraCatalog.all {
            switch CaptureGate.disposition(for: spec, entitlements: entitlements) {
            case .save:
                XCTAssertFalse(spec.isPurchasable)
            case .requirePurchase(let id):
                XCTAssertEqual(id, spec.id)
                XCTAssertTrue(spec.isPurchasable)
            }
        }
    }

    // MARK: - 広告

    func testAdsStayUntilSomethingIsPurchased() {
        XCTAssertFalse(StaticCameraEntitlements().hasAnyPurchase())
    }

    func testBuyingASingleCameraRemovesAds() throws {
        let bought = try XCTUnwrap(paidCameras.first)

        XCTAssertTrue(StaticCameraEntitlements(owned: [bought]).hasAnyPurchase())
    }

    // MARK: - .storekit とカタログの一致

    /// StoreKit Configuration の中身がカタログとずれると、シミュレータでは買えるのに
    /// 実機で買えない（あるいはその逆）という一番気づきにくい壊れ方をする。
    func testStoreKitConfigurationMatchesTheCatalog() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "RetroSnap", withExtension: "storekit"),
            "RetroSnap.storekit がテストバンドルに入っていない"
        )
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try XCTUnwrap(json as? [String: Any])
        let products = try XCTUnwrap(root["products"] as? [[String: Any]])

        let configured = Set(products.compactMap { $0["productID"] as? String })
        let expected = Set(paidCameras.map(\.productID))
        XCTAssertEqual(configured, expected, "カタログの有料カメラと .storekit の商品がずれている")

        // 種別は全部「非消耗型」。サブスクではない
        for product in products {
            XCTAssertEqual(product["type"] as? String, "NonConsumable", "\(product["productID"] ?? "?")")
        }

        // 無料カメラは登録しない（登録すると無料のものに値段が付く）
        for spec in freeCameras {
            XCTAssertFalse(configured.contains(spec.productID), "\(spec.id.rawValue) は無料なのに登録されている")
        }
    }

    func testStoreKitConfigurationUsesTheDecidedPrices() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "RetroSnap", withExtension: "storekit"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let products = try XCTUnwrap((json as? [String: Any])?["products"] as? [[String: Any]])

        var prices: [String: String] = [:]
        for product in products {
            guard let id = product["productID"] as? String,
                  let price = product["displayPrice"] as? String else { continue }
            prices[id] = price
        }

        // 決定事項: nightneon / toyplastic = 300、datestamp98 = 500
        XCTAssertEqual(prices[CameraSpec.nightNeon.productID], "300")
        XCTAssertEqual(prices[CameraSpec.toyPlastic.productID], "300")
        XCTAssertEqual(prices[CameraSpec.dateStamp98.productID], "500")
    }

    // MARK: - entitlement 識別子の規約

    func testEntitlementIDsAreDerivedFromSlug() {
        for spec in CameraCatalog.all {
            XCTAssertEqual(spec.entitlementID, "camera_" + spec.id.rawValue)
        }
    }

    func testEntitlementIDsAreUnique() {
        let ids = CameraCatalog.all.map(\.entitlementID)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEntitlementIDsUseLowercaseAlphanumericsAndUnderscore() {
        // RevenueCat のダッシュボードに入れる文字列。表記を機械で固定しておく
        for spec in CameraCatalog.all {
            XCTAssertNotNil(
                spec.entitlementID.range(of: "^[a-z0-9_]+$", options: .regularExpression),
                "\(spec.entitlementID) に使えない文字が入っている"
            )
        }
    }

    func testUnknownEntitlementDoesNotRemoveAds() {
        // カタログに無い entitlement が1つあるだけで広告が消える、という事故を防ぐ
        let entitlements = StaticCameraEntitlements(activeEntitlementIDs: ["camera_retired", "pro"])

        XCTAssertFalse(entitlements.hasAnyPurchase())
    }
}
