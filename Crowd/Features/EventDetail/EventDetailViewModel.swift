//
//  EventDetailViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import Foundation
import SwiftUI
import Combine

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
    private let eventRepo: EventRepository
    
    init(eventRepo: EventRepository = AppEnvironment.current.eventRepo) {
        self.eventRepo = eventRepo
    }
    
    func joinEvent(eventId: String) async -> Bool {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            joinError = "Not logged in"
            return false
        }
        
        isJoining = true
        joinError = nil
        defer { isJoining = false }
        
        do {
            try await eventRepo.join(eventId: eventId, userId: userId)
            print("✅ Successfully joined event: \(eventId)")
            return true
        } catch {
            joinError = "Failed to join event"
            print("❌ Failed to join event: \(error)")
            return false
        }
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

