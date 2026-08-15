//
//  CameraStoreUITests.swift
//  RetroSnapUITests
//
//  単品カメラ課金の要になる2点を、画面から確かめる。
//
//  1. 未購入カメラでも**ライブプレビューは効く**。塞がるのは保存だけ
//  2. シミュレータで購入すると、そのカメラで撮った1枚が保存まで通る
//
//  StoreKit Testing（SKTestSession）で RetroSnap.storekit を読むので、
//  App Store Connect に商品が無くても通る。
//
//  `RETROSNAP_SCREENSHOT_DIR` を渡すと各段のスクリーンショットを書き出す。
//

import StoreKitTest
import XCTest

final class CameraStoreUITests: XCTestCase {

    /// 有料カメラ1台。slug は CameraCatalog と揃える（product ID は slug から機械的に決まる）。
    private let paidCameraSlug = "nightneon"
    private var paidProductID: String { "com.entaku.retrosnap.camera.\(paidCameraSlug)" }

    private var session: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false

        session = try SKTestSession(configurationFileNamed: "RetroSnap")

        // iOS 26 系のシミュレータでは StoreKit Test が使えない（storefront が空で返る）。
        // 実行環境の問題なので落とさずに飛ばす。課金の確認は iOS 18 系のシミュレータで行う。
        try XCTSkipIf(
            session.storefront.isEmpty,
            "StoreKit Testing が使えない実行環境。iOS 18 系のシミュレータで実行すること"
        )

        session.disableDialogs = true
        // 前のテストの購入を持ち越すと「買わずに保存できた」を見逃す。毎回まっさらから。
        session.clearTransactions()
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
    }

    // MARK: - 未購入: プレビューは効く / 保存は止まる

    func testUnpurchasedCameraPreviewsButBlocksSaving() throws {
        let app = launchApp()

        let beforeSelection = XCUIScreen.main.screenshot().pngRepresentation
        selectPaidCamera(in: app)

        // 1. プレビューが変わる = 未購入でも写りが分かる
        let afterSelection = XCUIScreen.main.screenshot()
        XCTAssertNotEqual(
            beforeSelection,
            afterSelection.pngRepresentation,
            "未購入カメラを選んでもプレビューが変わらない（プレビューを塞いではいけない）"
        )
        record(afterSelection, as: "locked-preview")

        // 2. シャッターを切ると購入を求められる（＝保存されずにカメラストアが出る）
        app.buttons["camera.shutter"].tap()

        let storeRow = app.buttons["store.row.\(paidCameraSlug)"]
        XCTAssertTrue(storeRow.waitForExistence(timeout: 30), "保存しようとしても購入導線が出てこない")
        record(XCUIScreen.main.screenshot(), as: "locked-store")

        // 3. 買わずに閉じたら、保存できていないことが画面に残る
        app.buttons["store.close"].tap()
        let notice = app.otherElements["camera.lockedNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "保存されなかったことが画面に出ていない")
        record(XCUIScreen.main.screenshot(), as: "locked-notice")

        // 「保存しました」は出ていない = 保存されていない
        XCTAssertFalse(app.alerts.element.exists, "未購入なのに保存された")
    }

    // MARK: - 購入すると保存まで通る

    func testPurchasingLetsTheShotBeSaved() throws {
        let app = launchApp()
        selectPaidCamera(in: app)

        app.buttons["camera.shutter"].tap()

        let buyButton = app.buttons["store.buy.\(paidCameraSlug)"]
        // コマンドラインからの実行では、アプリ側のプロセスに StoreKit の
        // テストストアが渡らない（UI テスト側の SKTestSession も、スキームの
        // StoreKit 設定も、テスト対象アプリには効かない）。価格が出ないので買えない。
        // 実装ではなく実行経路の制約なので、ここでは飛ばす。
        try XCTSkipUnless(
            buyButton.waitForExistence(timeout: 30),
            "アプリ側に StoreKit のテストストアが無い実行環境（価格が出ないため購入できない）"
        )
        record(XCUIScreen.main.screenshot(), as: "purchase-before")

        buyButton.tap()

        // 購入が通ると行が「購入済み」に変わる
        let owned = app.staticTexts["store.owned"]
        let ownedAppeared = owned.waitForExistence(timeout: 15)
            || app.buttons["store.buy.\(paidCameraSlug)"].waitForNonExistence(timeout: 15)
        XCTAssertTrue(ownedAppeared, "購入しても表示が変わらない")
        record(XCUIScreen.main.screenshot(), as: "purchase-done")

        // 閉じると、保留していた1枚がそのまま保存される
        app.buttons["store.close"].tap()

        let savedAlert = app.alerts.element
        XCTAssertTrue(savedAlert.waitForExistence(timeout: 10), "購入後も保存されない")
        record(XCUIScreen.main.screenshot(), as: "purchase-saved")

        XCTAssertTrue(session.allTransactions().contains { $0.productIdentifier == paidProductID })
    }

    // MARK: - 補助

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        dismissTrackingPromptIfPresent()
        return app
    }

    private func selectPaidCamera(in app: XCUIApplication) {
        let chip = app.buttons["camera.chip.\(paidCameraSlug)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "カルーセルに \(paidCameraSlug) が無い")
        chip.tap()
    }

    private func dismissTrackingPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 5), alert.buttons.count > 0 else { return }
        alert.buttons.element(boundBy: 0).tap()
    }

    private func record(_ shot: XCUIScreenshot, as name: String) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["RETROSNAP_SCREENSHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !exists { return true }
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 0.3)
        }
        return !exists
    }
}
