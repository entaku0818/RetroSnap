//
//  AdmobBannerView.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 8.10.2023.
//

import GoogleMobileAds
import UIKit
import SwiftUI

struct AdmobBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)

        #if DEBUG
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        view.adUnitID = "ca-app-pub-3484697221349891/8738220120"
        #endif
        view.rootViewController = Self.rootViewController()
        view.delegate = context.coordinator
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 起動直後はまだシーンが前面に出ておらず nil になることがあるので、ここで拾い直す
        if uiView.rootViewController == nil {
            uiView.rootViewController = Self.rootViewController()
        }
    }

    // Adding the Coordinator for delegate handling
     func makeCoordinator() -> Coordinator {
         Coordinator()
     }

    /// 表示中のウインドウのルート。これが nil だとバナーはロードされない
    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
    }

    class Coordinator: NSObject, BannerViewDelegate {

        // 広告受信時
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("adUnitID: \(bannerView.adUnitID ?? "nil")")
            print("Ad received successfully.")

        }

        // 広告受信失敗時
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Failed to load ad with error: \(error.localizedDescription)")
            print("adUnitID: \(bannerView.adUnitID ?? "nil")")

        }

        // インプレッションが記録された時
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("Impression has been recorded for the ad.")
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            print("Ad was clicked.")
        }
    }
}


#Preview {
    AdmobBannerView()
}
