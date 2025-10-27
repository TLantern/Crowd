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
    
    // MARK: - Create Profile
    
    func createProfile(
        userId: String,
        displayName: String,
        campus: String,
        interests: [String],
        avatarColorHex: String? = nil
    ) async throws {
        print("🔧 UserProfileService: Creating profile for userId: \(userId)")
        print("   - displayName: \(displayName)")
        print("   - campus: \(campus)")
        print("   - interests: \(interests)")
        
        let color = avatarColorHex ?? generateRandomColor()
        let handle = "@\(displayName.lowercased().replacingOccurrences(of: " ", with: ""))"
        
        let profile = UserProfile(
            id: userId,
            displayName: displayName,
            handle: handle,
            bio: nil,
            campus: campus,
            interests: interests,
            auraPoints: 0,
            avatarColorHex: color,
            profileImageURL: nil,
            hostedCount: 0,
            joinedCount: 0,
            friendsCount: 0,
            lastActive: Date(),
            createdAt: Date()
        )
        
        print("🔧 UserProfileService: Profile object created, calling saveProfile...")
        try await saveProfile(profile)
    }
    
    // MARK: - Save/Update Profile
    
    func saveProfile(_ profile: UserProfile) async throws {
        print("🔧 UserProfileService: saveProfile called for userId: \(profile.id)")
        
        let data: [String: Any] = [
            "displayName": profile.displayName,
            "handle": profile.handle ?? "",
            "bio": profile.bio ?? "",
            "campus": profile.campus ?? "",
            "interests": profile.interests,
            "auraPoints": profile.auraPoints,
            "avatarColorHex": profile.avatarColorHex,
            "profileImageURL": profile.profileImageURL ?? "",
            "hostedCount": profile.hostedCount,
            "joinedCount": profile.joinedCount,
            "friendsCount": profile.friendsCount,
            "lastActive": Timestamp(date: profile.lastActive ?? Date()),
            "createdAt": Timestamp(date: profile.createdAt)
        ]
        
        print("🔧 UserProfileService: Data prepared, writing to Firestore collection 'users', document '\(profile.id)'")
        
        do {
            try await db.collection("users").document(profile.id).setData(data, merge: true)
            print("✅ UserProfileService: Firestore write successful")
        } catch {
            print("❌ UserProfileService: Firestore write failed with error: \(error)")
            throw error
        }
        
        // Update cache
        profileCache[profile.id] = profile
        
        print("✅ Profile saved for user: \(profile.id)")
    }
    
    func updateProfile(userId: String, updates: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(updates)
        
        // Clear cache to force refresh
        profileCache.removeValue(forKey: userId)
        
        print("✅ Profile updated for user: \(userId)")
    }
    
    // MARK: - Fetch Profile
    
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
        let handle = data["handle"] as? String
        let bio = data["bio"] as? String
        let campus = data["campus"] as? String
        let interests = data["interests"] as? [String] ?? []
        let auraPoints = data["auraPoints"] as? Int ?? 0
        let avatarColorHex = data["avatarColorHex"] as? String ?? "#808080"
        let profileImageURL = data["profileImageURL"] as? String
        let hostedCount = data["hostedCount"] as? Int ?? 0
        let joinedCount = data["joinedCount"] as? Int ?? 0
        let friendsCount = data["friendsCount"] as? Int ?? 0
        
        let lastActive: Date?
        if let timestamp = data["lastActive"] as? Timestamp {
            lastActive = timestamp.dateValue()
        } else {
            lastActive = nil
        }
        
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        return UserProfile(
            id: userId,
            displayName: displayName,
            handle: handle,
            bio: bio,
            campus: campus,
            interests: interests,
            auraPoints: auraPoints,
            avatarColorHex: avatarColorHex,
            profileImageURL: profileImageURL,
            hostedCount: hostedCount,
            joinedCount: joinedCount,
            friendsCount: friendsCount,
            lastActive: lastActive,
            createdAt: createdAt
        )
    }
    
    // MARK: - Utility
    
    func clearCache() {
        profileCache.removeAll()
    }
    
    private func generateRandomColor() -> String {
        let colors = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8",
            "#F7DC6F", "#BB8FCE", "#85C1E2", "#F8B195", "#C06C84"
        ]
        return colors.randomElement() ?? "#808080"
    }
}

