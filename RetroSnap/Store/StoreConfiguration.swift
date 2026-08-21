//
//  StoreConfiguration.swift
//  RetroSnap
//
//  RevenueCat の API キーの受け渡しと初期化。
//
//  ★キーはリポジトリに置かない。
//   Info.plist の `RevenueCatAPIKey` を経由し、その値は xcconfig（Config/Secrets.xcconfig、
//   git 管理外）から差し込む。未設定でも**クラッシュさせない**: 課金が使えない状態に留め、
//   カメラストアに理由を出す。無料カメラは今までどおり使える。
//
//  設定手順:
//    1. RevenueCat で RetroSnap のプロジェクトを作り、iOS の公開 SDK キー（appl_ で始まる）を取る
//    2. `Config/Secrets.xcconfig` を作って `REVENUECAT_API_KEY = appl_xxxxx` を書く
//       （雛形は Config/Secrets.xcconfig.example）
//    3. Xcode の Project > Info > Configurations で、Debug / Release の両方に
//       Secrets.xcconfig を割り当てる
//
//  公開 SDK キーはアプリに埋め込まれる前提のもの（バイナリから読める）なので、
//  秘密鍵ではない。それでも履歴に残さないほうが差し替えが楽なので xcconfig 経由にしている。
//

import Foundation
import RevenueCat

enum StoreConfiguration {

    /// Info.plist に埋める鍵の名前。
    private static let infoPlistKey = "RevenueCatAPIKey"

    /// 設定済みのキー。未設定・空・雛形のままなら nil。
    static var apiKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String else {
            return nil
        }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // xcconfig を割り当てていないと "$(REVENUECAT_API_KEY)" が素のまま入ってくる。
        guard !key.isEmpty, !key.hasPrefix("$"), key != "REPLACE_ME" else { return nil }
        return key
    }

    /// 課金を動かせる状態か。
    static var isConfigured: Bool { apiKey != nil }

    /// 起動時に1回だけ呼ぶ。キーが無ければ何もしない。
    static func configureIfPossible() {
        guard let apiKey else {
            print("RevenueCat の API キーが未設定。課金は無効のまま起動する（無料カメラは使える）")
            return
        }

        #if DEBUG
        Purchases.logLevel = .warn
        #else
        Purchases.logLevel = .error
        #endif

        Purchases.configure(withAPIKey: apiKey)
    }
}
