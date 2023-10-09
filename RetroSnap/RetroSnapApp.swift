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
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        return true
    }
}

