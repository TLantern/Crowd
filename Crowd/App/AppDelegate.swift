//
//  AppDelegate.swift
//  Crowd
//
//  Created by AI Assistant
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import SuperwallKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🚀 AppDelegate: App did finish launching")

        // Initialize FirebaseManager (it configures Firebase + App Check)
        _ = FirebaseManager.shared
        
        // Ensure permanent mock user exists
        Task {
            await UserProfileService.shared.ensurePermanentMockUser()
        }
        
        // Configure Superwall
        // Note: StoreKit "No active account" errors are expected when no Apple ID is signed in
        // These are harmless and won't affect app functionality
        let config = Config.build()
        Superwall.configure(apiKey: config.superwallAPIKey)
        print("✅ Superwall configured")
        
        return true
    }
    
    // MARK: - Remote Notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 AppDelegate: Registered for remote notifications")
        print("📱 Device token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // Pass the device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ AppDelegate: Failed to register for remote notifications")
        print("❌ Error: \(error.localizedDescription)")
    }
    
    // MARK: - Handle Remote Notification (Background)
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 AppDelegate: Received remote notification")
        print("📬 Notification data: \(userInfo)")
        
        // Handle the notification data
        // This is called when notification is received in background or when tapped
        
        completionHandler(.newData)
    }
}

