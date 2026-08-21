//
//  RetroSnapApp.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 30.9.2023.
//

import SwiftUI
import FirebaseCrashlytics
import FirebaseCore
import GoogleMobileAds

@main
struct RetroSnapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            CameraView()
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // StoreClient が所有状態を引きにいくより前に済ませる必要がある。
        // API キーが未設定なら何もしない（課金が無効になるだけでクラッシュはしない）。
        StoreConfiguration.configureIfPossible()

        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        MobileAds.shared.start(completionHandler: nil)

        return true
    }
}

