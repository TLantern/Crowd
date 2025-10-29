//
//  PresenceService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation
import FirebaseFunctions
import FirebaseFirestore

actor PresenceService {
    private let functions: Functions
    private var heartbeatTask: Task<Void, Never>?
    
    init() {
        self.functions = FirebaseManager.shared.functions
    }
    
    /// Send a location heartbeat to the backend
    func heartbeat(userId: String, at coordinate: CLLocationCoordinate2D) async {
        // For now, we'll use the presence collection in Firestore
        // This can be used to show real-time user locations
        let db = await FirebaseManager.shared.db
        
        let data: [String: Any] = [
            "userId": userId,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try await db.collection("presence").document(userId).setData(data, merge: true)
            print("💓 Heartbeat sent for user \(userId)")
        } catch {
            print("❌ Failed to send heartbeat: \(error)")
        }
    }
    
    /// Start sending periodic heartbeats
    func startHeartbeat(userId: String, locationService: LocationService) {
        // Cancel any existing heartbeat task
        heartbeatTask?.cancel()
        
        heartbeatTask = Task {
            while !Task.isCancelled {
                if let location = await locationService.lastKnown {
                    await heartbeat(userId: userId, at: location)
                }
                
                // Send heartbeat every 30 seconds
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        
        print("💓 Started heartbeat service for user \(userId)")
    }
    
    /// Stop sending heartbeats
    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        print("💓 Stopped heartbeat service")
    }
    
    /// Get density of people near a location using signals
    func density(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async -> Int {
        let radiusKm = radiusMeters / 1000.0
        
        let data: [String: Any] = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "radiusKm": radiusKm
        ]
        
        do {
            let callable = functions.httpsCallable("getNearbySignals")
            let result = try await callable.call(data)
            
            if let response = result.data as? [String: Any],
               let count = response["count"] as? Int {
                return count
            }
            
            return 0
        } catch {
            print("❌ Failed to get density: \(error)")
            return 0
        }
    }
}
