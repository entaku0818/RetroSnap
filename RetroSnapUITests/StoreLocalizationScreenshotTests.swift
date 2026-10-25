import XCTest

final class StoreLocalizationScreenshotTests: XCTestCase {
    func testCameraInSixLanguages() throws {
        continueAfterFailure = false
        let output = URL(fileURLWithPath: "/tmp/retrosnap-growth-screens")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for language in ["ja", "en", "ko", "de", "fr", "es"] {
            let app = XCUIApplication()
            let photo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fastlane/screenshots/source/photos/02_iced_coffee_cafe.jpg")
            try XCTSkipUnless(FileManager.default.fileExists(atPath: photo.path), "Local source photo required; see screenshot README")
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language, "-RetroSnapScreenshotPhoto", photo.path]
            app.launch()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 3) { alert.buttons.firstMatch.tap() }
            XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 15))
            app.buttons["camera.chip.sunsetfade"].tap()
            // Core Image publishes the new preview asynchronously after selection.
            Thread.sleep(forTimeInterval: 2)
            try app.screenshot().pngRepresentation.write(to: output.appendingPathComponent("\(language)-camera.png"))
            app.terminate()
        }
    }
}
