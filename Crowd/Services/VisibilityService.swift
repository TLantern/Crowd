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
    
    private init() {
        self.db = FirebaseManager.shared.db
    }
    
    // MARK: - Toggle Visibility
    
    func toggleVisibility(userId: String) async throws {
        // Fetch current profile to get current visibility state
        let currentProfile = try await UserProfileService.shared.fetchProfile(userId: userId)
        let newVisibility = !currentProfile.isVisible
        
        try await updateVisibilityInFirestore(userId: userId, isVisible: newVisibility)
        print("👁️ Visibility toggled: \(newVisibility ? "ON" : "OFF") for user \(userId)")
    }
    
    // MARK: - Update Visibility in Firestore
    
    func updateVisibilityInFirestore(userId: String, isVisible: Bool) async throws {
        print("👁️ Updating visibility in Firestore: \(isVisible) for user \(userId)")
        
        try await db.collection("users")
            .document(userId)
            .setData([
                "isVisible": isVisible
            ], merge: true)
        
        print("✅ Visibility updated in Firestore: \(isVisible)")
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
                
                print("👁️ Visible users updated: \(profiles.count) users")
                onChange(profiles)
            }
    }
}
