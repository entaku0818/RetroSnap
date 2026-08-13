//
//  FilmRendererTests.swift
//  RetroSnapTests
//
//  現像エンジンとカタログの最低限の保証。
//  - カタログの全カメラがレンダリングを完走すること
//  - 同じ入力 + 同じ CameraSpec なら出力が決定的であること
//  - slug / product ID の規約（診断レポート §8-1）が守られていること
//

import XCTest
import UIKit
@testable import RetroSnap

final class FilmRendererTests: XCTestCase {

    /// 日付焼き込みを含む現像を決定的にするための固定日時。
    private let fixedDate = Date(timeIntervalSince1970: 902_000_000)

    private var renderer: FilmRenderer!

    override func setUpWithError() throws {
        renderer = FilmRenderer()
    }

    override func tearDownWithError() throws {
        renderer = nil
    }

    // MARK: - テスト用の入力画像

    /// 現像の各段が効いていることを確認できるだけの情報量を持つ入力を作る。
    /// - 白飛び気味の明部（ハレーション用）
    /// - 中間調のグラデーション（色被り・粒子用）
    /// - 暗部（ビネット用）
    private func makeTestImage(
        size: CGSize = CGSize(width: 120, height: 160),
        orientation: UIImage.Orientation = .up
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let base = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.25, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height / 2))

            // ハイライト。ハレーションのしきい値を超えさせる
            UIColor(white: 0.98, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.6, y: size.height * 0.1,
                                width: size.width * 0.3, height: size.height * 0.2))

            UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.1, y: size.height * 0.6,
                                width: size.width * 0.5, height: size.height * 0.25))
        }

        guard orientation != .up, let cgImage = base.cgImage else { return base }
        return UIImage(cgImage: cgImage, scale: base.scale, orientation: orientation)
    }

    private func pixelData(_ image: UIImage) throws -> Data {
        let data = try XCTUnwrap(image.pngData(), "PNG に書き出せること")
        return data
    }

    // MARK: - 全カメラがレンダリングを完走する

    func testAllCamerasRenderSuccessfully() throws {
        let input = makeTestImage()

        for spec in CameraCatalog.all {
            let output = renderer.render(input, with: spec, capturedAt: fixedDate)
            let rendered = try XCTUnwrap(output, "\(spec.id.rawValue) の現像が nil を返した")

            XCTAssertEqual(rendered.size, input.size,
                           "\(spec.id.rawValue): 現像の前後でサイズが変わっている")
            XCTAssertEqual(rendered.imageOrientation, .up,
                           "\(spec.id.rawValue): 出力は向きが正規化されているべき")
            XCTAssertNotNil(rendered.cgImage,
                            "\(spec.id.rawValue): CGImage を持たない")
        }
    }

    func testCatalogCoversTheFiveLaunchCameras() {
        let slugs = CameraCatalog.all.map(\.id.rawValue)
        XCTAssertEqual(slugs, ["plain70", "sunsetfade", "nightneon", "toyplastic", "datestamp98"])
    }

    // MARK: - 決定性

    func testRenderIsDeterministicForSameInputAndSpec() throws {
        let input = makeTestImage()

        for spec in CameraCatalog.all {
            let first = try XCTUnwrap(renderer.render(input, with: spec, capturedAt: fixedDate))
            let second = try XCTUnwrap(renderer.render(input, with: spec, capturedAt: fixedDate))

            XCTAssertEqual(try pixelData(first), try pixelData(second),
                           "\(spec.id.rawValue): 同じ入力・同じ CameraSpec なのに出力が一致しない")
        }
    }

    func testDifferentCamerasProduceDifferentImages() throws {
        let input = makeTestImage()

        // 「カメラごとに写りが違う」がこのアプリの売りそのものなので、
        // 2台が同じ絵を吐いていたらカタログの設定ミスとして落とす
        var seen: [String: Data] = [:]
        for spec in CameraCatalog.all {
            let rendered = try XCTUnwrap(renderer.render(input, with: spec, capturedAt: fixedDate))
            let data = try pixelData(rendered)

            for (otherSlug, otherData) in seen {
                XCTAssertNotEqual(data, otherData,
                                  "\(spec.id.rawValue) と \(otherSlug) の現像結果が同一になっている")
            }
            seen[spec.id.rawValue] = data
        }
    }

    func testRenderChangesTheImage() throws {
        let input = makeTestImage()
        let rendered = try XCTUnwrap(renderer.render(input, with: .plain70, capturedAt: fixedDate))

        XCTAssertNotEqual(try pixelData(rendered), try pixelData(input),
                          "現像しても入力と同じ絵のままになっている")
    }

    // MARK: - 向きの正規化（診断レポート §11-#2）

    func testRenderNormalizesOrientation() throws {
        let portrait = makeTestImage(orientation: .up)
        // .right が付いた画像は「ピクセルは横倒し、表示は縦」の状態。
        // 正規化されていれば、出力は幅と高さが入れ替わる
        let rotated = makeTestImage(orientation: .right)

        let renderedPortrait = try XCTUnwrap(renderer.render(portrait, with: .plain70, capturedAt: fixedDate))
        let renderedRotated = try XCTUnwrap(renderer.render(rotated, with: .plain70, capturedAt: fixedDate))

        XCTAssertEqual(renderedPortrait.imageOrientation, .up)
        XCTAssertEqual(renderedRotated.imageOrientation, .up)
        XCTAssertEqual(renderedRotated.size,
                       CGSize(width: renderedPortrait.size.height, height: renderedPortrait.size.width),
                       "imageOrientation が実ピクセルに焼き込まれていない")
    }

    // MARK: - 非同期版

    func testAsyncRenderReturnsOnMainThread() throws {
        let input = makeTestImage()
        let expectation = expectation(description: "現像が完了する")

        renderer.render(input, with: .sunsetFade, capturedAt: fixedDate) { rendered in
            XCTAssertTrue(Thread.isMainThread, "完了ハンドラはメインスレッドで呼ばれるべき")
            XCTAssertNotNil(rendered)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    // MARK: - 効果ごとのステージが実際に効いているか

    func testEachEffectStageChangesTheOutput() throws {
        let input = makeTestImage()

        // 素通しの CameraSpec に効果を1つだけ足し、出力が変わることを確かめる。
        // ステージの配線ミス（パラメータを読んでいない等）はここで落ちる
        let neutral = CameraSpec(
            id: CameraID("testneutral"),
            displayNameKey: "",
            taglineKey: "",
            tier: .free
        )
        let baseline = try pixelData(try XCTUnwrap(renderer.render(input, with: neutral, capturedAt: fixedDate)))

        var withEffect: [String: CameraSpec] = [:]
        withEffect["tone"] = {
            var spec = neutral
            spec.tone.saturation = 0.4
            return spec
        }()
        withEffect["grain"] = {
            var spec = neutral
            spec.grain = GrainParams(intensity: 0.5, size: 1.5)
            return spec
        }()
        withEffect["vignette"] = {
            var spec = neutral
            spec.vignette = VignetteParams(intensity: 1.0, radius: 0.7, falloff: 0.5)
            return spec
        }()
        withEffect["halation"] = {
            var spec = neutral
            spec.halation = HalationParams(threshold: 0.5, radius: 0.03, intensity: 0.8)
            return spec
        }()
        withEffect["lightLeak"] = {
            var spec = neutral
            spec.lightLeak = LightLeakParams(
                center: CGPoint(x: 0.9, y: 0.9),
                color: RGB(red: 1, green: 0.5, blue: 0.2),
                opacity: 0.6
            )
            return spec
        }()
        withEffect["distortion"] = {
            var spec = neutral
            spec.distortion = DistortionParams(amount: 0.5)
            return spec
        }()
        withEffect["dateStamp"] = {
            var spec = neutral
            spec.dateStamp = DateStampParams(dateFormat: "yy M d")
            return spec
        }()
        withEffect["frame"] = {
            var spec = neutral
            spec.frame = FrameStyle(widthFraction: 0.06, color: RGB(red: 1, green: 1, blue: 1))
            return spec
        }()

        for (name, spec) in withEffect {
            let rendered = try XCTUnwrap(renderer.render(input, with: spec, capturedAt: fixedDate))
            XCTAssertNotEqual(try pixelData(rendered), baseline,
                              "\(name) を有効にしても出力が変わっていない")
        }
    }

    func testDateStampDependsOnCaptureDate() throws {
        let input = makeTestImage()
        let laterDate = fixedDate.addingTimeInterval(60 * 60 * 24 * 40)

        let first = try pixelData(try XCTUnwrap(renderer.render(input, with: .dateStamp98, capturedAt: fixedDate)))
        let second = try pixelData(try XCTUnwrap(renderer.render(input, with: .dateStamp98, capturedAt: laterDate)))

        XCTAssertNotEqual(first, second, "撮影日を変えても焼き込まれる日付が変わっていない")
    }

    // MARK: - 目視確認用

    /// 5台それぞれの現像結果を xcresult の添付として書き出す。
    /// `xcrun xcresulttool export attachments` で取り出して並べれば、
    /// カタログをいじったときの絵の変化をそのまま目で確認できる。
    func testRendersSampleSheetForVisualReview() throws {
        let scene = makeSampleScene()

        func attach(_ image: UIImage, _ name: String) {
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        attach(scene, "00-original")
        for spec in CameraCatalog.all {
            attach(try XCTUnwrap(renderer.render(scene, with: spec, capturedAt: fixedDate)),
                   spec.id.rawValue)
        }
    }

    /// 各効果の効きが目で分かる程度の情報量を持つ疑似風景。
    /// ハイライト（太陽）・空・地面・中間色の面・暗部のシルエットを含む。
    private func makeSampleScene(size: CGSize = CGSize(width: 360, height: 480)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.55, green: 0.72, blue: 0.9, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.55))

            UIColor(white: 1.0, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 250, y: 40, width: 70, height: 70))

            UIColor(red: 0.35, green: 0.42, blue: 0.24, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: size.height * 0.55, width: size.width, height: size.height * 0.45))

            UIColor(red: 0.78, green: 0.5, blue: 0.42, alpha: 1).setFill()
            context.fill(CGRect(x: 40, y: 180, width: 110, height: 130))
            UIColor(red: 0.25, green: 0.26, blue: 0.3, alpha: 1).setFill()
            context.fill(CGRect(x: 60, y: 210, width: 30, height: 40))
            context.fill(CGRect(x: 105, y: 210, width: 30, height: 40))

            UIColor(red: 0.12, green: 0.1, blue: 0.14, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 230, y: 300, width: 40, height: 40))
            context.fill(CGRect(x: 232, y: 340, width: 36, height: 90))
        }
    }

    // MARK: - 小さい画像でも落ちない

    func testRenderHandlesTinyImage() throws {
        let tiny = makeTestImage(size: CGSize(width: 4, height: 4))

        for spec in CameraCatalog.all {
            XCTAssertNotNil(renderer.render(tiny, with: spec, capturedAt: fixedDate),
                            "\(spec.id.rawValue): 極小画像で現像が失敗した")
        }
    }
}

