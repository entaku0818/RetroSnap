//
//  RetroSnapApp.swift
//  RetroSnap
//
//  Created by 遠藤拓弥 on 30.9.2023.
//

import SwiftUI
import GoogleMobileAds
import FirebaseCrashlytics
import FirebaseCore
import AppTrackingTransparency

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
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        })

        return true
    }
}

