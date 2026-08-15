//
//  SamplePreviewFrame.swift
//  RetroSnap
//
//  シミュレータには実カメラが無く `AVCaptureDevice.default(for: .video)` が nil を返すため、
//  ライブプレビューが常に真っ黒になり、カメラ切替の効きを目視で確認できない。
//  そこで**シミュレータでだけ**、カメラの映像の代わりに手続き的に描いた1枚を
//  同じ現像パイプラインへ流す。
//
//  - 実機ではこのファイルのコードは1行も実行されない（`#if targetEnvironment(simulator)`）。
//    プレビューが出ない状況で偽の映像を出すのは実機では誤解のもとなので、意図的に閉じている。
//  - アセットは持たない。カメラ追加と同じで、増やすのはコードのパラメータだけ。
//

#if targetEnvironment(simulator)

import CoreImage
import UIKit

enum SamplePreviewFrame {

    /// 現像の効きが分かるだけの情報量を持つ1枚を作る。
    /// - 空のグラデーションと太陽（ハレーション・色被りが見える明部）
    /// - 中間調の建物（彩度・コントラストが見える面）
    /// - 影（ビネットが見える暗部）
    static func make(size: CGSize = CGSize(width: 900, height: 1600)) -> CIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext

            // 空
            let colors = [
                UIColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1).cgColor,
                UIColor(red: 0.85, green: 0.72, blue: 0.55, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height * 0.62),
                    options: []
                )
            }

            // 太陽（ハイライト）
            UIColor(white: 0.99, alpha: 1).setFill()
            let sun = CGRect(
                x: size.width * 0.58,
                y: size.height * 0.14,
                width: size.width * 0.22,
                height: size.width * 0.22
            )
            cgContext.fillEllipse(in: sun)

            // 地面
            UIColor(red: 0.32, green: 0.3, blue: 0.26, alpha: 1).setFill()
            cgContext.fill(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: size.height * 0.38))

            // 建物（中間調）
            let buildings: [(x: CGFloat, w: CGFloat, h: CGFloat, color: UIColor)] = [
                (0.04, 0.22, 0.26, UIColor(red: 0.75, green: 0.35, blue: 0.3, alpha: 1)),
                (0.28, 0.18, 0.36, UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)),
                (0.48, 0.24, 0.22, UIColor(red: 0.32, green: 0.55, blue: 0.45, alpha: 1)),
                (0.74, 0.2, 0.31, UIColor(red: 0.82, green: 0.72, blue: 0.4, alpha: 1)),
            ]
            for building in buildings {
                building.color.setFill()
                let height = size.height * building.h
                cgContext.fill(CGRect(
                    x: size.width * building.x,
                    y: size.height * 0.62 - height,
                    width: size.width * building.w,
                    height: height
                ))
            }

            // 手前の影（暗部）
            UIColor(white: 0.08, alpha: 1).setFill()
            cgContext.fill(CGRect(x: 0, y: size.height * 0.88, width: size.width, height: size.height * 0.12))
        }

        guard let cgImage = image.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}

#endif