// MARK: - カタログの規約

final class CameraCatalogTests: XCTestCase {

    /// slug は product ID の一部になり、**作成後に変更できない**。
    /// 表記揺れが入り込む前に機械的に止める（診断レポート §8-1）。
    func testSlugsUseLowercaseAlphanumericsOnly() {
        for spec in CameraCatalog.all {
            let slug = spec.id.rawValue
            XCTAssertFalse(slug.isEmpty, "slug が空")
            XCTAssertNil(slug.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted),
                         "\(slug): 英数字以外が入っている")
            XCTAssertEqual(slug, slug.lowercased(), "\(slug): 小文字にする")
        }
    }

    func testSlugsAreUnique() {
        let slugs = CameraCatalog.all.map(\.id.rawValue)
        XCTAssertEqual(Set(slugs).count, slugs.count, "slug が重複している")
    }

    func testProductIDsAreDerivedFromSlugAndNamespaced() {
        for spec in CameraCatalog.all {
            XCTAssertEqual(spec.productID, "com.entaku.retrosnap.camera.\(spec.id.rawValue)")
            XCTAssertTrue(spec.productID.hasPrefix("com.entaku.retrosnap."),
                          "他アプリと衝突しないよう bundle ID 由来の接頭辞から始める")
        }
    }

    func testProductIDsAreUnique() {
        let ids = CameraCatalog.all.map(\.productID)
        XCTAssertEqual(Set(ids).count, ids.count, "product ID が重複している")
    }

    /// 無料カメラは ASC に登録しない。課金対象の判定がカタログから導けることを保証する。
    func testFreeCamerasAreNotPurchasable() {
        for spec in CameraCatalog.all {
            XCTAssertEqual(spec.isPurchasable, spec.tier != .free, "\(spec.id.rawValue)")
        }
    }

    /// 立ち上げ期の配分（診断レポート §8-3）。無料が2台無いと
    /// 「カメラごとに写りが違う」ことが初回起動で体感できない。
    func testAtLeastTwoFreeCameras() {
        let freeCount = CameraCatalog.all.filter { $0.tier == .free }.count
        XCTAssertGreaterThanOrEqual(freeCount, 2)
    }

    func testDefaultCameraIsFreeAndInCatalog() {
        XCTAssertEqual(CameraCatalog.default.tier, .free)
        XCTAssertTrue(CameraCatalog.all.contains(CameraCatalog.default))
    }

    func testLookupBySlugFallsBackToDefault() {
        XCTAssertEqual(CameraCatalog.camera(forSlug: "nightneon"), .nightNeon)
        // カメラを廃止しても、そのカメラで撮った既存データが読めなくならないこと
        XCTAssertEqual(CameraCatalog.camera(forSlug: "retiredcamera"), CameraCatalog.default)
        XCTAssertEqual(CameraCatalog.camera(forSlug: nil), CameraCatalog.default)
    }

    func testEveryCameraHasLocalizationKeys() {
        for spec in CameraCatalog.all {
            XCTAssertFalse(spec.displayNameKey.isEmpty, "\(spec.id.rawValue): displayNameKey が空")
            XCTAssertFalse(spec.taglineKey.isEmpty, "\(spec.id.rawValue): taglineKey が空")
        }
    }
}
