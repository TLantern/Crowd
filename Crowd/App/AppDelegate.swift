//
//  AppDelegate.swift
//  Crowd
//
//  Created by AI Assistant
//

import UIKit
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🚀 AppDelegate: App did finish launching")
        
        // Firebase is already configured in FirebaseManager.shared
        // Just ensure it's initialized
        _ = FirebaseManager.shared
        
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

