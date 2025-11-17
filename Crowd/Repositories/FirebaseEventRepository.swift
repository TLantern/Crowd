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
        let radiusKm = region.spec.distance / 1000.0
        
        print("📍 Fetching events from both 'events' and 'userEvents' collections")
        
        var allEvents: [CrowdEvent] = []
        
        // Fetch from official 'events' collection (Firebase-generated/scraped events)
        let eventsSnapshot = try await db.collection("events").getDocuments()
        for document in eventsSnapshot.documents {
            if let event = try? parseEvent(from: document.data()) {
                let distance = calculateDistance(from: center, to: event.coordinates)
                if distance <= radiusKm {
                    allEvents.append(event)
                }
            }
        }
        
        // Fetch from 'userEvents' collection (user-created events)
        let userEventsSnapshot = try await db.collection("userEvents").getDocuments()
        for document in userEventsSnapshot.documents {
            if let event = try? parseEvent(from: document.data()) {
                let distance = calculateDistance(from: center, to: event.coordinates)
                if distance <= radiusKm {
                    allEvents.append(event)
                }
            }
        }
        
        print("✅ Fetched \(allEvents.count) total events (\(eventsSnapshot.documents.count) official + \(userEventsSnapshot.documents.count) user)")
        
        return allEvents
    }
    
    /// Fetch events separated by source (official vs user-created)
    func fetchEventsSeparately(in region: CampusRegion) async throws -> (official: [CrowdEvent], userCreated: [CrowdEvent]) {
        let center = region.spec.center
        let radiusKm = region.spec.distance / 1000.0
        
        print("📍 Fetching events separately from 'events' and 'userEvents' collections")
        
        var officialEvents: [CrowdEvent] = []
        var userCreatedEvents: [CrowdEvent] = []
        
        // Fetch from official 'events' collection (Firebase-generated/scraped events)
        let eventsSnapshot = try await db.collection("events").getDocuments()
        for document in eventsSnapshot.documents {
            if let event = try? parseEvent(from: document.data()) {
                let distance = calculateDistance(from: center, to: event.coordinates)
                if distance <= radiusKm {
                    officialEvents.append(event)
                }
            }
        }
        
        // Fetch from 'userEvents' collection (user-created events)
        let userEventsSnapshot = try await db.collection("userEvents").getDocuments()
        for document in userEventsSnapshot.documents {
            if let event = try? parseEvent(from: document.data()) {
                let distance = calculateDistance(from: center, to: event.coordinates)
                if distance <= radiusKm {
                    userCreatedEvents.append(event)
                }
            }
        }
        
        print("✅ Fetched \(officialEvents.count) official events and \(userCreatedEvents.count) user-created events")
        
        return (official: officialEvents, userCreated: userCreatedEvents)
    }
    
    func create(event: CrowdEvent) async throws {
        // Check authentication status before attempting creation
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId() else {
            print("❌ No authenticated user - cannot create event")
            throw CrowdError.custom("User not authenticated")
        }
        
        print("🔍 Creating event with user ID: \(currentUserId)")
        print("🔍 Event host ID: \(event.hostId)")
        print("🔍 User authenticated: \(currentUserId == event.hostId)")
        
        // Calculate geohash for proximity queries
        let coordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
        let geohash = coordinate.geohash(precision: 6)
        
        // Ensure tags and category are never missing before saving
        let finalCategory = event.category ?? EventCategory.other.rawValue
        var finalTags = event.tags
        if finalTags.isEmpty {
            if let cat = EventCategory(rawValue: finalCategory) {
                finalTags = [cat.defaultTag]
            } else {
                finalTags = [EventCategory.other.defaultTag]
            }
        }
        
        let data: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "latitude": event.latitude,
            "longitude": event.longitude,
            "radiusMeters": event.radiusMeters,
            "startsAt": event.startsAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "endsAt": event.endsAt?.timeIntervalSince1970,
            "tags": finalTags,
            "category": finalCategory,
            "geohash": geohash,
            "hostId": event.hostId,
            "hostName": event.hostName,
            "description": event.description ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "attendeeCount": 0,
            "signalStrength": 1
        ]
        
        print("📝 Creating user event in userEvents collection with geohash: \(geohash)")
        print("📝 Data being sent: \(data)")
        
        // Save directly to Firestore userEvents collection (no Cloud Function needed)
        try await db.collection("userEvents").document(event.id).setData(data)
        
        print("✅ Event created in userEvents: \(event.id)")
    }
    
    func join(eventId: String, userId: String) async throws {
        print("🔍 FirebaseEventRepository: Attempting to join event \(eventId) for user \(userId)")
        
        // Try to get user's current location, but do not fail if unavailable
        let location = await AppEnvironment.current.location.lastKnown
        if let loc = location {
            print("📍 FirebaseEventRepository: User location: (\(loc.latitude), \(loc.longitude))")
        } else {
            print("⚠️ FirebaseEventRepository: Proceeding without location — joining should not be blocked")
        }
        
        // Check if user already has a signal for this event
        let existingSignalQuery = try await db.collection("signals")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        if !existingSignalQuery.documents.isEmpty {
            print("⚠️ User \(userId) already has a signal for event \(eventId)")
            return // Already joined, no error
        }
        
        // Check if event exists in either collection
        let eventDoc = try await db.collection("events").document(eventId).getDocument()
        let userEventDoc = try await db.collection("userEvents").document(eventId).getDocument()
        
        guard eventDoc.exists || userEventDoc.exists else {
            print("❌ Event \(eventId) not found")
            throw CrowdError.custom("Event not found")
        }
        
        // Create signal document directly in Firestore (latitude/longitude optional)
        var signalData: [String: Any] = [
            "eventId": eventId,
            "userId": userId,
            "signalStrength": 3,
            "createdAt": FieldValue.serverTimestamp(),
            "lastSeenAt": FieldValue.serverTimestamp()
        ]
        if let loc = location {
            signalData["latitude"] = loc.latitude
            signalData["longitude"] = loc.longitude
        }
        
        print("📡 FirebaseEventRepository: Creating signal in Firestore")
        
        do {
            // Add signal to signals collection
            let signalRef = db.collection("signals").document()
            try await signalRef.setData(signalData)
            
            // Update event attendee count
            let eventRef = eventDoc.exists ? db.collection("events").document(eventId) : db.collection("userEvents").document(eventId)
            try await eventRef.updateData([
                "attendeeCount": FieldValue.increment(Int64(1)),
                "signalStrength": FieldValue.increment(Int64(3))
            ])
            
            if let loc = location {
                print("✅ FirebaseEventRepository: Successfully joined event \(eventId) at location (\(loc.latitude), \(loc.longitude))")
            } else {
                print("✅ FirebaseEventRepository: Successfully joined event \(eventId) without location")
            }
        } catch {
            print("❌ FirebaseEventRepository: Failed to create signal - \(error.localizedDescription)")
            throw error
        }
    }
    
    func leave(eventId: String, userId: String) async throws {
        print("🔍 FirebaseEventRepository: Attempting to leave event \(eventId) for user \(userId)")
        
        // Find user's signal for this event
        let signalsSnapshot = try await db.collection("signals")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        guard !signalsSnapshot.documents.isEmpty else {
            print("⚠️ User \(userId) has no signal for event \(eventId)")
            return // Not joined, no error
        }
        
        // Get signal strength before deletion
        let signalDoc = signalsSnapshot.documents.first!
        let signalStrength = signalDoc.data()["signalStrength"] as? Int ?? 3
        
        // Delete signal document
        try await signalDoc.reference.delete()
        print("✅ Deleted signal document: \(signalDoc.documentID)")
        
        // Check which collection the event is in
        let eventDoc = try await db.collection("events").document(eventId).getDocument()
        let userEventDoc = try await db.collection("userEvents").document(eventId).getDocument()
        
        guard eventDoc.exists || userEventDoc.exists else {
            print("⚠️ Event \(eventId) not found, but signal was deleted")
            return // Signal deleted, event might have been deleted
        }
        
        // Decrement event attendeeCount and signalStrength
        let eventRef = eventDoc.exists ? db.collection("events").document(eventId) : db.collection("userEvents").document(eventId)
        try await eventRef.updateData([
            "attendeeCount": FieldValue.increment(Int64(-1)),
            "signalStrength": FieldValue.increment(Int64(-signalStrength))
        ])
        
        print("✅ Successfully left event \(eventId), decremented attendeeCount and signalStrength")
    }
    
    func deleteEvent(eventId: String) async throws {
        print("🗑️ Deleting event from userEvents: \(eventId)")
        
        // Check authentication status before attempting deletion
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId() else {
            print("❌ No authenticated user - cannot delete event")
            throw CrowdError.custom("User not authenticated")
        }
        
        print("🔍 Current user ID: \(currentUserId)")
        
        // First, get the event to verify ownership
        let eventDoc = try await db.collection("userEvents").document(eventId).getDocument()
        
        guard eventDoc.exists else {
            print("❌ Event not found: \(eventId)")
            throw CrowdError.custom("Event not found")
        }
        
        let eventData = eventDoc.data() ?? [:]
        let eventHostId = eventData["hostId"] as? String ?? ""
        
        print("🔍 Event host ID: \(eventHostId)")
        
        guard eventHostId == currentUserId else {
            print("❌ User (\(currentUserId)) is not the host (\(eventHostId)) of event \(eventId)")
            throw CrowdError.custom("Only the event host can delete this event")
        }
        
        // Delete directly from Firestore userEvents collection
        try await db.collection("userEvents").document(eventId).delete()
        
        // Also delete any associated signals
        let signalsSnapshot = try await db.collection("signals")
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()
        
        // Delete all signals for this event
        for document in signalsSnapshot.documents {
            try await document.reference.delete()
        }
        
        print("✅ Event deleted from userEvents: \(eventId) (and \(signalsSnapshot.documents.count) signals)")
    }
    
    /// Delete expired events from both collections
    func deleteExpiredEvents() async throws {
        let now = Date()
        let nowSeconds = now.timeIntervalSince1970
        
        print("🧹 Starting cleanup of expired events...")
        
        var deletedCount = 0
        
        // Delete expired events from 'events' collection
        // Get all events and filter by endsAt (handles both Timestamp and TimeInterval formats)
        do {
            let allEvents = try await db.collection("events")
                .limit(to: 500)
                .getDocuments()
            
            let expiredEvents = allEvents.documents.filter { doc in
                let data = doc.data()
                guard let endsAtValue = data["endsAt"] else { return false }
                
                if let timestamp = endsAtValue as? Timestamp {
                    return timestamp.dateValue() <= now
                } else if let seconds = endsAtValue as? TimeInterval {
                    return seconds <= nowSeconds
                } else if let seconds = endsAtValue as? Double {
                    return seconds <= nowSeconds
                }
                return false
            }
            
            for document in expiredEvents {
                let eventId = document.documentID
                
                // Delete all signals for this event first
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                let batch = db.batch()
                for signalDoc in signalsSnapshot.documents {
                    batch.deleteDocument(signalDoc.reference)
                }
                
                // Delete all attendances for this event
                let attendancesSnapshot = try await db.collection("userAttendances")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                for attendanceDoc in attendancesSnapshot.documents {
                    batch.deleteDocument(attendanceDoc.reference)
                }
                
                // Delete the event document
                batch.deleteDocument(document.reference)
                
                try await batch.commit()
                deletedCount += 1
                print("✅ Deleted expired event \(eventId) from 'events' collection")
            }
        } catch {
            print("⚠️ Error deleting expired events from 'events' collection: \(error.localizedDescription)")
        }
        
        // Delete expired events from 'userEvents' collection
        do {
            let allUserEvents = try await db.collection("userEvents")
                .limit(to: 500)
                .getDocuments()
            
            let expiredUserEvents = allUserEvents.documents.filter { doc in
                let data = doc.data()
                guard let endsAtValue = data["endsAt"] else { return false }
                
                if let timestamp = endsAtValue as? Timestamp {
                    return timestamp.dateValue() <= now
                } else if let seconds = endsAtValue as? TimeInterval {
                    return seconds <= nowSeconds
                } else if let seconds = endsAtValue as? Double {
                    return seconds <= nowSeconds
                }
                return false
            }
            
            for document in expiredUserEvents {
                let eventId = document.documentID
                
                // Delete all signals for this event first
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                let batch = db.batch()
                for signalDoc in signalsSnapshot.documents {
                    batch.deleteDocument(signalDoc.reference)
                }
                
                // Delete all attendances for this event
                let attendancesSnapshot = try await db.collection("userAttendances")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                for attendanceDoc in attendancesSnapshot.documents {
                    batch.deleteDocument(attendanceDoc.reference)
                }
                
                // Delete the event document
                batch.deleteDocument(document.reference)
                
                try await batch.commit()
                deletedCount += 1
                print("✅ Deleted expired event \(eventId) from 'userEvents' collection")
            }
        } catch {
            print("⚠️ Error deleting expired events from 'userEvents' collection: \(error.localizedDescription)")
        }
        
        // Also handle events without endsAt that started more than 4 hours ago
        let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
        let fourHoursAgoSeconds = fourHoursAgo.timeIntervalSince1970
        
        // Check events collection for events without endsAt
        do {
            let allEventsWithoutEndTime = try await db.collection("events")
                .limit(to: 500)
                .getDocuments()
            
            let eventsWithoutEndTime = allEventsWithoutEndTime.documents.filter { doc in
                let data = doc.data()
                guard data["endsAt"] == nil else { return false }
                
                // Check if startsAt is more than 4 hours ago
                if let timestamp = data["startsAt"] as? Timestamp {
                    return timestamp.dateValue() <= fourHoursAgo
                } else if let seconds = data["startsAt"] as? TimeInterval {
                    return seconds <= fourHoursAgoSeconds
                } else if let seconds = data["startsAt"] as? Double {
                    return seconds <= fourHoursAgoSeconds
                }
                return false
            }
            
            for document in eventsWithoutEndTime {
                let eventId = document.documentID
                
                // Delete associated data
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                let batch = db.batch()
                for signalDoc in signalsSnapshot.documents {
                    batch.deleteDocument(signalDoc.reference)
                }
                
                let attendancesSnapshot = try await db.collection("userAttendances")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                for attendanceDoc in attendancesSnapshot.documents {
                    batch.deleteDocument(attendanceDoc.reference)
                }
                
                batch.deleteDocument(document.reference)
                try await batch.commit()
                deletedCount += 1
                print("✅ Deleted old event without end time \(eventId) from 'events' collection")
            }
        } catch {
            print("⚠️ Error deleting old events without end time: \(error.localizedDescription)")
        }
        
        // Check userEvents collection for events without endsAt
        do {
            let allUserEventsWithoutEndTime = try await db.collection("userEvents")
                .limit(to: 500)
                .getDocuments()
            
            let userEventsWithoutEndTime = allUserEventsWithoutEndTime.documents.filter { doc in
                let data = doc.data()
                guard data["endsAt"] == nil else { return false }
                
                // Check if startsAt is more than 4 hours ago
                if let timestamp = data["startsAt"] as? Timestamp {
                    return timestamp.dateValue() <= fourHoursAgo
                } else if let seconds = data["startsAt"] as? TimeInterval {
                    return seconds <= fourHoursAgoSeconds
                } else if let seconds = data["startsAt"] as? Double {
                    return seconds <= fourHoursAgoSeconds
                }
                return false
            }
            
            for document in userEventsWithoutEndTime {
                let eventId = document.documentID
                
                // Delete associated data
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                let batch = db.batch()
                for signalDoc in signalsSnapshot.documents {
                    batch.deleteDocument(signalDoc.reference)
                }
                
                let attendancesSnapshot = try await db.collection("userAttendances")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                for attendanceDoc in attendancesSnapshot.documents {
                    batch.deleteDocument(attendanceDoc.reference)
                }
                
                batch.deleteDocument(document.reference)
                try await batch.commit()
                deletedCount += 1
                print("✅ Deleted old event without end time \(eventId) from 'userEvents' collection")
            }
        } catch {
            print("⚠️ Error deleting old user events without end time: \(error.localizedDescription)")
        }
        
        print("✅ Cleanup complete: Deleted \(deletedCount) expired events from database")
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
        
        // Track analytics
        AnalyticsService.shared.trackSignalBoosted(
            eventId: eventId,
            oldStrength: currentStrength,
            newStrength: newStrength
        )
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
    
    func parseEvent(from data: [String: Any]) throws -> CrowdEvent {
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
        
        // Parse tags - ensure never empty
        var tags = data["tags"] as? [String] ?? []
        
        // Parse category - ensure never nil
        var category = data["category"] as? String ?? EventCategory.other.rawValue
        
        // If tags are empty but category exists, generate tags from category
        if tags.isEmpty {
            if let cat = EventCategory(rawValue: category) {
                tags = [cat.defaultTag]
            } else {
                tags = [EventCategory.other.defaultTag]
                category = EventCategory.other.rawValue
            }
        }
        
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
            tags: tags,
            category: category
        )
    }
}
