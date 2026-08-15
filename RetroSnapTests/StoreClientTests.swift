//
//  StoreClientTests.swift
//  RetroSnapTests
//
//  StoreKit Testing（SKTestSession）で実際に買って・復元して確かめる。
//  RetroSnap.storekit をそのまま使うので、ASC に商品が無くても通る。
//
//  ここで見るのは3点:
//  - 購入すると所有判定が変わり、保存時ゲートが通ること
//  - 所有は entitlements から作り直されること（＝アプリ内のフラグに依存していないこと）
//  - 復元で所有が戻ること
//

import StoreKit
import StoreKitTest
import XCTest
@testable import RetroSnap

@MainActor
final class StoreClientTests: XCTestCase {

    private var session: SKTestSession!

    private var paidCamera: CameraSpec { .nightNeon }
    private var otherPaidCamera: CameraSpec { .toyPlastic }

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "RetroSnap")

        // iOS 26 系のシミュレータでは StoreKit Test の XPC が繋がらず、
        // SKTestSession の全操作が SKInternalErrorDomain Code=3 で失敗する（storefront も空になる）。
        // 実装の問題ではなく実行環境の問題なので、落とさずに飛ばす。
        // 課金まわりを実際に確かめるときは iOS 18 系のシミュレータで実行すること。
        try XCTSkipIf(
            session.storefront.isEmpty,
            "StoreKit Testing が使えない実行環境。iOS 18 系のシミュレータで実行すること"
        )

        session.disableDialogs = true
        // 課金まわりのテストは前の購入を引きずると簡単に嘘をつくので、毎回まっさらから始める。
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
    }

    // MARK: - 商品

    func testLoadsAProductForEveryPaidCamera() async throws {
        let client = StoreClient(startsListening: false)
        await client.loadProducts()

        for spec in CameraCatalog.all.filter(\.isPurchasable) {
            XCTAssertNotNil(client.products[spec.productID], "\(spec.id.rawValue) の商品が取れない")
        }
        XCTAssertNil(client.productLoadFailure)
    }

    func testFreeCamerasHaveNoProduct() async throws {
        let client = StoreClient(startsListening: false)
        await client.loadProducts()

        for spec in CameraCatalog.all where !spec.isPurchasable {
            XCTAssertNil(client.products[spec.productID], "\(spec.id.rawValue) に商品が付いている")
        }
    }

    // MARK: - 所有判定

    func testNothingIsOwnedBeforeBuying() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()

        XCTAssertTrue(client.ownedProductIDs.isEmpty)
        XCTAssertFalse(client.isUnlocked(paidCamera))
        XCTAssertFalse(client.hasAnyPurchase)
        // 無料カメラは買わなくても使える
        XCTAssertTrue(client.isUnlocked(CameraCatalog.default))
    }

    func testPurchasingUnlocksThatCameraAndOnlyThatCamera() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()

        let outcome = await client.purchase(paidCamera)
        XCTAssertEqual(outcome, .purchased)

        XCTAssertTrue(client.isUnlocked(paidCamera))
        XCTAssertFalse(client.isUnlocked(otherPaidCamera), "買っていないカメラまで開いている")
    }

    func testPurchasingRemovesAds() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()
        XCTAssertFalse(client.hasAnyPurchase)

        _ = await client.purchase(paidCamera)

        // 1台でも買ったら広告は全消し
        XCTAssertTrue(client.hasAnyPurchase)
    }

    func testSaveGateOpensAfterPurchase() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()

        XCTAssertEqual(
            CaptureGate.disposition(for: paidCamera, entitlements: client),
            .requirePurchase(paidCamera.id)
        )

        _ = await client.purchase(paidCamera)

        XCTAssertEqual(CaptureGate.disposition(for: paidCamera, entitlements: client), .save)
    }

    func testBuyingTwiceIsNotAnError() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()

        _ = await client.purchase(paidCamera)
        // 既に持っているものを押しても失敗にしない（黙って無反応にもしない）
        let second = await client.purchase(paidCamera)
        XCTAssertEqual(second, .purchased)
    }

    func testFreeCameraPurchaseIsReportedAsFree() async throws {
        let client = StoreClient(startsListening: false)

        let outcome = await client.purchase(CameraCatalog.default)
        XCTAssertEqual(outcome, .free)
    }

    // MARK: - 所有はフラグではなく entitlements から来ている

    func testOwnershipComesFromEntitlementsNotFromAnyStoredFlag() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()
        _ = await client.purchase(paidCamera)
        XCTAssertTrue(client.isUnlocked(paidCamera))

        // 取引を消す＝払い戻し相当。アプリ内にフラグを持っていたらここで剥がれない。
        session.clearTransactions()
        await client.refreshEntitlements()

        XCTAssertFalse(client.isUnlocked(paidCamera), "購入フラグが残っている（entitlements を見ていない）")
        XCTAssertFalse(client.hasAnyPurchase)
    }

    func testANewClientSeesPurchasesMadeByAnother() async throws {
        let buyer = StoreClient(startsListening: false)
        await buyer.refresh()
        _ = await buyer.purchase(paidCamera)

        // 再起動相当。所有は毎回 entitlements から組み直される
        let fresh = StoreClient(startsListening: false)
        await fresh.refreshEntitlements()

        XCTAssertTrue(fresh.isUnlocked(paidCamera))
    }

    // MARK: - 復元

    func testRestoreBringsBackAPurchase() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()
        _ = await client.purchase(paidCamera)
        XCTAssertTrue(client.isUnlocked(paidCamera))

        let outcome = await client.restore()

        XCTAssertEqual(outcome, .restored(1))
        XCTAssertTrue(client.isUnlocked(paidCamera))
    }

    func testRestoreWithNothingBoughtSaysSoInsteadOfFailing() async throws {
        let client = StoreClient(startsListening: false)
        await client.refresh()

        // 「復元するものが無い」は失敗ではない。区別して伝える
        let outcome = await client.restore()
        XCTAssertEqual(outcome, .nothingToRestore)
    }
}
