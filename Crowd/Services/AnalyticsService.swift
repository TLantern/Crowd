//
//  AnalyticsService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import FirebaseAnalytics

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Event Tracking
    
    func track(_ name: String, props: [String: Any] = [:]) {
        // Log to console for debugging
        print("📊 Analytics: \(name) | \(props)")
        
        // Log to Firebase Analytics
        Analytics.logEvent(name, parameters: props)
    }
    
    // MARK: - User Events
    
    func trackUserCreated(userId: String, displayName: String) {
        track("user_created", props: [
            "user_id": userId,
            "display_name": displayName
        ])
    }
    
    func trackProfileUpdated(userId: String) {
        track("profile_updated", props: [
            "user_id": userId
        ])
    }
    
    // MARK: - Event Events
    
    func trackEventCreated(eventId: String, title: String, category: String?) {
        track("event_created", props: [
            "event_id": eventId,
            "title": title,
            "category": category ?? "unknown"
        ])
    }
    
    func trackEventJoined(eventId: String, title: String) {
        track("event_joined", props: [
            "event_id": eventId,
            "title": title
        ])
    }
    
    func trackEventDeleted(eventId: String) {
        track("event_deleted", props: [
            "event_id": eventId
        ])
    }
    
    func trackSignalBoosted(eventId: String, newStrength: Int) {
        track("signal_boosted", props: [
            "event_id": eventId,
            "strength": newStrength
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
    
    func trackMessageSent(eventId: String) {
        track("message_sent", props: [
            "event_id": eventId
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
}
