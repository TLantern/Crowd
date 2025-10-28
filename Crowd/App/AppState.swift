//
//  AppState.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation

@MainActor
final class AppState: ObservableObject {
    @Published var sessionUser: UserProfile? = .anonymous
    @Published var selectedRegion: CampusRegion = .mainCampus
    @Published var camera: MapCameraPosition = .automatic
    @Published var unreadRewardNotice: Bool = false
    
    private var locationUpdateCancellable: AnyCancellable?
    private var lastLocationSaveTime: Date?

    func bootstrap() async {
        // Authenticate anonymously with Firebase
        do {
            let userId = try await FirebaseManager.shared.signInAnonymously()
            print("✅ Authenticated with Firebase: \(userId)")
            
            // Load user profile
            await loadUserProfile(userId: userId)
            
            // Start monitoring location updates
            startLocationMonitoring(userId: userId)
        } catch {
            print("⚠️ Firebase auth failed: \(error.localizedDescription)")
        }
        // preload regions, request location (soft), warm caches
    }
    
    private func loadUserProfile(userId: String) async {
        do {
            let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
            await MainActor.run {
                self.sessionUser = profile
                print("✅ Loaded user profile: \(profile.displayName)")
            }
        } catch {
            print("⚠️ Failed to load user profile: \(error.localizedDescription)")
            // Keep anonymous profile as fallback
        }
    }
    
    // MARK: - Location Monitoring
    
    private func startLocationMonitoring(userId: String) {
        print("📍 AppState: Starting location monitoring for user \(userId)")
        
        let locationService = AppEnvironment.current.location
        
        // Subscribe to location updates
        locationUpdateCancellable = locationService.$lastKnown
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.handleLocationUpdate(userId: userId, coordinate: coordinate)
            }
    }
    
    private func handleLocationUpdate(userId: String, coordinate: CLLocationCoordinate2D) {
        // Only save every 5 minutes to reduce Firestore writes
        let now = Date()
        if let lastSave = lastLocationSaveTime,
           now.timeIntervalSince(lastSave) < 300 { // 5 minutes
            return
        }
        
        lastLocationSaveTime = now
        
        Task {
            await AppEnvironment.current.location.saveLocationToProfile(
                userId: userId,
                coordinate: coordinate
            )
        }
    }
}
