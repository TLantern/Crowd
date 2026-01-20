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
    private var mockUsersEnabled = true // Enabled - constant mock user for onboarding
    
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
    
    // Generate constant mock user for onboarding
    private func generateMockUsers() -> [UserProfile] {
        let bruceHallCoordinate = CLLocationCoordinate2D(
            latitude: 33.2087,
            longitude: -97.1524
        )
        
        // Parse the date from the provided data (January 19, 2026 at 10:13:51 PM UTC-6)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "America/Chicago")
        let createdAtDate = dateFormatter.date(from: "2026-01-19 22:13:51") ?? Date()
        let lastActiveDate = createdAtDate
        let lastLocationUpdateDate = dateFormatter.date(from: "2026-01-19 22:14:19") ?? Date()
        let lastTokenUpdateDate = dateFormatter.date(from: "2026-01-14 18:53:08") ?? Date()
        
        return [
            UserProfile(
                id: "mock_teni",
                displayName: "teni",
                handle: "@teni",
                bio: "",
                campus: "UNT",
                interests: [
                    "Music",
                    "Basketball",
                    "Gym Life",
                    "Adventure",
                    "Foodie",
                    "Coding",
                    "AI & Tech",
                    "Startups",
                    "Entrepreneurship",
                    "Esports",
                    "Campus Events",
                    "Travel",
                    "Beach Days",
                    "Chill Spots"
                ],
                auraPoints: 0,
                avatarColorHex: "#85C1E2",
                profileImageURL: "https://i.pinimg.com/236x/a6/65/6f/a6656f5d7f2d0074993dca19278d6774.jpg",
                hostedCount: 0,
                joinedCount: 0,
                friendsCount: 0,
                lastActive: lastActiveDate,
                createdAt: createdAtDate,
                fcmToken: nil, // Not needed for mock
                lastTokenUpdate: lastTokenUpdateDate,
                latitude: bruceHallCoordinate.latitude,
                longitude: bruceHallCoordinate.longitude,
                geohash: "9vfuvm",
                lastLocationUpdate: lastLocationUpdateDate,
                notificationCooldowns: nil,
                lastNotificationSent: nil,
                eventStatus: ["wunna-them-nights-feat-gunna-live"],
                termsAccepted: true,
                blockedUsers: nil,
                isVisible: true,
                visibilityExpiresAt: Date().addingTimeInterval(6 * 60 * 60)
            )
        ]
    }
    
    // MARK: - Toggle Visibility
    
    func toggleVisibility(userId: String) async throws {
        // Fetch current profile to get current visibility state
        let currentProfile = try await UserProfileService.shared.fetchProfile(userId: userId)
        
        let newVisibility = !currentProfile.isVisible
        
        // If turning on, set expiration to 6 hours from now and save current location
        let expiresAt = newVisibility ? Date().addingTimeInterval(6 * 60 * 60) : nil
        
        // When enabling visibility, ensure current location is saved immediately
        if newVisibility {
            let locationService = AppEnvironment.current.location
            if let coordinate = await locationService.ensureLocationAvailable() {
                await locationService.saveLocationToProfile(userId: userId, coordinate: coordinate)
                print("👁️ Saved location when enabling visibility: \(coordinate.latitude), \(coordinate.longitude)")
            }
        }
        
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
        
        print("👁️ Fetching visible users in region, found \(profiles.count) real users")
        
        // Add constant mock user for onboarding
        if mockUsersEnabled {
            profiles.append(contentsOf: cachedMockUsers)
            print("👁️ Added \(cachedMockUsers.count) constant mock user for onboarding")
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
                
                // Add constant mock user for onboarding
                if self.mockUsersEnabled {
                    profiles.append(contentsOf: self.cachedMockUsers)
                }
                
                onChange(profiles)
            }
    }
}
