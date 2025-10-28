//
//  FirebaseEventRepository.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseFunctions

final class FirebaseEventRepository: EventRepository {
    private let db: Firestore
    private let functions: Functions
    private let firebase = FirebaseManager.shared
    
    init() {
        self.db = FirebaseManager.shared.db
        self.functions = FirebaseManager.shared.functions
    }
    
    // MARK: - EventRepository Protocol
    
    func fetchEvents(in region: CampusRegion) async throws -> [CrowdEvent] {
        let center = region.spec.center
        
        // Call Cloud Function to get events in region
        let data: [String: Any] = [
            "latitude": center.latitude,
            "longitude": center.longitude,
            "radiusKm": region.spec.distance / 1000.0 // Convert meters to km
        ]
        
        let callable = functions.httpsCallable("getEventsInRegion")
        let result = try await callable.call(data)
        
        guard let response = result.data as? [String: Any],
              let eventsData = response["events"] as? [[String: Any]] else {
            return []
        }
        
        return eventsData.compactMap { eventDict -> CrowdEvent? in
            try? parseEvent(from: eventDict)
        }
    }
    
    func create(event: CrowdEvent) async throws {
        // Calculate geohash for proximity queries
        let coordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
        let geohash = coordinate.geohash(precision: 6)
        
        let data: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "latitude": event.latitude,
            "longitude": event.longitude,
            "radiusMeters": event.radiusMeters,
            "startsAt": event.startsAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "endsAt": event.endsAt?.timeIntervalSince1970,
            "tags": event.tags,
            "category": event.category ?? "hangout",
            "geohash": geohash,
            "hostId": event.hostId,
            "hostName": event.hostName,
            "description": event.description ?? ""
        ]
        
        print("📝 Creating event with geohash: \(geohash)")
        
        let callable = functions.httpsCallable("createEvent")
        _ = try await callable.call(data)
    }
    
    func join(eventId: String, userId: String) async throws {
        // Get user's current location
        guard let location = await AppEnvironment.current.locationService.lastKnown else {
            throw CrowdError.custom("Location not available. Please enable location services.")
        }
        
        // Create a signal for the event with user's location
        let data: [String: Any] = [
            "eventId": eventId,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "signalStrength": 3 // Default signal strength
        ]
        
        let callable = functions.httpsCallable("createSignal")
        _ = try await callable.call(data)
        
        print("✅ Joined event \(eventId) at location (\(location.latitude), \(location.longitude))")
    }
    
    func deleteEvent(eventId: String) async throws {
        let callable = functions.httpsCallable("deleteEvent")
        let data: [String: Any] = ["id": eventId]
        
        let result = try await callable.call(data)
        
        guard let response = result.data as? [String: Any],
              let success = response["success"] as? Bool,
              success else {
            throw CrowdError.invalidResponse
        }
        
        print("✅ Event deleted: \(eventId)")
    }
    
    func boostSignal(eventId: String, delta: Int) async throws {
        // Get current user's signal for this event
        let signalsSnapshot = try await db.collection("signals")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: firebase.getCurrentUserId() ?? "")
            .getDocuments()
        
        guard let signalDoc = signalsSnapshot.documents.first else {
            throw CrowdError.notFound
        }
        
        let currentStrength = signalDoc.data()["signalStrength"] as? Int ?? 1
        let newStrength = max(1, min(5, currentStrength + delta))
        
        let data: [String: Any] = [
            "id": signalDoc.documentID,
            "signalStrength": newStrength
        ]
        
        let callable = functions.httpsCallable("updateSignal")
        _ = try await callable.call(data)
    }
    
    // MARK: - Real-time Listeners
    
    func listenToEvents(in region: CampusRegion, onChange: @escaping ([CrowdEvent]) -> Void) {
        // Use geohash-based query for efficient spatial filtering
        let center = region.spec.center
        let radiusKm = region.spec.distance / 1000.0
        
        // Calculate geohash prefix for the region
        // For simplicity, we'll use a 4-character prefix (~39km × 19.5km)
        // This is a rough approximation - in production, use the geohash utility
        let geohashPrefix = String(encodeGeohash(lat: center.latitude, lon: center.longitude).prefix(4))
        
        print("🔄 Setting up real-time listener for region: \(region.rawValue) with geohash prefix: \(geohashPrefix)")
        
        db.collection("events")
            .whereField("geohash", isGreaterThanOrEqualTo: geohashPrefix)
            .whereField("geohash", isLessThanOrEqualTo: geohashPrefix + "\u{f8ff}")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("❌ Error fetching events: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                let events = documents.compactMap { doc -> CrowdEvent? in
                    guard let event = try? self.parseEvent(from: doc.data()) else {
                        return nil
                    }
                    
                    // Filter by exact distance
                    let distance = self.calculateDistance(
                        from: center,
                        to: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
                    )
                    
                    return distance <= radiusKm ? event : nil
                }
                
                print("🔄 Real-time update: \(events.count) events in region")
                onChange(events)
            }
    }
    
    // Simple geohash encoder (6-character precision)
    private func encodeGeohash(lat: Double, lon: Double) -> String {
        let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var bit = 0
        var ch = 0
        
        while geohash.count < 6 {
            if bit % 2 == 0 {
                let mid = (lonRange.0 + lonRange.1) / 2
                if lon > mid {
                    ch |= (1 << (4 - (bit / 2)))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if lat > mid {
                    ch |= (1 << (4 - (bit / 2)))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            
            bit += 1
            if bit == 10 {
                geohash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        
        return geohash
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let locationFrom = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let locationTo = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return locationFrom.distance(from: locationTo) / 1000.0 // Convert to km
    }
    
    // MARK: - Helpers
    
    private func parseEvent(from data: [String: Any]) throws -> CrowdEvent {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String,
              let lat = data["latitude"] as? Double,
              let lon = data["longitude"] as? Double,
              let radiusMeters = data["radiusMeters"] as? Double else {
            throw CrowdError.invalidResponse
        }
        
        let signalStrength = data["signalStrength"] as? Int ?? 0
        let attendeeCount = data["attendeeCount"] as? Int ?? 0
        let hostId = data["hostId"] as? String ?? ""
        let hostName = data["hostName"] as? String ?? "Guest"
        
        // Parse timestamps
        var startsAt: Date?
        var endsAt: Date?
        
        if let timestamp = data["startsAt"] as? Timestamp {
            startsAt = timestamp.dateValue()
        } else if let seconds = data["startsAt"] as? TimeInterval {
            startsAt = Date(timeIntervalSince1970: seconds)
        }
        
        if let timestamp = data["endsAt"] as? Timestamp {
            endsAt = timestamp.dateValue()
        } else if let seconds = data["endsAt"] as? TimeInterval {
            endsAt = Date(timeIntervalSince1970: seconds)
        }
        
        // Parse tags
        let tags = data["tags"] as? [String] ?? []
        
        // Parse createdAt
        var createdAt = Date()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let seconds = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: seconds)
        }
        
        return CrowdEvent(
            id: id,
            title: title,
            hostId: hostId,
            hostName: hostName,
            latitude: lat,
            longitude: lon,
            radiusMeters: radiusMeters,
            startsAt: startsAt,
            endsAt: endsAt,
            createdAt: createdAt,
            signalStrength: signalStrength,
            attendeeCount: attendeeCount,
            tags: tags
        )
    }
}
