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

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var hostProfile: UserProfile?
    @Published var friendsAttending: [UserProfile] = []
    @Published var isLoadingHost = false
    @Published var isLoadingFriends = false
    @Published var isJoining = false
    @Published var joinError: String?
    
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
            AnalyticsService.shared.trackEventJoined(eventId: event.id, title: event.title)
            print("✅ Locally joined live campus event: \(event.id)")
            return true
        }

        do {
            try await eventRepo.join(eventId: event.id, userId: userId)
            
            // Create attendance record in userAttendances collection
            try await createAttendanceRecord(eventId: event.id, userId: userId)
            
            // Add to attended events
            attendedEventsService.addAttendedEvent(event)
            
            // Track analytics
            AnalyticsService.shared.trackEventJoined(eventId: event.id, title: event.title)
            
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
}

