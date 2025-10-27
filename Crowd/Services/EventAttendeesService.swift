//
//  EventAttendeesService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import Foundation
import FirebaseFirestore

final class EventAttendeesService {
    static let shared = EventAttendeesService()
    
    private let db: Firestore
    private let profileService = UserProfileService.shared
    
    private init() {
        self.db = FirebaseManager.shared.db
    }
    
    func fetchAttendees(eventId: String) async throws -> [UserProfile] {
        // Query signals collection for this event
        let snapshot = try await db.collection("signals")
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()
        
        // Extract unique user IDs
        let userIds = snapshot.documents.compactMap { doc -> String? in
            doc.data()["userId"] as? String
        }
        
        // Fetch profiles for all attendees
        return try await profileService.fetchProfiles(userIds: userIds)
    }
    
    func fetchFriendsAttending(eventId: String, currentUserId: String) async throws -> [UserProfile] {
        // Fetch all attendees
        let attendees = try await fetchAttendees(eventId: eventId)
        
        // Fetch current user's friends list
        let friendIds = try await fetchFriendIds(userId: currentUserId)
        
        // Filter attendees to only friends
        return attendees.filter { friendIds.contains($0.id) }
    }
    
    private func fetchFriendIds(userId: String) async throws -> Set<String> {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data(),
              let friendsArray = data["friends"] as? [String] else {
            return []
        }
        
        return Set(friendsArray)
    }
}

