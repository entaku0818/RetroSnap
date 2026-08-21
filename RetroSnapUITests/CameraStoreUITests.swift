//
//  CameraStoreUITests.swift
//  RetroSnapUITests
//
//  単品カメラ課金の要になる2点を、画面から確かめる。
//
//  1. 未購入カメラでも**ライブプレビューは効く**。塞がるのは保存だけ
//  2. シミュレータで購入すると、そのカメラで撮った1枚が保存まで通る
//
//  課金の中身は RevenueCat なので、価格が出るかどうかは API キーと
//  ダッシュボードの設定に依存する。1 はキー無しでも確かめられる（ゲートはアプリ内の判断）。
//  2 は価格が出ない環境では飛ばす。
//
//  `RETROSNAP_SCREENSHOT_DIR` を渡すと各段のスクリーンショットを書き出す。
//

import XCTest

final class CameraStoreUITests: XCTestCase {

    /// 有料カメラ1台。slug は CameraCatalog と揃える（product ID は slug から機械的に決まる）。
    private let paidCameraSlug = "nightneon"

    override func setUpWithError() throws {
        continueAfterFailure = false
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

        // 型で引かないこと。価格が出ない環境では行の中の Button が消え、
        // 行の要素型が Button から変わるため `app.buttons[...]` では当たらない。
        let storeRow = element("store.row.\(paidCameraSlug)", in: app)
        XCTAssertTrue(storeRow.waitForExistence(timeout: 30), "保存しようとしても購入導線が出てこない")
        record(XCUIScreen.main.screenshot(), as: "locked-store")

        // 3. 買わずに閉じたら、保存できていないことが画面に残る
        app.buttons["store.close"].tap()
        let notice = element("camera.lockedNotice", in: app)
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
        // RevenueCat の API キーが未設定、または商品が未登録だと価格が出ない。
        // 実装ではなく設定の問題なので、ここでは飛ばす。
        try XCTSkipUnless(
            buyButton.waitForExistence(timeout: 30),
            "価格が出ない環境（RevenueCat の API キー未設定、または商品未登録）"
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

        // 保存されなかったときの掲示が消えていること（＝保存に進んだ）
        XCTAssertFalse(element("camera.lockedNotice", in: app).exists)
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

    /// 識別子だけで引く。要素の型は画面の状態で変わるので当てにしない。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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
