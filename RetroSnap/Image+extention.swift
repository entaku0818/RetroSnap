//
//  Image+extention.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 30.9.2023.
//

import Foundation
import UIKit

extension UIImage {
    /// ピクセルの並びを `.up` に揃えた画像を返す。
    ///
    /// `AVCapturePhoto` から作った `UIImage` は、ピクセルは横倒しのままで
    /// `imageOrientation` に「本来の向き」を持っている状態になる。
    /// 一方 `CIImage(cgImage:)` は `imageOrientation` を見ないため、そのまま現像すると
    /// 「画面では正しいのに保存すると倒れている」という食い違いが起きる（診断レポート §11-#2）。
    /// 現像の入口でここを通し、以降は向きの補正を一切しない。
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
