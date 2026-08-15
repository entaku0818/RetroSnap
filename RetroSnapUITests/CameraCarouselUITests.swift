//
//  CameraCarouselUITests.swift
//  RetroSnapUITests
//
//  カメラ切替カルーセルが**ライブプレビューに効いている**ことを画面から確かめる。
//  現像そのものは FilmRendererTests が見ているので、ここが見るのは配線:
//  「チップを押した ＝ その場でプレビューの絵が変わった」。
//
//  - チップの識別子は `camera.chip.<slug>`。カタログの slug がそのまま出るので、
//    カメラを足しても このファイルに名前を書き足す必要はない。
//  - `RETROSNAP_SCREENSHOT_DIR` を渡すと、カメラごとのスクリーンショットを書き出す
//    （リリース用ではなく、切替の効きを目視で確認するため）。
//

import XCTest

final class CameraCarouselUITests: XCTestCase {

    private let chipPrefix = "camera.chip."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTappingACameraChangesTheLivePreviewImmediately() throws {
        let app = XCUIApplication()
        app.launch()
        dismissTrackingPromptIfPresent()

        let chips = cameraChips(in: app)
        XCTAssertGreaterThanOrEqual(chips.count, 2, "カルーセルにカメラが並んでいない")

        let screenshotDirectory = ProcessInfo.processInfo.environment["RETROSNAP_SCREENSHOT_DIR"]
        var previous: Data?

        for chip in chips {
            chip.tap()
            // 選択の反映は次の映像フレームを待たない設計なので、待つのは描画1回分で足りる。
            _ = chip.waitForExistence(timeout: 2)

            let slug = chip.identifier.replacingOccurrences(of: chipPrefix, with: "")
            let shot = XCUIScreen.main.screenshot()

            add(attachment(named: slug, shot: shot))
            if let screenshotDirectory {
                let url = URL(fileURLWithPath: screenshotDirectory)
                    .appendingPathComponent("camera-\(slug).png")
                try shot.pngRepresentation.write(to: url)
            }

            // 直前のカメラと同じ絵なら、選択がプレビューに届いていない
            if let previous {
                XCTAssertNotEqual(previous, shot.pngRepresentation, "\(slug): プレビューが変わらない")
            }
            previous = shot.pngRepresentation
        }
    }

    // MARK: - 補助

    private func cameraChips(in app: XCUIApplication) -> [XCUIElement] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", chipPrefix)
        let query = app.buttons.matching(predicate)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 10), "カルーセルが出てこない")
        return query.allElementsBoundByIndex
    }

    /// 起動直後に出る ATT のダイアログを閉じる。既に答え済みなら何もしない。
    private func dismissTrackingPromptIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 5) else { return }

        // 「許可」ではない方（＝トラッキングを許可しない）を押す。文言はロケールで変わるので位置で選ぶ。
        let buttons = alert.buttons
        guard buttons.count > 0 else { return }
        buttons.element(boundBy: 0).tap()
    }

    private func attachment(named name: String, shot: XCUIScreenshot) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}
