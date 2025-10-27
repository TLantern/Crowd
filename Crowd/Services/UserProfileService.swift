//
//  UserProfileService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import Foundation
import FirebaseFirestore

final class UserProfileService {
    static let shared = UserProfileService()
    
    private let db: Firestore
    private var profileCache: [String: UserProfile] = [:]
    
    private init() {
        self.db = FirebaseManager.shared.db
    }
    
    func fetchProfile(userId: String) async throws -> UserProfile {
        // Check cache first
        if let cached = profileCache[userId] {
            return cached
        }
        
        // Fetch from Firestore
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists,
              let data = document.data() else {
            // Return anonymous profile if not found
            return UserProfile.anonymous
        }
        
        let profile = try parseProfile(from: data, userId: userId)
        
        // Cache the profile
        profileCache[userId] = profile
        
        return profile
    }
    
    func fetchProfiles(userIds: [String]) async throws -> [UserProfile] {
        return try await withThrowingTaskGroup(of: UserProfile.self) { group in
            for userId in userIds {
                group.addTask {
                    try await self.fetchProfile(userId: userId)
                }
            }
            
            var profiles: [UserProfile] = []
            for try await profile in group {
                profiles.append(profile)
            }
            return profiles
        }
    }
    
    private func parseProfile(from data: [String: Any], userId: String) throws -> UserProfile {
        let displayName = data["displayName"] as? String ?? "Guest"
        let auraPoints = data["auraPoints"] as? Int ?? 0
        let avatarColorHex = data["avatarColorHex"] as? String ?? "#808080"
        let profileImageURL = data["profileImageURL"] as? String
        
        return UserProfile(
            id: userId,
            displayName: displayName,
            auraPoints: auraPoints,
            avatarColorHex: avatarColorHex,
            profileImageURL: profileImageURL
        )
    }
    
    func clearCache() {
        profileCache.removeAll()
    }
}

