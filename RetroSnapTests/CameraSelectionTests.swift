//
//  CameraSelectionTests.swift
//  RetroSnapTests
//
//  カメラ切替カルーセルの土台になる選択状態の保証。
//  - ラインナップが CameraCatalog 由来であること（UI 側にカメラを書き足させない）
//  - 選択が壊れた状態にならないこと
//

import CoreImage
import UIKit
import XCTest
@testable import RetroSnap

final class CameraSelectionTests: XCTestCase {

    func testDefaultLineupComesFromTheCatalog() {
        let selection = CameraSelection()

        // UI に台数・並び順を持たせない。カタログの並びがそのままカルーセルの並びになる
        XCTAssertEqual(selection.cameras, CameraCatalog.all)
        XCTAssertEqual(selection.selected, CameraCatalog.default)
    }

    func testSelectionChangesToAnyCameraInTheLineup() {
        let selection = CameraSelection()

        for spec in CameraCatalog.all {
            selection.selected = spec
            XCTAssertEqual(selection.selected.id, spec.id)
        }
    }

    func testSelectedCameraOutsideTheLineupFallsBack() {
        // カタログから外したカメラを選択状態で渡されても、切替不能にならないこと
        let lineup = Array(CameraCatalog.all.dropFirst())
        let selection = CameraSelection(cameras: lineup, selected: CameraCatalog.all[0])

        XCTAssertEqual(selection.selected, lineup.first)
    }

    func testSelectedCameraInsideTheLineupIsKept() {
        let selection = CameraSelection(cameras: CameraCatalog.all, selected: .nightNeon)

        XCTAssertEqual(selection.selected, .nightNeon)
    }

    func testEverySelectableCameraIsRenderable() throws {
        // カルーセルに出る = ライブプレビューでも撮影でも現像を通る、ということ
        let renderer = FilmRenderer()
        let selection = CameraSelection()
        let source = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        for spec in selection.cameras {
            XCTAssertNotNil(renderer.render(source, with: spec), "\(spec.id.rawValue) が現像できない")
        }
    }

    // MARK: - ライブプレビュー

    func testDevelopProducesAnImageForEveryCamera() throws {
        let renderer = FilmRenderer()
        let source = CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 60, height: 80))

        for spec in CameraCatalog.all {
            let developed = try XCTUnwrap(renderer.develop(source, with: spec), "\(spec.id.rawValue)")
            // プレビューでも撮影と同じ画角を保つ（ステージが extent を広げたままにしない）
            XCTAssertEqual(developed.extent, source.extent)
            XCTAssertNotNil(renderer.rasterize(developed))
        }
    }

    func testDevelopMatchesTheDevelopedStillForTheSameCamera() throws {
        // プレビュー（CIImage 経路）と撮影後の1枚（UIImage 経路）が同じステージ列を通ること。
        // ここがずれると「選んだときに見えた写り」と「保存された写り」が食い違う。
        let renderer = FilmRenderer()
        let date = Date(timeIntervalSince1970: 902_000_000)
        let size = CGSize(width: 60, height: 80)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let still = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let cgSource = try XCTUnwrap(still.normalizedUp().cgImage)

        for spec in CameraCatalog.all {
            let viaStill = try XCTUnwrap(renderer.render(still, with: spec, capturedAt: date))
            let developed = try XCTUnwrap(
                renderer.develop(CIImage(cgImage: cgSource), with: spec, capturedAt: date)
            )
            let viaPreview = UIImage(cgImage: try XCTUnwrap(renderer.rasterize(developed)))

            XCTAssertEqual(
                viaStill.pngData(),
                viaPreview.pngData(),
                "\(spec.id.rawValue): プレビューと保存で現像結果が違う"
            )
        }
    }

    func testDevelopRejectsAnEmptyImage() {
        XCTAssertNil(FilmRenderer().develop(CIImage.empty(), with: CameraCatalog.default))
    }
}
