//
//  EventDetailViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import CoreLocation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var hostProfile: UserProfile?
    @Published var friendsAttending: [UserProfile] = []
    @Published var isLoadingHost = false
    @Published var isLoadingFriends = false
    @Published var isJoining = false
    @Published var joinError: String?
    @Published var isLeaving = false
    @Published var leaveError: String?
    
    private let profileService = UserProfileService.shared
    private let attendeesService = EventAttendeesService.shared
    private let attendedEventsService = AttendedEventsService.shared
    private let eventRepo: EventRepository
    
    init(eventRepo: EventRepository = AppEnvironment.current.eventRepo) {
        self.eventRepo = eventRepo
    }
    
    func joinEvent(event: CrowdEvent) async -> Bool {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            joinError = "Not logged in"
            return false
        }
        
        isJoining = true
        joinError = nil
        defer { isJoining = false }
        
        // Calendar/live campus events (with sourceURL) are not stored in backend events collection.
        // Join locally to avoid "Event not found" errors when tapping from map or calendar.
        if event.sourceURL != nil {
            attendedEventsService.addAttendedEvent(event)
            let coordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
            let zone = coordinate.geohash(precision: 4)
            AnalyticsService.shared.trackEventJoined(eventId: event.id, title: event.title, zone: zone)
            print("✅ Locally joined live campus event: \(event.id)")
            return true
        }

        do {
            try await eventRepo.join(eventId: event.id, userId: userId)
            
            // Create attendance record in userAttendances collection
            try await createAttendanceRecord(eventId: event.id, userId: userId)
            
            // Add to attended events
            attendedEventsService.addAttendedEvent(event)
            
            // Track analytics with zone
            let coordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
            let zone = coordinate.geohash(precision: 4)
            AnalyticsService.shared.trackEventJoined(eventId: event.id, title: event.title, zone: zone)
            
            print("✅ Successfully joined event: \(event.id)")
            return true
        } catch {
            joinError = "Failed to join event"
            print("❌ Failed to join event: \(error)")
            return false
        }
    }
    
    private func createAttendanceRecord(eventId: String, userId: String) async throws {
        let db = FirebaseManager.shared.db
        let attendanceData: [String: Any] = [
            "userId": userId,
            "eventId": eventId,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("userAttendances").addDocument(data: attendanceData)
        print("✅ Created attendance record for user \(userId) and event \(eventId)")
    }
    
    func loadHostProfile(hostId: String) async {
        isLoadingHost = true
        defer { isLoadingHost = false }
        
        do {
            hostProfile = try await profileService.fetchProfile(userId: hostId)
        } catch {
            print("Failed to load host profile: \(error)")
            // Use anonymous profile as fallback
            hostProfile = UserProfile.anonymous
        }
    }
    
    func loadFriendsAttending(eventId: String) async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId() else {
            return
        }
        
        do {
            friendsAttending = try await attendeesService.fetchFriendsAttending(
                eventId: eventId,
                currentUserId: currentUserId
            )
        } catch {
            print("Failed to load friends attending: \(error)")
            friendsAttending = []
        }
    }
    
    func leaveEvent(event: CrowdEvent) async -> Bool {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            leaveError = "Not logged in"
            return false
        }
        
        isLeaving = true
        leaveError = nil
        defer { isLeaving = false }
        
        // Calendar/live campus events (with sourceURL) are not stored in backend events collection.
        // Leave locally for these events.
        if event.sourceURL != nil {
            attendedEventsService.removeAttendedEvent(event.id)
            print("✅ Locally left live campus event: \(event.id)")
            return true
        }
        
        do {
            try await eventRepo.leave(eventId: event.id, userId: userId)
            
            // Remove from attended events
            attendedEventsService.removeAttendedEvent(event.id)
            
            print("✅ Successfully left event: \(event.id)")
            return true
        } catch {
            leaveError = "Failed to leave event"
            print("❌ Failed to leave event: \(error)")
            return false
        }
    }
}

