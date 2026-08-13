//
//  FilmRenderer.swift
//  RetroSnap
//
//  CameraSpec を受けて1枚を現像する唯一のエンジン。
//
//  ★設計の要点: このファイルに `switch spec.id { case .plain70: ... }` を書いてはいけない。
//   効果は「カメラごと」ではなく「効果の種類ごと」に1ステージだけ実装されており、
//   各ステージは CameraSpec のパラメータが nil か / 素通し値かだけを見て on/off する。
//   そのため **カメラを1台足してもこのファイルは1行も増えない**。
//   増えるのは「今までに無い種類の効果」を導入するときだけで、そのときは
//   CameraSpec にパラメータを1つ、ここにステージを1つ足す。
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class FilmRenderer {

    static let shared = FilmRenderer()

    /// 診断レポート §11-#6 の修正。
    /// 以前は `Image+extention.swift` で現像のたびに `CIContext()` を生成していた。
    /// CIContext は生成コストが高く、かつスレッドセーフなので1つを共有する。
    private let context: CIContext

    /// 現像はメインスレッドから逃がす。多段フィルタになった分、UI を止めると体感が悪い。
    private let queue = DispatchQueue(label: "com.entaku.RetroSnap.FilmRenderer", qos: .userInitiated)

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    // MARK: - 現像

    /// 現像してメインスレッドで結果を返す。撮影時のようにUIを止めたくない経路で使う。
    /// - Parameter capturedAt: 日付焼き込みに使う日時。
    func render(
        _ image: UIImage,
        with spec: CameraSpec,
        capturedAt: Date = Date(),
        completion: @escaping (UIImage?) -> Void
    ) {
        queue.async { [weak self] in
            let result = self?.render(image, with: spec, capturedAt: capturedAt)
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// 同期版。呼び出し元のスレッドで現像する。
    /// - Note: 重いのでメインスレッドから直接呼ばないこと。テストとプレビュー生成用。
    func render(_ image: UIImage, with spec: CameraSpec, capturedAt: Date = Date()) -> UIImage? {
        // 診断レポート §11-#2 の修正。
        // 以前は保存パスが `sepiaTone()` だけ、表示パスが `sepiaTone()?.orientedImage(...)` で、
        // 保存された画像と画面に出た画像の向きが食い違っていた。
        // ここで入力を .up に正規化し、保存・表示・アルバムのすべてが同じ1枚を使う。
        guard let source = image.normalizedUp().cgImage else { return nil }

        var ciImage = CIImage(cgImage: source)
        let extent = ciImage.extent
        guard !extent.isEmpty, !extent.isInfinite,
              extent.width.isFinite, extent.height.isFinite else { return nil }

        for stage in Self.stages {
            // 各ステージはぼかしや歪みで extent を広げうるので、毎回元のサイズに戻す。
            ciImage = stage(ciImage, spec, capturedAt).cropped(to: extent)
        }

        guard let rendered = context.createCGImage(ciImage, from: extent) else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: .up)
    }

    // MARK: - パイプライン

    private typealias Stage = (CIImage, CameraSpec, Date) -> CIImage

    /// 適用順。順番には意味がある:
    /// 幾何変形 → 色 → 光学現象 → 減光 → 重ね物 → 粒子 → 焼き込み → 縁。
    private static let stages: [Stage] = [
        applyDistortion,
        applyTone,
        applyHalation,
        applyVignette,
        applyLightLeak,
        applyGrain,
        applyDateStamp,
        applyFrame,
    ]

    // MARK: - 各ステージ

    /// レンズ歪み。
    private static func applyDistortion(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let params = spec.distortion, params.amount != 0 else { return input }
        let extent = input.extent

        let filter = CIFilter.bumpDistortion()
        // clamp しておかないと歪みで縁に透明が出る。
        filter.inputImage = input.clampedToExtent()
        filter.center = CGPoint(x: extent.midX, y: extent.midY)
        filter.radius = Float(max(extent.width, extent.height) * params.radiusFraction)
        filter.scale = params.amount
        return filter.outputImage ?? input
    }

    /// 色調（露出・彩度・コントラスト・色被り・セピア）。
    private static func applyTone(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        let tone = spec.tone
        var image = input

        if tone.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = tone.exposure
            image = filter.outputImage ?? image
        }

        if tone.saturation != 1 || tone.contrast != 1 || tone.brightness != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.saturation = tone.saturation
            filter.contrast = tone.contrast
            filter.brightness = tone.brightness
            image = filter.outputImage ?? image
        }

        if tone.hasColorShift {
            let filter = CIFilter.colorMatrix()
            filter.inputImage = image
            filter.rVector = CIVector(x: tone.redGain, y: 0, z: 0, w: 0)
            filter.gVector = CIVector(x: 0, y: tone.greenGain, z: 0, w: 0)
            filter.bVector = CIVector(x: 0, y: 0, z: tone.blueGain, w: 0)
            filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            filter.biasVector = CIVector(x: tone.redBias, y: tone.greenBias, z: tone.blueBias, w: 0)
            image = filter.outputImage ?? image
        }

        if tone.sepia > 0 {
            let filter = CIFilter.sepiaTone()
            filter.inputImage = image
            filter.intensity = tone.sepia
            image = filter.outputImage ?? image
        }

        return image
    }

    /// ハレーション。ハイライトを抜き出し、色を付けてぼかし、加算で戻す。
    private static func applyHalation(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let params = spec.halation, params.intensity > 0 else { return input }
        let extent = input.extent

        let threshold = CGFloat(max(0, min(0.999, params.threshold)))

        // まず輝度に落とす。
        // チャンネルごとに閾値を見ると「明るくはないが青が濃い空」のような
        // 彩度の高い面が丸ごと発光してしまうため、必ず輝度で判定する。
        // 注意: CIColorMatrix は `out.r = dot(pixel, rVector)` という定義。
        // つまり rVector は「出力Rを作るための (r,g,b,a) への重み」であって、
        // 「入力Rが各出力へ配る量」ではない。対角行列なら区別が付かないが、
        // ここのような非対角行列では転置すると別物になる。
        let weights = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        let luminance = CIFilter.colorMatrix()
        luminance.inputImage = input
        luminance.rVector = weights
        luminance.gVector = weights
        luminance.bVector = weights
        luminance.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let luma = luminance.outputImage else { return input }

        // 閾値より暗いところを一律に潰す（この後の変換で 0 になる）。
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = luma
        clamp.minComponents = CIVector(x: threshold, y: threshold, z: threshold, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        guard let clamped = clamp.outputImage else { return input }

        // threshold...1 を 0...1 に伸ばしてマスクにする。
        let gain = 1 / (1 - threshold)
        let normalize = CIFilter.colorMatrix()
        normalize.inputImage = clamped
        normalize.rVector = CIVector(x: gain, y: 0, z: 0, w: 0)
        normalize.gVector = CIVector(x: 0, y: gain, z: 0, w: 0)
        normalize.bVector = CIVector(x: 0, y: 0, z: gain, w: 0)
        normalize.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        normalize.biasVector = CIVector(x: -threshold * gain, y: -threshold * gain, z: -threshold * gain, w: 0)
        guard let linearMask = normalize.outputImage else { return input }

        // マスクを2乗して落ちを速くする。
        // これが無いと、閾値を少し超えただけの広い面（明るい空など）が
        // 面ごと持ち上がって白飛びする。滲みは「一番明るいところ」にだけ出したい。
        let falloff = CIFilter.gammaAdjust()
        falloff.inputImage = linearMask
        falloff.power = 2
        guard let mask = falloff.outputImage else { return input }

        // マスクに色と強度を乗せる。
        let tint = CIFilter.colorMatrix()
        tint.inputImage = mask
        tint.rVector = CIVector(x: params.color.red * params.intensity, y: 0, z: 0, w: 0)
        tint.gVector = CIVector(x: 0, y: params.color.green * params.intensity, z: 0, w: 0)
        tint.bVector = CIVector(x: 0, y: 0, z: params.color.blue * params.intensity, w: 0)
        tint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let highlights = tint.outputImage else { return input }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = highlights.clampedToExtent()
        blur.radius = Float(min(extent.width, extent.height) * params.radius)
        guard let blurred = blur.outputImage else { return input }


        // 加算合成(CIAdditionCompositing)は、RGB=0・アルファ=1 の層を重ねただけで
        // 下地が白飛びする挙動を示したため使わない。
        // スクリーン合成なら層が黒のところは下地がそのまま残る＝滲みの無い場所は無変化になる。
        let blend = CIFilter.screenBlendMode()
        blend.inputImage = blurred.cropped(to: extent)
        blend.backgroundImage = input
        return blend.outputImage ?? input
    }

    /// 周辺減光。
    private static func applyVignette(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let params = spec.vignette, params.intensity > 0 else { return input }
        let extent = input.extent

        let filter = CIFilter.vignetteEffect()
        filter.inputImage = input
        filter.center = CGPoint(x: extent.midX, y: extent.midY)
        filter.radius = Float(min(extent.width, extent.height)) * params.radius
        filter.intensity = params.intensity
        filter.falloff = params.falloff
        return filter.outputImage ?? input
    }

    /// 光漏れ。放射グラデーションをスクリーン合成で重ねる。
    private static func applyLightLeak(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let params = spec.lightLeak, params.opacity > 0 else { return input }
        let extent = input.extent
        let base = min(extent.width, extent.height)

        let gradient = CIFilter.radialGradient()
        gradient.center = CGPoint(
            x: extent.minX + extent.width * params.center.x,
            y: extent.minY + extent.height * params.center.y
        )
        gradient.radius0 = Float(base * params.innerRadius)
        gradient.radius1 = Float(base * max(params.innerRadius + 0.001, params.outerRadius))
        gradient.color0 = CIColor(
            red: params.color.red,
            green: params.color.green,
            blue: params.color.blue,
            alpha: params.opacity
        )
        gradient.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let leak = gradient.outputImage?.cropped(to: extent) else { return input }

        let blend = CIFilter.screenBlendMode()
        blend.inputImage = leak
        blend.backgroundImage = input
        return blend.outputImage ?? input
    }

    /// フィルム粒子。
    private static func applyGrain(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let params = spec.grain, params.intensity > 0 else { return input }
        let extent = input.extent

        // CIRandomGenerator は座標から決まる決定的なノイズなので、同じ入力なら毎回同じ絵になる。
        guard let raw = CIFilter.randomGenerator().outputImage else { return input }
        let sized = params.size > 1
            ? raw.transformed(by: CGAffineTransform(scaleX: params.size, y: params.size))
            : raw

        // アルファチャンネルだけを粒子の素性に使う。
        // RGB はプリマルチプライ済みでアルファの乱数が掛かった値になっており、
        // 割り戻すとアルファが小さい画素で値が発散して白い点が散る。アルファ自体は一様乱数なので素直。
        // 同時に、強度に応じて中間グレー(0.5)へ寄せるところまで1枚の行列で済ませる。
        // out = a * intensity + 0.5 * (1 - intensity) なので、intensity 0 なら 0.5 = 素通しになる。
        let intensity = CGFloat(params.intensity)
        let level = CIVector(x: 0, y: 0, z: 0, w: intensity)
        let bias = 0.5 * (1 - intensity)
        let monochrome = CIFilter.colorMatrix()
        monochrome.inputImage = sized.cropped(to: extent)
        monochrome.rVector = level
        monochrome.gVector = level
        monochrome.bVector = level
        monochrome.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        monochrome.biasVector = CIVector(x: bias, y: bias, z: bias, w: 1)
        guard let grain = monochrome.outputImage?.cropped(to: extent) else { return input }

        // オーバーレイだと1ピクセル単位の白点が浮いてデジタルノイズに見えるので、
        // フィルムの粒に近い柔らかさになるソフトライトで重ねる。
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = grain
        blend.backgroundImage = input
        return blend.outputImage ?? input
    }

    /// 日付の焼き込み。
    private static func applyDateStamp(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let params = spec.dateStamp else { return input }
        let extent = input.extent

        let formatter = DateFormatter()
        // 端末のロケール設定で表記が揺れないように固定する。
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = params.dateFormat
        let text = formatter.string(from: date) as NSString

        let fontSize = extent.height * params.sizeFraction
        guard fontSize >= 1 else { return input }
        let attributes: [NSAttributedString.Key: Any] = [
            // 実在のセグメント表示フォントを模した書体は同梱しない（アセット不要・権利上も安全）。
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor(
                red: params.color.red,
                green: params.color.green,
                blue: params.color.blue,
                alpha: 1
            ),
        ]

        let textSize = text.size(withAttributes: attributes)
        guard textSize.width >= 1, textSize.height >= 1 else { return input }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let stamp = UIGraphicsImageRenderer(size: textSize, format: format).image { _ in
            text.draw(at: .zero, withAttributes: attributes)
        }
        guard let stampCG = stamp.cgImage else { return input }

        // CIImage(cgImage:) が上下の向きを吸収するので、ここで反転を掛けてはいけない
        // （掛けると日付が上下逆に焼き込まれる）。
        var stampImage = CIImage(cgImage: stampCG)

        let margin = min(extent.width, extent.height) * params.margin
        let x = params.corner.isTrailing
            ? extent.maxX - margin - stampImage.extent.width
            : extent.minX + margin
        let y = params.corner.isTop
            ? extent.maxY - margin - stampImage.extent.height
            : extent.minY + margin
        stampImage = stampImage.transformed(by: CGAffineTransform(translationX: x, y: y))

        // 光として焼き込まれた見え方にしたいのでスクリーン合成にする。
        let blend = CIFilter.screenBlendMode()
        blend.inputImage = stampImage
        blend.backgroundImage = input
        return blend.outputImage ?? input
    }

    /// 縁取り。写真を内側に縮めるのではなく、外周に色を重ねる。
    private static func applyFrame(_ input: CIImage, _ spec: CameraSpec, _ date: Date) -> CIImage {
        guard let style = spec.frame, style.widthFraction > 0 else { return input }
        let extent = input.extent

        let inset = min(extent.width, extent.height) * style.widthFraction
        let inner = extent.insetBy(dx: inset, dy: inset)
        guard !inner.isEmpty else { return input }

        let border = CIImage(color: CIColor(
            red: style.color.red,
            green: style.color.green,
            blue: style.color.blue,
            alpha: 1
        )).cropped(to: extent)

        let over = CIFilter.sourceOverCompositing()
        over.inputImage = input.cropped(to: inner)
        over.backgroundImage = border
        return over.outputImage ?? input
    }
}
