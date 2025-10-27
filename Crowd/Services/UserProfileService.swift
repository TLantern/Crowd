//
//  UserProfileService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/26/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

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
    
    // MARK: - Profile Creation & Updates
    
    func createUser(displayName: String, campus: String, interests: [String]) async throws -> UserProfile {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            throw NSError(domain: "UserProfileService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let functions = FirebaseManager.shared.functions
        let callable = functions.httpsCallable("createUser")
        
        let data: [String: Any] = [
            "displayName": displayName,
            "interests": interests,
            "campus": campus
        ]
        
        let result = try await callable.call(data)
        
        guard let response = result.data as? [String: Any],
              let success = response["success"] as? Bool,
              success else {
            throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create user"])
        }
        
        // Fetch the newly created profile
        let profile = try await fetchProfile(userId: userId)
        
        print("✅ User profile created: \(displayName)")
        return profile
    }
    
    func updateProfile(userId: String, updates: [String: Any]) async throws {
        let functions = FirebaseManager.shared.functions
        let callable = functions.httpsCallable("updateUser")
        
        var data = updates
        data["id"] = userId
        
        let result = try await callable.call(data)
        
        guard let response = result.data as? [String: Any],
              let success = response["success"] as? Bool,
              success else {
            throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update profile"])
        }
        
        // Clear cache to force refresh
        profileCache.removeValue(forKey: userId)
        
        print("✅ User profile updated")
    }
    
    func updateInterests(userId: String, interests: [String]) async throws {
        try await updateProfile(userId: userId, updates: ["interests": interests])
    }
    
    func updateDisplayName(userId: String, displayName: String) async throws {
        try await updateProfile(userId: userId, updates: ["displayName": displayName])
    }
    
    // MARK: - Profile Image Upload
    
    /// Upload profile image to Firebase Storage and update user profile
    func uploadProfileImage(userId: String, image: UIImage) async throws -> String {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "UserProfileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Upload to Firebase Storage
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("profile_images/\(userId).jpg")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload image
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await imageRef.downloadURL()
        
        // Update user profile with image URL
        try await updateProfile(userId: userId, updates: ["profileImageURL": downloadURL.absoluteString])
        
        print("✅ Profile image uploaded: \(downloadURL.absoluteString)")
        
        return downloadURL.absoluteString
    }
}

