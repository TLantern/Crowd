//
//  AnalyticsService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import FirebaseAnalytics
import FirebaseFirestore

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Event Tracking
    
    func track(_ name: String, props: [String: Any] = [:]) {
        // Automatically include user_id if available
        var propsWithUserId = props
        if let userId = FirebaseManager.shared.getCurrentUserId() {
            propsWithUserId["user_id"] = userId
        }
        
        // Log to console for debugging
        print("📊 Analytics: \(name) | \(propsWithUserId)")
        
        // Log to Firebase Analytics
        Analytics.logEvent(name, parameters: propsWithUserId)
    }
    
    // MARK: - Firestore Activity Logging
    
    func logToFirestore(eventName: String, properties: [String: Any] = [:], zone: String? = nil) {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ AnalyticsService: Cannot log to Firestore - no user ID")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        var eventData: [String: Any] = [
            "eventName": eventName,
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "properties": properties
        ]
        
        if let zone = zone {
            eventData["zone"] = zone
        }
        
        let db = FirebaseManager.shared.db
        let eventRef = db.collection("activity_logs")
            .document(dateString)
            .collection("events")
            .document()
        
        eventRef.setData(eventData) { error in
            if let error = error {
                print("❌ AnalyticsService: Failed to log to Firestore - \(error.localizedDescription)")
            } else {
                print("✅ AnalyticsService: Logged \(eventName) to Firestore")
            }
        }
    }
    
    // MARK: - User Events
    
    func trackUserCreated(userId: String, displayName: String, campus: String? = nil, interestsCount: Int? = nil) {
        var props: [String: Any] = [
            "user_id": userId,
            "display_name": displayName
        ]
        if let campus = campus {
            props["campus"] = campus
        }
        if let interestsCount = interestsCount {
            props["interests_count"] = interestsCount
        }
        track("user_created", props: props)
    }
    
    func trackProfileUpdated(userId: String, fieldsChanged: [String] = []) {
        track("profile_updated", props: [
            "user_id": userId,
            "fields_changed": fieldsChanged.joined(separator: ",")
        ])
    }
    
    func trackProfileImageUploaded(userId: String) {
        track("profile_image_uploaded", props: [
            "user_id": userId
        ])
    }
    
    func trackInterestsUpdated(userId: String, interestsCount: Int) {
        track("interests_updated", props: [
            "user_id": userId,
            "interests_count": interestsCount
        ])
    }
    
    // MARK: - Event Events
    
    func trackEventCreated(eventId: String, title: String, category: String?, zone: String? = nil) {
        let props: [String: Any] = [
            "event_id": eventId,
            "title": title,
            "category": category ?? "unknown"
        ]
        track("event_created", props: props)
        logToFirestore(eventName: "event_created", properties: props, zone: zone)
    }
    
    func trackEventJoined(eventId: String, title: String, zone: String? = nil) {
        let props: [String: Any] = [
            "event_id": eventId,
            "title": title
        ]
        track("event_joined", props: props)
        logToFirestore(eventName: "event_joined", properties: props, zone: zone)
    }
    
    func trackEventDeleted(eventId: String) {
        track("event_deleted", props: [
            "event_id": eventId
        ])
    }
    
    func trackSignalBoosted(eventId: String, oldStrength: Int, newStrength: Int) {
        track("signal_boosted", props: [
            "event_id": eventId,
            "old_strength": oldStrength,
            "new_strength": newStrength
        ])
    }
    
    // MARK: - Screen Views
    
    func trackScreenView(_ screenName: String) {
        track("screen_view", props: [
            "screen_name": screenName
        ])
        
        // Log screen view to Firebase Analytics
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenName
        ])
    }
    
    // MARK: - Social Events
    
    func trackFriendAdded(friendId: String) {
        track("friend_added", props: [
            "friend_id": friendId
        ])
    }
    
    func trackMessageSent(eventId: String, messageLength: Int) {
        track("message_sent", props: [
            "event_id": eventId,
            "message_length": messageLength
        ])
    }
    
    // MARK: - Engagement
    
    func trackLeaderboardViewed(timeframe: String) {
        track("leaderboard_viewed", props: [
            "timeframe": timeframe
        ])
    }
    
    func trackMapInteraction(action: String) {
        track("map_interaction", props: [
            "action": action
        ])
    }
    
    func trackRegionChanged(region: String) {
        track("region_changed", props: [
            "region": region
        ])
    }
    
    func trackFilterChanged(filterType: String, value: String? = nil) {
        var props: [String: Any] = ["filter_type": filterType]
        if let value = value {
            props["filter_value"] = value
        }
        track("filter_changed", props: props)
    }
}
