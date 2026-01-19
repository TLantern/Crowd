//
//  VisibilityService.swift
//  Crowd
//
//  Created by AI Assistant
//

import Foundation
import FirebaseFirestore
import CoreLocation
import MapKit
import _MapKit_SwiftUI

final class VisibilityService {
    static let shared = VisibilityService()
    
    private let db: Firestore
    
    // MARK: - Mock Users for Testing
    private var mockUsersEnabled = true // Set to false to disable mock users
    
    // Fixed reference point: UNT campus center
    private let untCampusCenter = CLLocationCoordinate2D(
        latitude: 33.210081,
        longitude: -97.147700
    )
    
    // Cached mock users with fixed coordinates
    private lazy var cachedMockUsers: [UserProfile] = {
        generateMockUsers()
    }()
    
    private init() {
        self.db = FirebaseManager.shared.db
    }
    
    // Generate mock users with fixed coordinates around UNT campus
    private func generateMockUsers() -> [UserProfile] {
        let mockUsers: [(name: String, offset: (lat: Double, lng: Double), color: String)] = [
            ("Alex Martinez", (0.002, 0.001), "#FF6B6B"),
            ("Jordan Lee", (-0.001, 0.002), "#4ECDC4"),
            ("Taylor Kim", (0.003, -0.001), "#45B7D1"),
            ("Morgan Chen", (-0.002, -0.002), "#FFA07A"),
            ("Casey Johnson", (0.001, 0.003), "#98D8C8"),
            ("Riley Patel", (-0.003, 0.001), "#F7DC6F"),
            ("Sam Williams", (0.002, -0.003), "#BB8FCE"),
            ("Dakota Brown", (0.004, 0.002), "#85C1E2"),
        ]
        
        return mockUsers.enumerated().map { index, user in
            let coordinate = CLLocationCoordinate2D(
                latitude: untCampusCenter.latitude + user.offset.lat,
                longitude: untCampusCenter.longitude + user.offset.lng
            )
            
            let interests = [
                ["🎮 Gaming", "🎵 Music", "🏀 Basketball"],
                ["📚 Reading", "☕ Coffee", "🎨 Art"],
                ["🏋️ Fitness", "🎬 Movies", "🍕 Food"],
                ["💻 Coding", "🎧 EDM", "🏃 Running"],
                ["🎸 Guitar", "📷 Photography", "🌮 Tacos"],
                ["🎭 Theater", "🏊 Swimming", "🍜 Ramen"],
                ["🎯 Darts", "🎲 Board Games", "☕ Tea"],
                ["🎨 Design", "🚴 Cycling", "🍣 Sushi"]
            ]
            
            return UserProfile(
                id: "mock_\(index)",
                displayName: user.name,
                handle: "@\(user.name.lowercased().replacingOccurrences(of: " ", with: ""))",
                bio: nil,
                campus: "UNT",
                interests: interests[index % interests.count],
                auraPoints: Int.random(in: 50...500),
                avatarColorHex: user.color,
                profileImageURL: nil,
                hostedCount: Int.random(in: 0...10),
                joinedCount: Int.random(in: 5...25),
                friendsCount: Int.random(in: 10...100),
                lastActive: Date(),
                createdAt: Date(),
                fcmToken: nil,
                lastTokenUpdate: nil,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                geohash: coordinate.geohash(precision: 6),
                lastLocationUpdate: Date(),
                notificationCooldowns: nil,
                lastNotificationSent: nil,
                eventStatus: nil,
                termsAccepted: true,
                blockedUsers: nil,
                isVisible: true,
                visibilityExpiresAt: Date().addingTimeInterval(6 * 60 * 60)
            )
        }
    }
    
    // MARK: - Toggle Visibility
    
    func toggleVisibility(userId: String) async throws {
        // Fetch current profile to get current visibility state
        let currentProfile = try await UserProfileService.shared.fetchProfile(userId: userId)
        
        let newVisibility = !currentProfile.isVisible
        
        // If turning on, set expiration to 6 hours from now
        let expiresAt = newVisibility ? Date().addingTimeInterval(6 * 60 * 60) : nil
        
        try await updateVisibilityInFirestore(userId: userId, isVisible: newVisibility, expiresAt: expiresAt)
    }
    
    // MARK: - Update Visibility in Firestore
    
    func updateVisibilityInFirestore(userId: String, isVisible: Bool, expiresAt: Date?) async throws {
        let docRef = db.collection("users").document(userId)
        
        var data: [String: Any] = [
            "isVisible": isVisible
        ]
        
        if let expiresAt = expiresAt {
            data["visibilityExpiresAt"] = Timestamp(date: expiresAt)
        } else {
            data["visibilityExpiresAt"] = FieldValue.delete()
        }
        
        try await docRef.setData(data, merge: true)
        
        // Clear the cache so next fetch gets fresh data
        UserProfileService.shared.clearCache()
    }
    
    // MARK: - Fetch Visible Users
    
