//
//  CameraSpec.swift
//  RetroSnap
//
//  カメラ1台の定義。**値とパラメータだけを持ち、画像処理は一切書かない。**
//  実際の現像は FilmRenderer が担当する。
//

import CoreGraphics
import Foundation

// MARK: - CameraID

/// カメラの永続 ID（slug）。
///
/// - Important: rawValue は product ID `com.entaku.retrosnap.camera.<slug>` の一部になる。
///   product ID は **App Store Connect で作成後に変更できず**、さらに App Transfer 時の
///   衝突要因にもなるため、**一度決めた slug は表示名を変えても永久に変えない**。
///   表示名を変えたいときは `displayNameKey` 側だけを差し替えること。
/// - Note: 文字種は小文字英数のみ `[a-z0-9]+`（ASC / StoreKit / ファイル名 / URL で
///   表記を一貫させるため）。この制約は `CameraCatalogTests` で機械的に検証している。
struct CameraID: RawRepresentable, Hashable, Sendable, Codable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - PriceTier

/// 価格帯。課金の実装（StoreKit）は次フェーズだが、
/// slug と同じく後から変えると事故になるため今のうちに確定させておく。
enum PriceTier: String, Sendable, Codable, CaseIterable {
    /// 初期解放カメラ。product ID を持たない。
    case free
    /// 主力。色・粒子・ビネットの組合せで作る標準的なカメラ。
    case standard
    /// 光漏れ / 日付焼き込み / 歪みなど、明確に手が込んでいるもの。
    case premium
}

// MARK: - パラメータ群

/// 色調。すべての効果の土台になるので、これだけは非オプショナル。
struct ToneParams: Sendable, Equatable {
    /// 露出補正（EV）。
    var exposure: Float = 0
    /// 彩度。1 で素通し。
    var saturation: Float = 1
    /// コントラスト。1 で素通し。
    var contrast: Float = 1
    /// 明度。0 で素通し。
    var brightness: Float = 0

    /// チャンネルごとのゲイン（色被り）。1 で素通し。
    var redGain: CGFloat = 1
    var greenGain: CGFloat = 1
    var blueGain: CGFloat = 1

    /// チャンネルごとのバイアス（黒の浮き＝褪色感）。0 で素通し。
    var redBias: CGFloat = 0
    var greenBias: CGFloat = 0
    var blueBias: CGFloat = 0

    /// セピア量。0 で素通し。
    var sepia: Float = 0

    /// ゲイン・バイアスのどれかが素通しでないか。
    var hasColorShift: Bool {
        redGain != 1 || greenGain != 1 || blueGain != 1
            || redBias != 0 || greenBias != 0 || blueBias != 0
    }
}

/// フィルム粒子。
struct GrainParams: Sendable, Equatable {
    /// 強度 0...1。0 で無効。
    var intensity: Float
    /// 粒径。1 で1ピクセル相当、大きいほど粗い。
    var size: CGFloat = 1
}

/// 周辺減光。
struct VignetteParams: Sendable, Equatable {
    /// 強度。大きいほど四隅が暗い。
    var intensity: Float
    /// 半径（画像の短辺に対する倍率）。小さいほど中心だけが明るく残る。
    var radius: Float = 1
    /// 減光の立ち上がりの緩さ。
    var falloff: Float = 0.5
}

/// ハレーション（ハイライトの滲み）。
struct HalationParams: Sendable, Equatable {
    /// この明るさより上をハイライトとして抽出する 0...1。
    var threshold: Float
    /// 滲みの半径（画像の短辺に対する比率）。
    var radius: CGFloat
    /// 合成の強さ 0...1。
    var intensity: CGFloat
    /// 滲みの色。フィルムのハレーションは赤寄りに出る。
    var color: RGB = RGB(red: 1, green: 0.6, blue: 0.4)
}

/// 光漏れ。テクスチャ画像ではなく手続き的に生成する
/// （アセットを持たない分カメラ追加が軽く、テストで決定的に検証できる）。
struct LightLeakParams: Sendable, Equatable {
    /// 光源の中心。画像の左下を (0, 0)、右上を (1, 1) とする正規化座標。
    var center: CGPoint
    /// 光が最も強い範囲の半径（画像の短辺に対する比率）。
    var innerRadius: CGFloat = 0
    /// 光が消えるまでの半径（画像の短辺に対する比率）。
    var outerRadius: CGFloat = 0.8
    /// 光の色。
    var color: RGB
    /// 不透明度 0...1。0 で無効。
    var opacity: CGFloat
}

