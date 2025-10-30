//
//  NotificationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import UserNotifications
import FirebaseMessaging
import FirebaseFirestore
import FirebaseFunctions
import UIKit
import Combine

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationService()
    
    // ObservableObject requirement
    let objectWillChange = PassthroughSubject<Void, Never>()
    
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
            
            // Send test notification only for verified (non-anonymous) users
            if FirebaseManager.shared.isCurrentUserVerified() {
                await sendDebugTestNotification()
            }
        }
    }
    
    // MARK: - Token Management
    
    func saveFCMTokenToProfile(token: String) async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ NotificationService: Cannot save token - no user ID")
            return
        }
        
        print("💾 NotificationService: Saving FCM token to Firestore for user: \(userId)")
        
        do {
            // Check if user document exists
            print("🔍 Checking if user document exists...")
            let userDoc = try await FirebaseManager.shared.db
                .collection("users")
                .document(userId)
                .getDocument()
            
            print("   - Document exists: \(userDoc.exists)")
            
            // If document doesn't exist, create a minimal user document
            let data: [String: Any]
            if !userDoc.exists {
                print("📝 Creating new user document for anonymous user")
                data = [
                    "displayName": "Guest",
                    "handle": "",
                    "bio": "",
                    "campus": "UNT",
                    "interests": [],
                    "auraPoints": 0,
                    "avatarColorHex": "#808080",
                    "profileImageURL": "",
                    "hostedCount": 0,
                    "joinedCount": 0,
                    "friendsCount": 0,
                    "lastActive": Timestamp(date: Date()),
                    "createdAt": Timestamp(date: Date()),
                    "fcmToken": token,
                    "lastTokenUpdate": Timestamp(date: Date())
                ]
            } else {
                print("📝 Updating FCM token on existing document")
                data = [
                    "fcmToken": token,
                    "lastTokenUpdate": Timestamp(date: Date())
                ]
            }
            
            print("💾 Writing to Firestore...")
            try await FirebaseManager.shared.db
                .collection("users")
                .document(userId)
                .setData(data, merge: true)
            
            print("✅ NotificationService: FCM token saved to user profile")
        } catch {
            print("❌ NotificationService: Failed to save token - \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - UserInfo: \(nsError.userInfo)")
            }
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
        
        // Parse notification data
        if let eventId = userInfo["eventId"] as? String {
            print("📲 Navigate to event: \(eventId)")
            
            // Post notification to trigger navigation in app
            NotificationCenter.default.post(
                name: .navigateToEventFromNotification,
                object: nil,
                userInfo: ["eventId": eventId]
            )
        } else if let notificationType = userInfo["type"] as? String {
            print("📲 Notification type: \(notificationType)")
            
            // Handle promotional notifications differently if needed
            if notificationType == "promotional" {
                // Could navigate to create event screen or just stay on home
                NotificationCenter.default.post(
                    name: .showHostSheetFromNotification,
                    object: nil
                )
            }
        }
        
        completionHandler()
    }

    private func sendDebugTestNotification() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { 
            print("❌ Debug: No user ID available for test notification")
            return 
        }
        
        print("🧪 Debug: Starting test notification for verified user")
        print("   - User ID: \(userId)")
        print("   - Is anonymous: \(FirebaseManager.shared.auth.currentUser?.isAnonymous ?? false)")
        
        do {
            print("📞 Debug: Calling testNotification Firebase Function...")
            let callable = FirebaseManager.shared.functions.httpsCallable("testNotification")
            
            let data: [String: Any] = [
                "userId": userId,
                "testMessage": "Debug test 🔔"
            ]
            print("   - Data: \(data)")
            
            let result = try await callable.call(data)
            print("✅ Debug: test notification requested successfully for \(userId)")
            print("   - Result: \(result.data ?? "nil")")
        } catch {
            print("❌ Debug: test notification error - \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - UserInfo: \(nsError.userInfo)")
            }
        }
    }
}
