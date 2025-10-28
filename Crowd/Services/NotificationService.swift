//
//  NotificationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import UserNotifications
import FirebaseMessaging
import FirebaseFirestore
import UIKit

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    func configure() {
        print("📱 NotificationService: Configuring push notifications...")
        
        // Set delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Request permission
        requestPermission()
        
        // Register for remote notifications
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        print("✅ NotificationService: Configuration complete")
    }
    
    // MARK: - Permission Request
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ NotificationService: Permission error - \(error.localizedDescription)")
                return
            }
            print("📱 NotificationService: Permission granted: \(granted)")
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("❌ NotificationService: FCM token is nil")
            return
        }
        
        print("🔑 NotificationService: FCM Token received")
        print("🔑 Token: \(token)")
        
        // Save token to user's Firestore profile
        Task {
            await saveFCMTokenToProfile(token: token)
        }
    }
    
    // MARK: - Token Management
    
    func saveFCMTokenToProfile(token: String) async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ NotificationService: Cannot save token - no user ID")
            return
        }
        
        print("💾 NotificationService: Saving FCM token to Firestore...")
        
        do {
            try await FirebaseManager.shared.db
                .collection("users")
                .document(userId)
                .updateData([
                    "fcmToken": token,
                    "lastTokenUpdate": Timestamp(date: Date())
                ])
            print("✅ NotificationService: FCM token saved to user profile")
        } catch {
            print("❌ NotificationService: Failed to save token - \(error.localizedDescription)")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notifications while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📬 NotificationService: Received notification in foreground")
        print("📬 Notification data: \(userInfo)")
        
        // Show notification banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap (when user taps on notification)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 NotificationService: User tapped notification")
        print("👆 Notification data: \(userInfo)")
        
        // TODO: Handle notification tap - navigate to specific screen if needed
        
        completionHandler()
    }
}
