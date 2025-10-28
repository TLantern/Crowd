//
//  MockDataUploader.swift
//  Crowd
//
//  Utility to upload mock events to Firebase (one-time setup)
//

import Foundation
import FirebaseFirestore

final class MockDataUploader {
    static let shared = MockDataUploader()
    private let db = FirebaseManager.shared.db
    
    private init() {}
    
    /// Upload mock events to Firebase (run this once)
    func uploadMockEventsToFirebase() async throws {
        print("📤 Starting mock event upload to Firebase...")
        
        let mockEvents = PrevData.events
        var successCount = 0
        var failureCount = 0
        
        for event in mockEvents {
            do {
                try await uploadEvent(event)
                successCount += 1
                print("✅ Uploaded: \(event.title)")
            } catch {
                failureCount += 1
                print("❌ Failed to upload \(event.title): \(error.localizedDescription)")
            }
        }
        
        print("📊 Upload complete: \(successCount) succeeded, \(failureCount) failed")
    }
    
    private func uploadEvent(_ event: CrowdEvent) async throws {
        // Calculate geohash for the event
        let coordinate = event.coordinates
        let geohash = coordinate.geohash(precision: 6)
        
        let eventData: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "hostId": event.hostId,
            "hostName": event.hostName,
            "latitude": event.latitude,
            "longitude": event.longitude,
            "location": GeoPoint(latitude: event.latitude, longitude: event.longitude),
            "geohash": geohash,
            "radiusMeters": event.radiusMeters,
            "startsAt": event.startsAt != nil ? Timestamp(date: event.startsAt!) : Timestamp(date: Date()),
            "endsAt": event.endsAt != nil ? Timestamp(date: event.endsAt!) : NSNull(),
            "createdAt": Timestamp(date: event.createdAt),
            "signalStrength": event.signalStrength,
            "attendeeCount": event.attendeeCount,
            "tags": event.tags,
            "category": event.category ?? "hangout",
            "description": event.description ?? "",
            "locationName": extractLocationName(from: event.description)
        ]
        
        try await db.collection("events").document(event.id).setData(eventData, merge: false)
    }
    
    private func extractLocationName(from description: String?) -> String {
        guard let description = description else { return "Unknown Location" }
        
        // Try to extract location from description (format: "📍 Location Name")
        if let locationLine = description.components(separatedBy: "\n").first,
           locationLine.contains("📍") {
            return locationLine.replacingOccurrences(of: "📍", with: "").trimmingCharacters(in: .whitespaces)
        }
        
        return "Unknown Location"
    }
    
    /// Delete all mock events from Firebase (cleanup)
    func deleteMockEventsFromFirebase() async throws {
        print("🗑️ Deleting mock events from Firebase...")
        
        let mockEventIds = PrevData.events.map { $0.id }
        
        for eventId in mockEventIds {
            try await db.collection("events").document(eventId).delete()
            print("✅ Deleted event: \(eventId)")
        }
        
        print("🗑️ All mock events deleted")
    }
    
    /// Check if mock events already exist in Firebase
    func checkIfMockEventsExist() async throws -> Bool {
        let mockEventIds = PrevData.events.map { $0.id }
        
        for eventId in mockEventIds {
            let doc = try await db.collection("events").document(eventId).getDocument()
            if doc.exists {
                print("✅ Found existing mock event: \(eventId)")
                return true
            }
        }
        
        print("❌ No mock events found in Firebase")
        return false
    }
}

// MARK: - Extension for geohash (in case CLLocationCoordinate2D+Geohash.swift is not available on main branch)
import CoreLocation

extension CLLocationCoordinate2D {
    func geohash(precision: Int = 6) -> String {
        let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        var lat = (latitude + 90.0, 0.0, 180.0)
        var lon = (longitude + 180.0, 0.0, 360.0)
        
        var hash = ""
        var isEven = true
        var bits = 0
        var charIndex = 0
        
        while hash.count < precision {
            if isEven {
                let mid = (lon.1 + lon.2) / 2
                if lon.0 >= mid {
                    charIndex |= (1 << (4 - bits))
                    lon.1 = mid
                } else {
                    lon.2 = mid
                }
            } else {
                let mid = (lat.1 + lat.2) / 2
                if lat.0 >= mid {
                    charIndex |= (1 << (4 - bits))
                    lat.1 = mid
                } else {
                    lat.2 = mid
                }
            }
            
            isEven = !isEven
            bits += 1
            
            if bits == 5 {
                let index = base32.index(base32.startIndex, offsetBy: charIndex)
                hash.append(base32[index])
                bits = 0
                charIndex = 0
            }
        }
        
        return hash
    }
}

