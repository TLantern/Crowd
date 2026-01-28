//
//  AnchorService.swift
//  Crowd
//
//  Service for loading, geocoding, and managing anchor locations
//

import Foundation
import CoreLocation
import MapKit
import FirebaseFirestore
import Combine

final class AnchorService: ObservableObject {
    static let shared = AnchorService()
    
    @Published private(set) var anchors: [Anchor] = []
    @Published private(set) var activeAnchors: [Anchor] = []
    
    private let db = FirebaseManager.shared.db
    private var coordinateCache: [String: CLLocationCoordinate2D] = [:]
    private let fallbackCoord = CLLocationCoordinate2D(latitude: 33.2100, longitude: -97.1500)
    private var anchorsListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Load Anchors
    
    func loadAnchors() async {
        // Load from local JSON ONLY (fast, deterministic, works offline)
        if let localAnchors = await loadAnchorsFromJSON() {
            await MainActor.run {
                self.anchors = localAnchors
            }
            await geocodeAnchors()
            await updateActiveAnchors()
            
            print("✅ AnchorService: Loaded \(localAnchors.count) anchors from JSON only")
        } else {
            print("❌ AnchorService: Failed to load anchors from JSON")
        }
    }
    
    private func loadAnchorsFromJSON() async -> [Anchor]? {
        // Try multiple paths for the JSON file
        var url: URL?
        
        // Try with subdirectory first
        url = Bundle.main.url(forResource: "Anchors", withExtension: "json", subdirectory: "Config")
        
        // Fallback: try without subdirectory
        if url == nil {
            url = Bundle.main.url(forResource: "Anchors", withExtension: "json")
        }
        
        // Fallback: try in main bundle root
        if url == nil {
            url = Bundle.main.url(forResource: "Config/Anchors", withExtension: "json")
        }
        
        guard let jsonURL = url,
              let data = try? Data(contentsOf: jsonURL) else {
            print("⚠️ AnchorService: Could not load Anchors.json from bundle")
            print("   Tried: Config/Anchors.json, Anchors.json, Config/Anchors.json")
            return nil
        }
        
        do {
            let config = try JSONDecoder().decode(AnchorsConfig.self, from: data)
            print("✅ AnchorService: Loaded \(config.anchors.count) anchors from JSON at \(jsonURL.lastPathComponent)")
            return config.anchors
        } catch {
            print("❌ AnchorService: Failed to decode Anchors.json - \(error)")
            return nil
        }
    }
    
    private func loadAnchorsFromFirebase() async -> [Anchor] {
        do {
            let snapshot = try await db.collection("anchors").getDocuments()
            var firebaseAnchors: [Anchor] = []
            
            for document in snapshot.documents {
                let data = document.data()
                if let anchor = try? parseAnchor(from: data) {
                    firebaseAnchors.append(anchor)
                }
            }
            
            await MainActor.run {
                self.anchors = firebaseAnchors
            }
            
            print("✅ AnchorService: Loaded \(firebaseAnchors.count) anchors from Firebase")
            return firebaseAnchors
        } catch {
            print("❌ AnchorService: Failed to load anchors from Firebase - \(error)")
            return []
        }
    }
    
    private func parseAnchor(from data: [String: Any]) throws -> Anchor {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let emoji = data["emoji"] as? String,
              let location = data["location"] as? String,
              let type = data["type"] as? String,
              let daysActive = data["days_active"] as? [String],
              let anchorStartLocal = data["anchor_start_local"] as? String,
              let anchorEndLocal = data["anchor_end_local"] as? String,
              let sendNotification = data["send_notification"] as? Bool,
              let description = data["description"] as? String else {
            throw NSError(domain: "AnchorService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required fields"])
        }
        
        let notificationTimeLocal = data["notification_time_local"] as? String
        let notificationMessage = data["notification_message"] as? String
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        
        var anchor = Anchor(
            id: id,
            name: name,
            emoji: emoji,
            location: location,
            type: type,
            daysActive: daysActive,
            anchorStartLocal: anchorStartLocal,
            anchorEndLocal: anchorEndLocal,
            sendNotification: sendNotification,
            notificationTimeLocal: notificationTimeLocal,
            notificationMessage: notificationMessage,
            description: description,
            latitude: latitude,
            longitude: longitude
        )
        
