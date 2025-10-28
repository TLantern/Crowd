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
    
    // MARK: - Create Profile
    
    func createProfile(
        userId: String,
        displayName: String,
        campus: String,
        interests: [String],
        avatarColorHex: String? = nil,
        profileImage: UIImage? = nil
    ) async throws {
        print("🔧 UserProfileService: Creating profile for userId: \(userId)")
        print("   - displayName: \(displayName)")
        print("   - campus: \(campus)")
        print("   - interests: \(interests)")
        print("   - profileImage: \(profileImage != nil ? "provided" : "nil")")
        
        let color = avatarColorHex ?? generateRandomColor()
        let handle = "@\(displayName.lowercased().replacingOccurrences(of: " ", with: ""))"
        
        // Upload profile image if provided
        var profileImageURL: String? = nil
        if let image = profileImage {
            print("📸 UserProfileService: Uploading profile image...")
            profileImageURL = try await uploadProfileImage(image, userId: userId)
            print("✅ UserProfileService: Profile image uploaded: \(profileImageURL ?? "nil")")
        }
        
        let profile = UserProfile(
            id: userId,
            displayName: displayName,
            handle: handle,
            bio: nil,
            campus: campus,
            interests: interests,
            auraPoints: 0,
            avatarColorHex: color,
            profileImageURL: profileImageURL,
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
    
    // MARK: - Profile Image Upload
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        print("📸 UserProfileService: Saving profile image locally for userId: \(userId)")
        
        // Resize image to reasonable size (max 1024x1024)
        let resizedImage = resizeImage(image, to: CGSize(width: 1024, height: 1024))
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            print("❌ UserProfileService: Failed to convert image to JPEG data")
            throw NSError(domain: "UserProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        print("📸 UserProfileService: Image data size: \(imageData.count) bytes")
        
        // Save to local documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsPath.appendingPathComponent("ProfileImages")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        
        let imageURL = imagesDirectory.appendingPathComponent("\(userId).jpg")
        
        do {
            try imageData.write(to: imageURL)
            print("✅ UserProfileService: Image saved locally at: \(imageURL.path)")
            
            // Return a local file URL that can be used to display the image
            return "file://\(imageURL.path)"
        } catch {
            print("❌ UserProfileService: Failed to save image locally: \(error)")
            throw error
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Local Image Loading
    
    func loadLocalProfileImage(userId: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent("ProfileImages/\(userId).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            print("📸 UserProfileService: No local image found for userId: \(userId)")
            return nil
        }
        
        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            print("❌ UserProfileService: Failed to load local image for userId: \(userId)")
            return nil
        }
        
        print("✅ UserProfileService: Loaded local image for userId: \(userId)")
        return image
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
        
        // Parse notification fields
        let fcmToken = data["fcmToken"] as? String
        let lastTokenUpdate: Date?
        if let timestamp = data["lastTokenUpdate"] as? Timestamp {
            lastTokenUpdate = timestamp.dateValue()
        } else {
            lastTokenUpdate = nil
        }
        
        // Parse location fields
        var latitude: Double? = nil
        var longitude: Double? = nil
        if let geoPoint = data["location"] as? GeoPoint {
            latitude = geoPoint.latitude
            longitude = geoPoint.longitude
        }
        let geohash = data["geohash"] as? String
        let lastLocationUpdate: Date?
        if let timestamp = data["lastLocationUpdate"] as? Timestamp {
            lastLocationUpdate = timestamp.dateValue()
        } else {
            lastLocationUpdate = nil
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
            createdAt: createdAt,
            fcmToken: fcmToken,
            lastTokenUpdate: lastTokenUpdate,
            latitude: latitude,
            longitude: longitude,
            geohash: geohash,
            lastLocationUpdate: lastLocationUpdate
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

