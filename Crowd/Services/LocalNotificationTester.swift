//
//  LocalNotificationTester.swift
//  Crowd
//
//  Local notification testing utility for development and preview
//

import Foundation
import UserNotifications
import SwiftUI

/// Helper for testing notifications locally without Firebase
final class LocalNotificationTester {
    static let shared = LocalNotificationTester()
    
    private init() {}
    
    // MARK: - Test Notification Scenarios
    
    /// Send a test "nearby event" notification
    func sendTestNearbyEventNotification(
        eventTitle: String = "Coffee Meetup",
        eventCategory: String = "Coffee/Hangout",
        locationName: String = "University Union",
        distance: Int = 200
    ) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 New \(eventCategory) near you!"
        content.body = "\(eventTitle) at \(locationName)"
        content.sound = .default
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "type": "nearby_event",
            "eventId": UUID().uuidString,
            "category": eventCategory,
            "distance": distance,
            "locationName": locationName
        ]
        
        // Deliver after 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error.localizedDescription)")
            } else {
                print("✅ Test notification scheduled (will appear in 2 seconds)")
            }
        }
    }
    
    /// Send immediate test notification
    func sendImmediateTestNotification(
        title: String = "🧪 Test Notification",
        body: String = "This is a test notification from Crowd!"
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error.localizedDescription)")
            } else {
                print("✅ Test notification sent immediately")
            }
        }
    }
    
    /// Send test notifications for different event categories
    func sendTestNotificationForCategory(_ category: EventCategory, distance: Int = 150) {
        sendTestNearbyEventNotification(
            eventTitle: getSampleEventTitle(for: category),
            eventCategory: category.rawValue,
            locationName: getSampleLocation(),
            distance: distance
        )
    }
    
    // MARK: - Sample Data Helpers
    
    private func getSampleEventTitle(for category: EventCategory) -> String {
        switch category {
        case .musicEntertainment:
            return "Open Mic Night"
        case .foodDining:
            return "Taco Tuesday"
        case .sportsFitness:
            return "Basketball Pickup Game"
        case .academicEducation:
            return "Finals Study Group"
        case .artsCulture:
            return "Art Gallery Opening"
        case .socialNetworking:
            return "Career Mixer"
        case .healthWellness:
            return "Yoga Session"
        case .outdoorNature:
            return "Campus Walk"
        case .gamingEntertainment:
            return "Mario Kart Tournament"
        case .lifestyleHobbies:
            return "Coffee Chat"
        case .politicsActivism:
            return "Student Government Meeting"
        case .specialEvents:
            return "Friday Night Party"
        case .other:
            return "General Event"
        }
    }
    
    private func getSampleLocation() -> String {
        let locations = [
            "University Union",
            "Willis Library",
            "The Syndicate",
            "Rec Center",
            "Denton Square"
        ]
        return locations.randomElement() ?? "University Union"
    }
    
    // MARK: - Batch Testing
    
    /// Send multiple test notifications with delays
    func sendTestBatch(count: Int = 3, delayBetween: TimeInterval = 3) {
        let categories: [EventCategory] = [.musicEntertainment, .foodDining, .academicEducation, .gamingEntertainment, .sportsFitness]
        
        for i in 0..<count {
            let category = categories[i % categories.count]
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (delayBetween * Double(i))) {
                self.sendTestNotificationForCategory(category, distance: Int.random(in: 50...350))
            }
        }
        
        print("📬 Scheduled \(count) test notifications")
    }
    
    // MARK: - Clear Notifications
    
    /// Remove all pending notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        // Reset badge
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        print("🧹 Cleared all notifications")
    }
    
    // MARK: - Check Permission Status
    
    func checkPermissionStatus(completion: @escaping (Bool, String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            let status: String
            
            switch settings.authorizationStatus {
            case .notDetermined:
                status = "Not Determined - Need to request permission"
            case .denied:
                status = "Denied - User must enable in Settings"
            case .authorized:
                status = "Authorized ✅"
            case .provisional:
                status = "Provisional - Quiet notifications only"
            case .ephemeral:
                status = "Ephemeral - App Clip only"
            @unknown default:
                status = "Unknown"
            }
            
            DispatchQueue.main.async {
                completion(isAuthorized, status)
            }
        }
    }
}

// MARK: - SwiftUI Preview Helper

#if DEBUG
struct NotificationTestView: View {
    @State private var permissionStatus = "Checking..."
    @State private var isAuthorized = false
    @State private var showSuccessMessage = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Permission Status") {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(permissionStatus)
                            .foregroundColor(isAuthorized ? .green : .orange)
                            .font(.caption)
                    }
                    
                    if !isAuthorized {
                        Button("Request Permission") {
                            NotificationService.shared.requestPermission()
                            checkStatus()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Quick Tests") {
                    Button("Send Immediate Test") {
                        LocalNotificationTester.shared.sendImmediateTestNotification()
                        showSuccess()
                    }
                    
                    Button("Send Nearby Event (2s delay)") {
                        LocalNotificationTester.shared.sendTestNearbyEventNotification()
                        showSuccess()
                    }
                }
                
                Section("Test by Category") {
                    ForEach(EventCategory.allCases) { category in
                        Button("\(category.emoji) \(category.rawValue)") {
                            LocalNotificationTester.shared.sendTestNotificationForCategory(category)
                            showSuccess()
                        }
                    }
                }
                
                Section("Batch Tests") {
                    Button("Send 3 Notifications (3s apart)") {
                        LocalNotificationTester.shared.sendTestBatch(count: 3, delayBetween: 3)
                        showSuccess()
                    }
                    
                    Button("Send 5 Notifications (2s apart)") {
                        LocalNotificationTester.shared.sendTestBatch(count: 5, delayBetween: 2)
                        showSuccess()
                    }
                }
                
                Section("Cleanup") {
                    Button("Clear All Notifications", role: .destructive) {
                        LocalNotificationTester.shared.clearAllNotifications()
                    }
                }
                
                if showSuccessMessage {
                    Section {
                        Text("✅ Notification scheduled!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("🔔 Notification Tester")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkStatus()
            }
            .refreshable {
                checkStatus()
            }
        }
    }
    
    private func checkStatus() {
        LocalNotificationTester.shared.checkPermissionStatus { authorized, status in
            self.isAuthorized = authorized
            self.permissionStatus = status
        }
    }
    
    private func showSuccess() {
        showSuccessMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccessMessage = false
        }
    }
}

#Preview {
    NotificationTestView()
}
#endif