    func fetchVisibleUsers(in camera: MapCamera, currentUserId: String, blockedUserIds: Set<String>) async throws -> [UserProfile] {
        let center = camera.centerCoordinate
        let distance = camera.distance // Distance in meters
        
        // Calculate geohash prefix based on camera distance
        // Use 4-character prefix for larger regions, 5 for medium, 6 for smaller
        let precision: Int
        if distance > 5000 {
            precision = 4 // ~39km x 19.5km
        } else if distance > 1000 {
            precision = 5 // ~4.9km x 4.9km
        } else {
            precision = 6 // ~610m x 610m
        }
        
        let geohashPrefix = center.geohash(precision: precision)
        
        print("👁️ Fetching visible users in region")
        print("   - Center: \(center.latitude), \(center.longitude)")
        print("   - Distance: \(distance)m")
        print("   - Geohash prefix: \(geohashPrefix) (precision: \(precision))")
        
        // Query users with isVisible == true and matching geohash
        let snapshot = try await db.collection("users")
            .whereField("isVisible", isEqualTo: true)
            .whereField("geohash", isGreaterThanOrEqualTo: geohashPrefix)
            .whereField("geohash", isLessThanOrEqualTo: geohashPrefix + "\u{f8ff}")
            .limit(to: 100) // Limit results to avoid performance issues
            .getDocuments()
        
        var profiles: [UserProfile] = []
        let now = Date()
        
        for document in snapshot.documents {
            let userId = document.documentID
            
            // Skip current user
            if userId == currentUserId {
                continue
            }
            
            // Skip blocked users
            if blockedUserIds.contains(userId) {
                continue
            }
            
            // Parse user profile
            let data = document.data()
            
            // Check visibility expiration
            if let expiresAtTimestamp = data["visibilityExpiresAt"] as? Timestamp {
                let expiresAt = expiresAtTimestamp.dateValue()
                if now > expiresAt {
                    // Visibility expired, auto-disable it
                    Task {
                        try? await updateVisibilityInFirestore(userId: userId, isVisible: false, expiresAt: nil)
                    }
                    continue
                }
            }
            
            // Check if user has location data
            guard let location = data["location"] as? GeoPoint else { continue }
            
            let userCoordinate = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            // Calculate distance from map center
            let userLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let targetLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
            let userDistance = userLocation.distance(from: targetLocation)
            
            // Filter by actual distance (within camera bounds + some margin)
            // Use camera distance as radius
            if userDistance > distance * 1.5 { // 1.5x for margin
                continue
            }
            
            // Parse and add profile
            do {
                let profile = try UserProfileService.shared.parseProfile(from: data, userId: userId)
                profiles.append(profile)
            } catch {
                print("⚠️ Failed to parse user profile for \(userId): \(error)")
            }
        }
        
        print("👁️ Fetching visible users in region, found \(profiles.count) users")
        
        // Add mock users if enabled (using fixed coordinates)
        if mockUsersEnabled {
            profiles.append(contentsOf: cachedMockUsers)
            print("👁️ Added \(cachedMockUsers.count) mock users for testing")
        }
        
        return profiles
    }
    
    // MARK: - Listen to Visible Users (Real-time)
    
    func listenToVisibleUsers(
        in camera: MapCamera,
        currentUserId: String,
        blockedUserIds: Set<String>,
        onChange: @escaping ([UserProfile]) -> Void
    ) -> ListenerRegistration {
        let center = camera.centerCoordinate
        let distance = camera.distance
        
        // Calculate geohash prefix
        let precision: Int
        if distance > 5000 {
            precision = 4
        } else if distance > 1000 {
            precision = 5
        } else {
            precision = 6
        }
        
        let geohashPrefix = center.geohash(precision: precision)
        
        print("👁️ Setting up listener for visible users with geohash prefix: \(geohashPrefix)")
        
        return db.collection("users")
            .whereField("isVisible", isEqualTo: true)
            .whereField("geohash", isGreaterThanOrEqualTo: geohashPrefix)
            .whereField("geohash", isLessThanOrEqualTo: geohashPrefix + "\u{f8ff}")
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error = error {
                        print("❌ Error listening to visible users: \(error.localizedDescription)")
                    }
                    return
                }
                
                var profiles: [UserProfile] = []
                let now = Date()
                
                for document in documents {
                    let userId = document.documentID
                    
                    // Skip current user
                    if userId == currentUserId {
                        continue
                    }
                    
                    // Skip blocked users
                    if blockedUserIds.contains(userId) {
                        continue
                    }
                    
                    let data = document.data()
                    
                    // Check visibility expiration
                    if let expiresAtTimestamp = data["visibilityExpiresAt"] as? Timestamp {
                        let expiresAt = expiresAtTimestamp.dateValue()
                        if now > expiresAt {
                            // Visibility expired, auto-disable it
                            Task {
                                try? await self.updateVisibilityInFirestore(userId: userId, isVisible: false, expiresAt: nil)
                            }
                            continue
                        }
                    }
                    
                    guard let location = data["location"] as? GeoPoint else { continue }
                    
                    let userCoordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    
                    // Filter by distance
                    let userLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    let targetLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
                    let userDistance = userLocation.distance(from: targetLocation)
                    
                    if userDistance > distance * 1.5 {
                        continue
                    }
                    
                    do {
                        let profile = try UserProfileService.shared.parseProfile(from: data, userId: userId)
                        profiles.append(profile)
                    } catch {
                        print("⚠️ Failed to parse user profile for \(userId): \(error)")
                    }
                }
                
                // Add mock users if enabled (using fixed coordinates)
                if self.mockUsersEnabled {
                    profiles.append(contentsOf: self.cachedMockUsers)
                }
                
                onChange(profiles)
            }
    }
}
