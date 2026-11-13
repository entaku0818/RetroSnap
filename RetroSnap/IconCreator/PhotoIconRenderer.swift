import UIKit
import ImageIO

/// The preview and PNG export share the same geometry and crop calculation.
enum PhotoIconRenderer {
    static let window = CGRect(x: 272, y: 214, width: 480, height: 596)

    static func cropRect(imageSize: CGSize, zoom: CGFloat, position: CGPoint) -> CGRect {
        let scale = max(window.width / imageSize.width, window.height / imageSize.height)
            * min(max(zoom, 1), 3)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = min(max(position.x, -1), 1)
        let y = min(max(position.y, -1), 1)
        return CGRect(x: window.midX - size.width / 2 + x * (size.width - window.width) / 2,
                      y: window.midY - size.height / 2 + y * (size.height - window.height) / 2,
                      width: size.width, height: size.height)
    }

    static func render(_ photo: UIImage, zoom: CGFloat = 1, position: CGPoint = .zero,
                       pixels: Int = 1024) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: pixels, height: pixels), format: format).image { renderer in
            let context = renderer.cgContext
            context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
            context.translateBy(x: 512, y: 512)
            context.rotate(by: -.pi / 18)
            context.translateBy(x: -512, y: -512)
            UIColor(red: 1, green: 0.96, blue: 0.85, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 122, y: 144, width: 780, height: 736), cornerRadius: 26).fill()
            UIColor(white: 0.12, alpha: 1).setFill()
            for x in [CGFloat(158), CGFloat(788)] {
                for y in [CGFloat(230), CGFloat(462), CGFloat(694)] {
                    UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 78, height: 100), cornerRadius: 14).fill()
                }
            }
            context.saveGState()
            UIBezierPath(roundedRect: window, cornerRadius: 18).addClip()
            photo.draw(in: cropRect(imageSize: photo.size, zoom: zoom, position: position))
            context.restoreGState()
        }
    }

    /// Decode only the size needed by the editor, including EXIF rotation.
    static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
