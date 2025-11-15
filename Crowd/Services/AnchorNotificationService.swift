//
//  AnchorNotificationService.swift
//  Crowd
//
//  Service for scheduling local notifications for anchors
//

import Foundation
import UserNotifications
import FirebaseFirestore

final class AnchorNotificationService {
    static let shared = AnchorNotificationService()
    
    private let chicagoTimeZone = TimeZone(identifier: "America/Chicago") ?? TimeZone.current
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Schedule Notifications
    
    func scheduleNotifications(for anchors: [Anchor]) async {
        // Request permission first
        let granted = await requestPermission()
        guard granted else {
            print("⚠️ AnchorNotificationService: Notification permission not granted")
            return
        }
        
        // Cancel all existing anchor notifications
        await cancelAllAnchorNotifications()
        
        // Schedule new notifications for anchors that require them
        for anchor in anchors {
            guard anchor.sendNotification,
                  let notificationTime = anchor.notificationTimeLocal,
                  let message = anchor.notificationMessage else {
                continue
            }
            
            await scheduleNotification(for: anchor, time: notificationTime, message: message)
        }
        
        print("✅ AnchorNotificationService: Scheduled notifications for \(anchors.filter { $0.sendNotification }.count) anchors")
    }
    
    private func scheduleNotification(for anchor: Anchor, time: String, message: String) async {
        // Parse time string (HH:mm format)
        let components = time.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            print("⚠️ AnchorNotificationService: Invalid time format for anchor \(anchor.id): \(time)")
            return
        }
        
        // Schedule for each day in daysActive
        for dayAbbrev in anchor.daysActive {
            guard let weekday = dayAbbreviationToWeekday(dayAbbrev) else {
                print("⚠️ AnchorNotificationService: Invalid day abbreviation: \(dayAbbrev)")
                continue
            }
            
            // Check if notification was already sent today
            let notificationId = "anchor_\(anchor.id)_\(weekday)"
            if await hasNotificationBeenSent(anchorId: anchor.id, dayOfWeek: weekday) {
                continue
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = anchor.name
            content.body = message
            content.sound = .default
            content.userInfo = [
                "type": "anchor_notification",
                "anchorId": anchor.id,
                "anchorName": anchor.name,
                "location": anchor.location
            ]
            
            // Create date components for the trigger (Chicago timezone)
            var dateComponents = DateComponents()
            dateComponents.timeZone = chicagoTimeZone
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
            
            do {
                try await notificationCenter.add(request)
                print("✅ AnchorNotificationService: Scheduled notification for \(anchor.name) on \(dayAbbrev) at \(time)")
            } catch {
                print("❌ AnchorNotificationService: Failed to schedule notification for \(anchor.name): \(error)")
            }
        }
    }
    
    // MARK: - Cancel Notifications
    
    func cancelAllAnchorNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let anchorIds = pendingRequests.filter { $0.identifier.hasPrefix("anchor_") }.map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: anchorIds)
        print("✅ AnchorNotificationService: Cancelled \(anchorIds.count) anchor notifications")
    }
    
    func cancelNotifications(for anchorId: String) async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let anchorIds = pendingRequests.filter { $0.identifier.hasPrefix("anchor_\(anchorId)_") }.map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: anchorIds)
        print("✅ AnchorNotificationService: Cancelled notifications for anchor \(anchorId)")
    }
    
    // MARK: - Permission
    
    private func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ AnchorNotificationService: Permission request failed: \(error)")
            return false
        }
    }
    
    // MARK: - Deduplication
    
    private func hasNotificationBeenSent(anchorId: String, dayOfWeek: Int) async -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        let key = "anchor_notification_\(anchorId)_\(dayOfWeek)_\(todayString)"
        
        // Check UserDefaults
        if UserDefaults.standard.bool(forKey: key) {
            return true
        }
        
        // Check Firestore (async)
        let db = FirebaseManager.shared.db
        let logId = "\(anchorId)_\(todayString)_\(dayOfWeek)"
        do {
            let doc = try await db.collection("anchor_notification_logs").document(logId).getDocument()
            if doc.exists {
                // Also cache in UserDefaults
                UserDefaults.standard.set(true, forKey: key)
                return true
            }
        } catch {
            print("⚠️ AnchorNotificationService: Failed to check Firestore for notification log: \(error)")
        }
        
        return false
    }
    
    func markNotificationSent(anchorId: String, anchorName: String, notificationTime: String) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        var calendar = Calendar.current
        calendar.timeZone = chicagoTimeZone
        let weekday = calendar.component(.weekday, from: Date())
        
        let key = "anchor_notification_\(anchorId)_\(weekday)_\(todayString)"
        UserDefaults.standard.set(true, forKey: key)
        
        // Log to Firestore
        let db = FirebaseManager.shared.db
        let logId = "\(anchorId)_\(todayString)_\(weekday)"
        let data: [String: Any] = [
            "anchorId": anchorId,
            "anchorName": anchorName,
            "notificationTime": notificationTime,
            "date": todayString,
            "weekday": weekday,
            "sentAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("anchor_notification_logs").document(logId).setData(data)
            print("✅ AnchorNotificationService: Logged notification send to Firestore")
        } catch {
            print("⚠️ AnchorNotificationService: Failed to log to Firestore: \(error)")
        }
        
        // Track analytics
        AnalyticsService.shared.trackAnchorNotificationSent(
            anchorId: anchorId,
            anchorName: anchorName,
            notificationTime: notificationTime
        )
    }
    
    // MARK: - Helper
    
    private func dayAbbreviationToWeekday(_ abbrev: String) -> Int? {
        let mapping: [String: Int] = [
            "Sun": 1,
            "Mon": 2,
            "Tue": 3,
            "Wed": 4,
            "Thu": 5,
            "Fri": 6,
            "Sat": 7
        ]
        return mapping[abbrev]
    }
}