/// レンズ歪み（樽型の膨らみ）。
struct DistortionParams: Sendable, Equatable {
    /// 歪みの量。正で中心が膨らむ。0 で無効。
    var amount: Float
    /// 歪みが及ぶ半径（画像の長辺に対する比率）。
    var radiusFraction: CGFloat = 0.8
}

/// 日付の焼き込み。
struct DateStampParams: Sendable, Equatable {
    /// 焼き込む位置。
    enum Corner: Sendable, Equatable {
        case bottomLeading, bottomTrailing, topLeading, topTrailing

        var isTrailing: Bool { self == .bottomTrailing || self == .topTrailing }
        var isTop: Bool { self == .topLeading || self == .topTrailing }
    }

    /// `DateFormatter` の書式。`en_US_POSIX` 固定で解釈される。
    var dateFormat: String
    /// 文字の高さ（画像の高さに対する比率）。
    var sizeFraction: CGFloat = 0.045
    /// 縁からの余白（画像の短辺に対する比率）。
    var margin: CGFloat = 0.035
    /// 文字色。
    var color: RGB = RGB(red: 1, green: 0.45, blue: 0.05)
    /// 焼き込む位置。
    var corner: Corner = .bottomTrailing
}

/// 縁取り。
///
/// - Warning: インスタントカメラ特有の「下辺だけが極端に広い白フチ」は
///   トレードドレスとして権利行使の対象になり得るため、**均一な縁しか作れない形にしてある**
///   （診断レポート §9-1）。下辺だけを広げるパラメータを足さないこと。
struct FrameStyle: Sendable, Equatable {
    /// 縁の太さ（画像の短辺に対する比率）。
    var widthFraction: CGFloat
    /// 縁の色。
    var color: RGB
}

/// 色。`CameraSpec` を CoreImage から独立させるため、CIColor ではなく素の値で持つ。
struct RGB: Sendable, Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

// MARK: - CameraSpec

/// カメラ1台＝「パラメータの束」。
///
/// 効果を追加したくなったらここにオプショナルのパラメータを1つ足し、
/// FilmRenderer にそれを読むステージを1つ足す。**カメラを足すだけならこのファイルは触らない。**
struct CameraSpec: Identifiable, Sendable, Equatable {
    /// 永続 ID。絶対に変えない。
    let id: CameraID
    /// 表示名のローカライズキー。表示名の変更はここだけで行う（slug は据え置く）。
    let displayNameKey: String
    /// 一覧に出す短い説明のローカライズキー。
    let taglineKey: String
    /// 価格帯。
    let tier: PriceTier

    var tone: ToneParams = ToneParams()
    var grain: GrainParams?
    var vignette: VignetteParams?
    var halation: HalationParams?
    var lightLeak: LightLeakParams?
    var distortion: DistortionParams?
    var dateStamp: DateStampParams?
    var frame: FrameStyle?
}

extension CameraSpec {
    /// 全 product ID に共通の接頭辞。
    ///
    /// bundle ID から始めることで他アプリの product ID と原理的に衝突しない（診断レポート §8-1）。
    /// `pro` / `annual` のような裸の汎用語は絶対に使わない。
    static let productIDPrefix = "com.entaku.retrosnap.camera."

    /// product ID は slug から機械的に導出する。
    /// ASC に登録する ID もこれと一致させること。カタログが唯一の情報源になる。
    var productID: String { Self.productIDPrefix + id.rawValue }

    /// RevenueCat の entitlement 識別子。これも slug から機械的に導出する。
    ///
    /// RevenueCat のダッシュボードで、この名前の entitlement を1台につき1つ作り、
    /// `productID` の商品を紐づける。アプリは entitlement しか見ないので、
    /// 後から価格や商品を差し替えてもアプリ側は無変更で済む。
    /// - Note: RevenueCat の識別子はハイフンよりアンダースコアが一般的なので
    ///   `camera_<slug>` にしてある。product ID と同じく**一度決めたら変えない**。
    var entitlementID: String { "camera_" + id.rawValue }

    /// 課金対象か（無料カメラは ASC に登録しない）。
    var isPurchasable: Bool { tier != .free }
}
