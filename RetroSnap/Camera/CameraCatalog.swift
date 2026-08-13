//
//  CameraCatalog.swift
//  RetroSnap
//
//  ★ カメラを1台足すときに触るのは、このファイルだけ。
//
//  手順:
//    1. 下の `CameraSpec` の extension に static let を1つ足す
//    2. `CameraCatalog.all` の配列に1行足す
//    3. 表示名・説明を Localizable.xcstrings に足す
//  FilmRenderer / CameraView / PhotoRepository は一切触らない。
//
//  命名の制約（診断レポート §8-1 / §9-1）:
//    - slug は小文字英数のみ。一度決めたら永久に変えない
//    - 実在のメーカー名・機種名・フィルム銘柄、およびその捩り（Huji 型）を使わない。
//      造語 + 時代 / 現象の記述にする
//

import CoreGraphics
import Foundation

enum CameraCatalog {
    /// アプリが扱う全カメラ。この配列がカメラ一覧の唯一の情報源。
    /// 並び順がそのままカメラ切替 UI の並び順になる。
    static let all: [CameraSpec] = [
        .plain70,
        .sunsetFade,
        .nightNeon,
        .toyPlastic,
        .dateStamp98,
    ]

    /// 起動時など、選択中カメラが決まっていないときに使う既定のカメラ。
    static let `default`: CameraSpec = .plain70

    /// slug からカメラを引く。永続化した ID の復元に使う。
    static func camera(for id: CameraID) -> CameraSpec? {
        all.first { $0.id == id }
    }

    /// 保存済みの文字列（CoreData 等）からカメラを引く。
    /// 未知の slug には既定のカメラを返すので、カメラを削除しても既存データが壊れない。
    static func camera(forSlug slug: String?) -> CameraSpec {
        guard let slug, let spec = camera(for: CameraID(slug)) else { return `default` }
        return spec
    }
}

// MARK: - ラインナップ

extension CameraSpec {

    /// ほんのり褪色・低彩度・軽いビネット。素直で失敗しない1台。
    /// モチーフ: 1970年代の一般的なカラーネガの褪色。
    static let plain70 = CameraSpec(
        id: CameraID("plain70"),
        displayNameKey: "camera.plain70.name",
        taglineKey: "camera.plain70.tagline",
        tier: .free,
        tone: ToneParams(
            exposure: 0.05,
            saturation: 0.86,
            contrast: 1.04,
            redGain: 1.04,
            greenGain: 1.0,
            blueGain: 0.94,
            redBias: 0.022,
            greenBias: 0.018,
            blueBias: 0.012,
            sepia: 0.12
        ),
        grain: GrainParams(intensity: 0.14, size: 1.2),
        vignette: VignetteParams(intensity: 0.35, radius: 1.1, falloff: 0.4)
    )

    /// 全体にオレンジ寄りの色被り、ハイライトが白く飛ぶ、粒子強め。
    /// plain70 と並べたときに差が一番分かる1台。
    /// モチーフ: 直射日光下で退色した古いプリント。
    static let sunsetFade = CameraSpec(
        id: CameraID("sunsetfade"),
        displayNameKey: "camera.sunsetfade.name",
        taglineKey: "camera.sunsetfade.tagline",
        tier: .free,
        tone: ToneParams(
            exposure: 0.32,
            saturation: 0.9,
            contrast: 0.88,
            redGain: 1.16,
            greenGain: 1.0,
            blueGain: 0.8,
            redBias: 0.06,
            greenBias: 0.032,
            blueBias: 0.02,
            sepia: 0.2
        ),
        grain: GrainParams(intensity: 0.42, size: 1.6),
        vignette: VignetteParams(intensity: 0.25, radius: 1.2, falloff: 0.35),
        halation: HalationParams(
            threshold: 0.86,
            radius: 0.028,
            intensity: 0.5,
            color: RGB(red: 1, green: 0.66, blue: 0.36)
        )
    )

    /// 暗部が青紫に転ぶ、光源が滲む、赤が誇張される。夜の街で映える1台。
    /// モチーフ: タングステン光下で日中用フィルムを使ったときの色転び。
    static let nightNeon = CameraSpec(
        id: CameraID("nightneon"),
        displayNameKey: "camera.nightneon.name",
        taglineKey: "camera.nightneon.tagline",
        tier: .standard,
        tone: ToneParams(
            exposure: -0.18,
            saturation: 1.28,
            contrast: 1.16,
            redGain: 1.12,
            greenGain: 0.94,
            blueGain: 1.2,
            redBias: 0.012,
            greenBias: 0,
            blueBias: 0.05
        ),
        grain: GrainParams(intensity: 0.34, size: 1.4),
        vignette: VignetteParams(intensity: 0.5, radius: 0.95, falloff: 0.5),
        halation: HalationParams(
            threshold: 0.76,
            radius: 0.038,
            intensity: 0.7,
            color: RGB(red: 1, green: 0.42, blue: 0.72)
        )
    )

    /// 強い周辺減光、彩度が異様に高い、四隅が流れる、光漏れが入る。
    /// モチーフ: プラスチックレンズの安価なカメラ。
    static let toyPlastic = CameraSpec(
        id: CameraID("toyplastic"),
        displayNameKey: "camera.toyplastic.name",
        taglineKey: "camera.toyplastic.tagline",
        tier: .standard,
        tone: ToneParams(
            exposure: 0.1,
            saturation: 1.45,
            contrast: 1.22,
            redGain: 1.05,
            greenGain: 1.08,
            blueGain: 0.98,
            greenBias: 0.02
        ),
        grain: GrainParams(intensity: 0.3, size: 1.5),
        vignette: VignetteParams(intensity: 1.1, radius: 0.72, falloff: 0.6),
        lightLeak: LightLeakParams(
            center: CGPoint(x: 0.94, y: 0.9),
            innerRadius: 0.05,
            outerRadius: 0.62,
            color: RGB(red: 1, green: 0.55, blue: 0.2),
            opacity: 0.55
        ),
        distortion: DistortionParams(amount: 0.32, radiusFraction: 0.78)
    )

    /// 標準的な90年代の色 + 右下にオレンジのセグメント風文字で日付を焼き込み。
    /// モチーフ: 90年代のコンパクト機のデート機能。
    static let dateStamp98 = CameraSpec(
        id: CameraID("datestamp98"),
        displayNameKey: "camera.datestamp98.name",
        taglineKey: "camera.datestamp98.tagline",
        tier: .premium,
        tone: ToneParams(
            saturation: 1.06,
            contrast: 1.06,
            redGain: 1.04,
            greenGain: 1.0,
            blueGain: 0.97,
            redBias: 0.014,
            greenBias: 0.01,
            blueBias: 0.006
        ),
        grain: GrainParams(intensity: 0.24, size: 1.3),
        vignette: VignetteParams(intensity: 0.22, radius: 1.15, falloff: 0.4),
        dateStamp: DateStampParams(
            // 90年代のデート機能の表記。`''` は DateFormatter でのアポストロフィのエスケープ。
            dateFormat: "''yy M d",
            sizeFraction: 0.05,
            margin: 0.04,
            color: RGB(red: 1, green: 0.42, blue: 0.06),
            corner: .bottomTrailing
        )
    )
}
