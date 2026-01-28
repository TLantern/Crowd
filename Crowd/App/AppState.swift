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
import FirebaseFirestore
import SuperwallKit

@MainActor
final class AppState: ObservableObject {
    @Published var sessionUser: UserProfile? = .anonymous
    @Published var selectedRegion: CampusRegion = .mainCampus
    @Published var camera: MapCameraPosition = .automatic
    @Published var unreadRewardNotice: Bool = false
    @Published var showTutorial: Bool = false
    @Published var currentJoinedEvent: CrowdEvent? {
        didSet {
            saveCurrentJoinedEvent()
        }
    }
    @Published var isVisible: Bool = false
    
    private var visibilityCheckTimer: Timer?
    private var locationUpdateCancellable: AnyCancellable?
    private var lastLocationSaveTime: Date?
    private let userDefaults = UserDefaults.standard
    private let currentJoinedEventKey = "current_joined_event"
    private var attendedEventsCancellable: AnyCancellable?

    func bootstrap() async {
        print("📱 [AppState] bootstrap started")
        // Clean up expired attended events first
        AttendedEventsService.shared.refreshAttendedEvents()
        
        // Restore and validate current joined event
        restoreCurrentJoinedEvent()
        
        // Observe attended events changes to clear currentJoinedEvent if event is removed
        setupAttendedEventsObserver()
        
        // Authenticate anonymously with Firebase
        do {
            let userId = try await FirebaseManager.shared.signInAnonymously()
            print("✅ Authenticated with Firebase: \(userId)")
            
            // Restore attendance for events user was previously attending
            await restoreAttendance(userId: userId)
            
            // Load user profile
            await loadUserProfile(userId: userId)
            
            // Start visibility expiration check
            startVisibilityExpirationCheck(userId: userId)
            
            // Start monitoring location updates
            startLocationMonitoring(userId: userId)
            
            // Start chat notification service
            ChatNotificationService.shared.start()
            
            // Request notification permission now that the main app is loaded.
            // Deferred from launch to avoid the app becoming unresponsive on iPad
            // after the user dismisses the system notification dialog (timing
            // with SwiftUI's first layout during init).
            print("📱 [AppState] calling NotificationService.requestPermission()")
            NotificationService.shared.requestPermission()
            
            // Check if tutorial should be shown
            await MainActor.run {
                if TutorialManager.shared.shouldShowTutorial() {
                    // Delay tutorial slightly to let map load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showTutorial = true
                        print("📚 Showing tutorial for first-time user")
                    }
                }
            }
            print("📱 [AppState] bootstrap completed")
        } catch {
            print("⚠️ [AppState] Firebase auth failed: \(error.localizedDescription)")
        }
        // preload regions, request location (soft), warm caches
    }
    
    private func restoreAttendance(userId: String) async {
        let attendedEvents = AttendedEventsService.shared.getAttendedEvents()
        guard !attendedEvents.isEmpty else {
            print("📋 No attended events to restore")
            return
        }
        
        print("📋 Restoring attendance for \(attendedEvents.count) event(s)")
        
        let db = FirebaseManager.shared.db
        let eventRepo = AppEnvironment.current.eventRepo
        
        for event in attendedEvents {
            // Skip calendar/live campus events (they don't have backend signals)
            if event.sourceURL != nil {
                continue
            }
            
            // Check if signal already exists
            do {
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: event.id)
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                if signalsSnapshot.documents.isEmpty {
                    // Signal doesn't exist, re-join the event
                    print("🔄 Restoring signal for event: \(event.title)")
                    try await eventRepo.join(eventId: event.id, userId: userId)
                    print("✅ Restored attendance for event: \(event.title)")
                } else {
                    print("✅ Signal already exists for event: \(event.title)")
                }
            } catch {
                print("⚠️ Failed to restore attendance for event \(event.id): \(error.localizedDescription)")
            }
        }
    }
    
    private func loadUserProfile(userId: String) async {
        do {
            let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
            await MainActor.run {
                self.sessionUser = profile
                
                // Always start with non-visible state (eye icon)
                // Check if visibility has expired first
                if let expiresAt = profile.visibilityExpiresAt, Date() > expiresAt {
                    self.isVisible = false
                    // Auto-disable expired visibility
                    Task {
                        try? await VisibilityService.shared.updateVisibilityInFirestore(
                            userId: userId,
                            isVisible: false,
                            expiresAt: nil
                        )
                    }
                } else {
                    // Always start with non-visible (eye icon showing)
                    self.isVisible = false
                    // If profile had visibility enabled, disable it in Firestore
                    if profile.isVisible {
                        Task {
                            try? await VisibilityService.shared.updateVisibilityInFirestore(
                                userId: userId,
                                isVisible: false,
                                expiresAt: nil
                            )
                        }
                    }
                }
                
                print("✅ Loaded user profile: \(profile.displayName)")
                print("👁️ Visibility state loaded: \(self.isVisible)")
            }
            
            // Identify user in Superwall if profile exists (not anonymous)
            if profile.id != UserProfile.anonymous.id {
                Superwall.shared.identify(userId: userId)
                print("✅ Superwall: Identified existing user: \(userId)")
            }
        } catch {
            print("⚠️ Failed to load user profile: \(error.localizedDescription)")
            // Keep anonymous profile as fallback
        }
    }
    
    // MARK: - Visibility Expiration Check
    
    private func startVisibilityExpirationCheck(userId: String) {
        // Check every 60 seconds if visibility has expired
        visibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let profile = self.sessionUser,
                      profile.isVisible,
                      let expiresAt = profile.visibilityExpiresAt else { return }
                
                if Date() > expiresAt {
                    print("👁️ Visibility expired, auto-disabling")
                    self.isVisible = false
                    
                    // Update Firestore
                    try? await VisibilityService.shared.updateVisibilityInFirestore(
                        userId: userId,
                        isVisible: false,
                        expiresAt: nil
                    )
                    
                    // Reload profile to sync
                    if let updated = try? await UserProfileService.shared.fetchProfile(userId: userId) {
                        self.sessionUser = updated
                    }
                }
            }
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
        let now = Date()
        
        // If visibility is enabled, save location more frequently (every 1 minute)
        // Otherwise, save every 5 minutes to reduce Firestore writes
        let saveInterval: TimeInterval = isVisible ? 60 : 300
        
        if let lastSave = lastLocationSaveTime,
           now.timeIntervalSince(lastSave) < saveInterval {
            return
        }
        
        // Only save location if visibility is enabled
        guard isVisible else {
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
    
    // MARK: - Current Joined Event Persistence
    
    private func setupAttendedEventsObserver() {
        attendedEventsCancellable = AttendedEventsService.shared.$attendedEvents
            .sink { [weak self] events in
                guard let self = self else { return }
                // If currentJoinedEvent is not in attended events, clear it
                if let currentEvent = self.currentJoinedEvent,
                   !events.contains(where: { $0.id == currentEvent.id }) {
                    self.currentJoinedEvent = nil
                    print("🧹 Cleared currentJoinedEvent - event no longer in attended list")
                }
            }
    }
    
    private func saveCurrentJoinedEvent() {
        if let event = currentJoinedEvent,
           let data = try? JSONEncoder().encode(event) {
            userDefaults.set(data, forKey: currentJoinedEventKey)
            print("💾 Saved current joined event: \(event.title)")
        } else {
            userDefaults.removeObject(forKey: currentJoinedEventKey)
            print("💾 Cleared current joined event")
        }
    }
    
    private func restoreCurrentJoinedEvent() {
        guard let data = userDefaults.data(forKey: currentJoinedEventKey),
              let event = try? JSONDecoder().decode(CrowdEvent.self, from: data) else {
            currentJoinedEvent = nil
            return
        }
        
        // Check if event has finished (immediately when end time is reached)
        let now = Date()
        
        let eventHasFinished: Bool
        if let time = event.time {
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            eventHasFinished = time < fourHoursAgo
        } else {
            eventHasFinished = false
        }
        
        // Check if user is still attending
        let isStillAttending = AttendedEventsService.shared.isAttendingEvent(event.id)
        
        if eventHasFinished || !isStillAttending {
            // Event finished or user left, clear it
            currentJoinedEvent = nil
            print("🧹 Cleared current joined event - finished: \(eventHasFinished), still attending: \(isStillAttending)")
        } else {
            // Restore the event
            currentJoinedEvent = event
            print("✅ Restored current joined event: \(event.title)")
        }
    }
}
