import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import RetroSnap

final class PhotoIconTests: XCTestCase {
    func testCropNeverExposesEmptyEdgesAtAnyPosition() {
        for size in [CGSize(width: 4000, height: 1000), CGSize(width: 800, height: 4000), CGSize(width: 500, height: 500)] {
            for zoom in [CGFloat(1), 2, 3] {
                for position in [CGPoint(x: -1, y: -1), .zero, CGPoint(x: 1, y: 1)] {
                    let rect = PhotoIconRenderer.cropRect(imageSize: size, zoom: zoom, position: position)
                    XCTAssertLessThanOrEqual(rect.minX, PhotoIconRenderer.window.minX + 0.001)
                    XCTAssertLessThanOrEqual(rect.minY, PhotoIconRenderer.window.minY + 0.001)
                    XCTAssertGreaterThanOrEqual(rect.maxX, PhotoIconRenderer.window.maxX - 0.001)
                    XCTAssertGreaterThanOrEqual(rect.maxY, PhotoIconRenderer.window.maxY - 0.001)
                }
            }
        }
    }

    func testExportIsOpaque1024PNGWithPhotoInsideFrame() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let input = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 160), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 160))
        }
        let output = PhotoIconRenderer.render(input)
        let cg = try XCTUnwrap(output.cgImage)
        XCTAssertEqual(cg.width, 1024); XCTAssertEqual(cg.height, 1024)
        XCTAssertEqual(output.imageOrientation, .up)
        var pixels = [UInt8](repeating: 0, count: 1024 * 1024 * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1024, height: 1024,
                bitsPerComponent: 8, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        }
        XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 })
        let png = try XCTUnwrap(output.pngData())
        XCTAssertNotNil(UIImage(data: png))
        let center = pixel(cg, x: 512, y: 512)
        XCTAssertGreaterThan(center[0], 240)
        XCTAssertLessThan(center[1], 10)
        let corner = pixel(cg, x: 0, y: 0)
        XCTAssertLessThan(corner[0], 50)
        XCTAssertEqual(corner[3], 255)
    }

    func testDecodeRejectsCorruptDataAndDownsamplesLargePhoto() throws {
        XCTAssertNil(PhotoIconRenderer.decode(Data("invalid image".utf8)))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let large = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000), format: format).image { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000))
        }
        let decoded = try XCTUnwrap(PhotoIconRenderer.decode(try XCTUnwrap(large.jpegData(compressionQuality: 0.8))))
        XCTAssertEqual(decoded.size.width, 2048)
        XCTAssertEqual(decoded.imageOrientation, .up)
    }

    @MainActor
    func testLoadFailurePreservesPreviousPhotoAndResetRestoresCrop() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200)).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
        }
        try XCTUnwrap(image.pngData()).write(to: url)
        let model = PhotoIconModel()
        await model.load(url: url)
        XCTAssertNotNil(model.preview)
        XCTAssertFalse(model.isLoading)
        model.zoom = 2; model.horizontal = 1; model.vertical = -1
        model.reset()
        XCTAssertEqual(model.zoom, 1); XCTAssertEqual(model.horizontal, 0); XCTAssertEqual(model.vertical, 0)
        await model.load(url: url.appendingPathExtension("missing"))
        XCTAssertNotNil(model.message)
        XCTAssertNotNil(model.photo)
        XCTAssertFalse(model.isLoading)
    }

    func testCameraPhotoEXIFRotationIsAppliedBeforeCropping() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let decoded = try XCTUnwrap(PhotoIconRenderer.decode(data as Data))
        XCTAssertEqual(decoded.size, CGSize(width: 40, height: 80))
        XCTAssertEqual(decoded.imageOrientation, .up)
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        }
        return bytes
    }
}