        return anchor
    }
    
    // MARK: - Geocoding
    
    private func geocodeAnchors() async {
        var updates: [(Int, CLLocationCoordinate2D)] = []
        
        print("🔍 AnchorService: Starting geocoding for \(anchors.count) anchors")
        
        for (index, anchor) in anchors.enumerated() {
            // Skip if already geocoded
            if anchor.latitude != nil && anchor.longitude != nil {
                print("   ✓ \(anchor.name) already has coordinates: (\(anchor.latitude!), \(anchor.longitude!))")
                continue
            }
            
            // Check cache first
            if let cached = coordinateCache[anchor.location] {
                print("   ✓ \(anchor.name) found in cache: (\(cached.latitude), \(cached.longitude))")
                updates.append((index, cached))
                continue
            }
            
            // Try predefined UNT locations first
            if let predefined = matchUNTLocationCoordinate(for: anchor.location) {
                print("   ✓ \(anchor.name) matched predefined location: \(predefined.latitude), \(predefined.longitude)")
                coordinateCache[anchor.location] = predefined
                updates.append((index, predefined))
                continue
            }
            
            print("   ⚠️ \(anchor.name) not found in predefined locations, trying Apple Maps...")
            // Fallback to Apple Maps search
            if let geocoded = await searchLocationOnAppleMaps(anchor.location) {
                print("   ✓ \(anchor.name) geocoded via Apple Maps: \(geocoded.latitude), \(geocoded.longitude)")
                coordinateCache[anchor.location] = geocoded
                updates.append((index, geocoded))
            } else {
                // Use fallback coordinate
                print("   ⚠️ \(anchor.name) geocoding failed, using fallback coordinate")
                coordinateCache[anchor.location] = fallbackCoord
                updates.append((index, fallbackCoord))
            }
        }
        
        print("🔍 AnchorService: Geocoded \(updates.count) anchors")
        
        // Apply coordinate updates
        await MainActor.run {
            for (index, coord) in updates {
                if index < self.anchors.count {
                    self.anchors[index].updateCoordinates(coord)
                }
            }
        }
    }
    
    private func searchLocationOnAppleMaps(_ locationName: String) async -> CLLocationCoordinate2D? {
        let trimmed = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let req = MKLocalSearch.Request()
        let query: String = (
            trimmed.contains("DATCU") || trimmed.contains("Stadium") || trimmed.contains("Square")
        ) ? "\(trimmed), Denton, TX" : "\(trimmed), UNT, Denton, TX 76203"
        
        req.naturalLanguageQuery = query
        req.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.210081, longitude: -97.147700),
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )
        
        do {
            let resp = try await MKLocalSearch(request: req).start()
            guard let item = resp.mapItems.first else { return nil }
            return item.placemark.coordinate
        } catch {
            print("⚠️ AnchorService: Geocoding failed for \(locationName) - \(error)")
            return nil
        }
    }
    
    // MARK: - Sync with Firebase
    
    private func syncWithFirebase() async {
        // Upload anchors with geocoded coordinates to Firebase as backup
        for anchor in anchors {
            guard let lat = anchor.latitude, let lon = anchor.longitude else { continue }
            
            let data: [String: Any] = [
                "id": anchor.id,
                "name": anchor.name,
                "emoji": anchor.emoji,
                "location": anchor.location,
                "type": anchor.type,
                "days_active": anchor.daysActive,
                "anchor_start_local": anchor.anchorStartLocal,
                "anchor_end_local": anchor.anchorEndLocal,
                "send_notification": anchor.sendNotification,
                "notification_time_local": anchor.notificationTimeLocal as Any,
                "notification_message": anchor.notificationMessage as Any,
                "description": anchor.description,
                "latitude": lat,
                "longitude": lon,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            do {
                try await db.collection("anchors").document(anchor.id).setData(data, merge: true)
            } catch {
                print("⚠️ AnchorService: Failed to sync anchor \(anchor.id) to Firebase - \(error)")
            }
        }
    }
    
    // MARK: - Active Anchors
    
    func updateActiveAnchors() async {
        await MainActor.run {
            let allAnchorsWithCoords = self.anchors.filter { $0.coordinates != nil }
            
            let active = allAnchorsWithCoords.filter { $0.isActive }
            
            print("📍 AnchorService: Total anchors: \(self.anchors.count)")
            print("📍 AnchorService: Anchors with coordinates: \(allAnchorsWithCoords.count)")
            print("📍 AnchorService: Active anchors: \(active.count)")
            for anchor in active {
                print("   - \(anchor.name) at \(anchor.location)")
            }
            
            self.activeAnchors = active
        }
    }
    
    // MARK: - Timer for periodic updates
    
    func startPeriodicUpdates() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateActiveAnchors()
            }
        }
        
        // Schedule notifications when anchors are loaded
        Task {
            await AnchorNotificationService.shared.scheduleNotifications(for: anchors)
        }
    }
    
    // MARK: - Firebase Listener
    
    private func setupFirebaseListener() {
        // Remove existing listener if any
        anchorsListener?.remove()
        
        // Set up real-time listener for anchor changes
        anchorsListener = db.collection("anchors").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ AnchorService: Firebase listener error - \(error)")
                return
            }
            
            guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                print("⚠️ AnchorService: Firebase listener returned empty snapshot")
                return
            }
            
            Task {
                var updatedAnchors: [Anchor] = []
                
                for document in snapshot.documents {
                    let data = document.data()
                    if let anchor = try? self.parseAnchor(from: data) {
                        updatedAnchors.append(anchor)
                    }
                }
                
                if !updatedAnchors.isEmpty {
                    await MainActor.run {
                        self.anchors = updatedAnchors
                    }
                    
                    print("✅ AnchorService: Updated \(updatedAnchors.count) anchors from Firebase listener")
                    await self.geocodeAnchors()
                    await self.updateActiveAnchors()
                }
            }
        }
    }
    
    func stopListening() {
        anchorsListener?.remove()
        anchorsListener = nil
    }
    
    // MARK: - Reload anchors (useful for testing or manual refresh)
    
    func reloadAnchors() async {
        await loadAnchors()
    }
}

