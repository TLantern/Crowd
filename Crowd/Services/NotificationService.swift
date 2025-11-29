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
        
        // Save token to user's Firestore profile only for verified users
        Task {
            // Only save token if user is verified (non-anonymous)
            if FirebaseManager.shared.isCurrentUserVerified() {
                await saveFCMTokenToProfile(token: token)
                await sendDebugTestNotification()
            } else {
                print("⏭️ NotificationService: Skipping FCM token save for anonymous user")
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
        
        // Track push opened
        var pushProps: [String: Any] = [:]
        if let notificationType = userInfo["type"] as? String {
            pushProps["notification_type"] = notificationType
        }
        if let eventId = userInfo["eventId"] as? String {
            pushProps["event_id"] = eventId
        }
        AnalyticsService.shared.track("push_opened", props: pushProps)
        AnalyticsService.shared.logToFirestore(eventName: "push_opened", properties: pushProps)
        
        // Parse notification data
        if let notificationType = userInfo["type"] as? String {
            if notificationType == "anchor_notification",
               let anchorId = userInfo["anchorId"] as? String,
               let anchorName = userInfo["anchorName"] as? String {
                print("📲 Anchor notification tapped: \(anchorName)")
                
                // Get notification time from anchor data or use current time
                let notificationTime = userInfo["notificationTime"] as? String ?? {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    formatter.timeZone = TimeZone(identifier: "America/Chicago")
                    return formatter.string(from: Date())
                }()
                
                // Mark notification as sent
                Task {
                    await AnchorNotificationService.shared.markNotificationSent(
                        anchorId: anchorId,
                        anchorName: anchorName,
                        notificationTime: notificationTime
                    )
                }
                
                // Could navigate to anchor location on map in the future
            } else if notificationType == "chat_message",
                      let eventId = userInfo["eventId"] as? String {
                print("📲 Navigate to event chat: \(eventId)")
                
                // Mark chat as read
                ChatNotificationService.shared.markAsRead(eventId: eventId)
                
                // Post notification to trigger navigation in app
                NotificationCenter.default.post(
                    name: .navigateToEventFromNotification,
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            } else if let eventId = userInfo["eventId"] as? String {
                print("📲 Navigate to event: \(eventId)")
                
                // Post notification to trigger navigation in app
                NotificationCenter.default.post(
                    name: .navigateToEventFromNotification,
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            } else {
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
        }
        
        completionHandler()
    }

    // MARK: - Host Follow Subscriptions
    
    func subscribeToHost(hostId: String) {
        print("🔔 NotificationService: Subscribed to host \(hostId)")
        // TODO: Implement FCM topic subscription when backend is ready
        // Messaging.messaging().subscribe(toTopic: "host_\(hostId)")
    }
    
    func unsubscribeFromHost(hostId: String) {
        print("🔕 NotificationService: Unsubscribed from host \(hostId)")
        // TODO: Implement FCM topic unsubscription when backend is ready
        // Messaging.messaging().unsubscribe(fromTopic: "host_\(hostId)")
    }
    
    func sendHostEventNotification(hostId: String, event: CrowdEvent) {
        print("📨 NotificationService: Would send notification for host \(hostId) event \(event.id)")
        // TODO: Implement via Firebase Cloud Function when backend is ready
    }
    
    private func sendDebugTestNotification() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { 
            print("❌ Debug: No user ID available for test notification")
            return 
        }
        
        print("🧪 Debug: Starting test notification for verified user")
        print("   - User ID: \(userId)")
        print("   - Is verified: \(FirebaseManager.shared.isCurrentUserVerified())")
        
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
            print("   - Result: \(result.data)")
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
