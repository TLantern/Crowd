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
    
    /// Fetch parties from events_from_linktree_raw collection
    func fetchParties() async throws -> [CrowdEvent] {
        print("🎉 Fetching parties from events_from_linktree_raw collection")
        
        let partiesSnapshot = try await db.collection("events_from_linktree_raw").getDocuments()
        print("📊 Found \(partiesSnapshot.documents.count) documents in events_from_linktree_raw")
        
        var parties: [CrowdEvent] = []
        var parseErrors = 0
        
        // Get start of today for filtering
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        for document in partiesSnapshot.documents {
            let data = document.data()
            print("📄 Document ID: \(document.documentID)")
            print("📄 Document data keys: \(data.keys.sorted())")
            
            do {
                let party = try await parseParty(from: data, documentId: document.documentID)
                
                // Only include upcoming parties (today or future)
                if let startsAt = party.startsAt {
                    if startsAt >= startOfToday {
                        parties.append(party)
                    } else {
                        print("⏭️ Skipping past party: \(party.title) (date: \(startsAt))")
                    }
                } else {
                    // Include parties without a date (they might be ongoing/TBD)
                    parties.append(party)
                }
            } catch {
                parseErrors += 1
                print("⚠️ Failed to parse party document \(document.documentID): \(error.localizedDescription)")
                print("📄 Data: \(data)")
            }
        }
        
        print("✅ Successfully parsed \(parties.count) upcoming parties, \(parseErrors) failed")
        
        // Trigger background cleanup of expired parties
        Task {
            await deleteExpiredParties()
        }
        
        return parties
    }
    
    /// Parse party from events_from_linktree_raw collection
    /// Fields: address, title, uploadedImageUrl, URL, description (contains date)
    private func parseParty(from data: [String: Any], documentId: String) async throws -> CrowdEvent {
        // Add detailed logging for debugging
        print("📄 Parsing party document: \(documentId)")
        print("📄 Available fields: \(data.keys.sorted())")
        
        // Extract nested dictionaries
        let normalized = data["normalized"] as? [String: Any]
        let eventDetails = data["eventDetails"] as? [String: Any]
        
        // Title - check top level first, then eventDetails
        guard let title = data["title"] as? String ?? eventDetails?["title"] as? String else {
            print("❌ Missing required 'title' field")
            throw CrowdError.invalidResponse
        }
        
        let id = documentId
        
        // Description - Check multiple field name variations (including nested)
        let description = data["description"] as? String ?? 
                         normalized?["description"] as? String ??
                         eventDetails?["description"] as? String ??
                         data["desc"] as? String ?? 
                         data["details"] as? String ?? 
                         data["about"] as? String ?? 
                         data["info"] as? String ?? ""
        print("📄 Description: \(description.isEmpty ? "empty" : String(description.prefix(50)))")
        
        // Address - Check multiple field name variations (including nested)
        var address: String?
        if let addr = data["address"] as? String { address = addr }
        else if let addr = eventDetails?["address"] as? String { address = addr }
        else if let addr = normalized?["address"] as? String { address = addr }
        else if let addr = data["location"] as? String { address = addr }
        else if let addr = eventDetails?["venue"] as? String { address = addr }
        else if let addr = normalized?["locationName"] as? String { address = addr }
        else if let addr = data["venue"] as? String { address = addr }
        else if let addr = data["place"] as? String { address = addr }
        else { address = data["where"] as? String }
        print("📄 Address: \(address ?? "nil")")
        
        // Image URL - Check multiple possible field names (including nested)
        var imageURL: String?
        if let url = data["imageURL"] as? String { imageURL = url }
        else if let url = data["imageUrl"] as? String { imageURL = url }
        else if let url = normalized?["imageUrl"] as? String { imageURL = url }
        else if let url = eventDetails?["imageUrl"] as? String { imageURL = url }
        else if let url = eventDetails?["primaryImage"] as? String { imageURL = url }
        else if let url = data["uploadedImageUrl"] as? String { imageURL = url }
        else if let url = data["image"] as? String { imageURL = url }
        else if let url = data["uploadedImage"] as? String { imageURL = url }
        else if let url = data["flyerUrl"] as? String { imageURL = url }
        else { imageURL = data["flyer"] as? String }
        print("📄 Image URL: \(imageURL ?? "nil")")
        
        // Ticket URL - Check multiple field name variations
        let ticketURL = data["URL"] as? String ?? 
                       data["ticketURL"] as? String ?? 
                       data["ticketUrl"] as? String ??
                       data["link"] as? String ??
                       data["ticketLink"] as? String ??
                       data["eventLink"] as? String ??
                       data["url"] as? String
        print("📄 Ticket URL: \(ticketURL ?? "nil")")
        
        // Check for host/group name in multiple possible field names (including nested)
        var hostName: String = "Party Host"
        if let name = data["hostName"] as? String { hostName = name }
        else if let name = normalized?["locationName"] as? String { hostName = name }
        else if let name = eventDetails?["venue"] as? String { hostName = name }
        else if let name = data["host_name"] as? String { hostName = name }
        else if let name = data["groupName"] as? String { hostName = name }
        else if let name = data["group_name"] as? String { hostName = name }
        else if let name = normalized?["sourceOrg"] as? String { hostName = name }
        else if let name = data["organization"] as? String { hostName = name }
        else if let name = data["org"] as? String { hostName = name }
        else if let name = data["host"] as? String { hostName = name }
        else if let name = data["organizer"] as? String { hostName = name }
        print("📄 Host Name: \(hostName)")
        
        // Try to get date from multiple field name variations
        var startsAt: Date?
        
        // Check dateTime field in various formats
        if let dateTimeString = data["dateTime"] as? String {
            print("📄 Found dateTime string: \(dateTimeString)")
            startsAt = parseDateTimeString(dateTimeString)
        } else if let dateTimeTimestamp = data["dateTime"] as? Timestamp {
            print("📄 Found dateTime timestamp")
            startsAt = dateTimeTimestamp.dateValue()
        } else if let dateTimeSeconds = data["dateTime"] as? TimeInterval {
            print("📄 Found dateTime interval: \(dateTimeSeconds)")
            startsAt = Date(timeIntervalSince1970: dateTimeSeconds)
        } else if let dateTimeMillis = data["dateTime"] as? Double {
            print("📄 Found dateTime double: \(dateTimeMillis)")
            // Try as milliseconds if value is very large
            if dateTimeMillis > 10000000000 {
                startsAt = Date(timeIntervalSince1970: dateTimeMillis / 1000)
            } else {
                startsAt = Date(timeIntervalSince1970: dateTimeMillis)
            }
        }
        
        // Try alternative date field names (including nested)
        if startsAt == nil {
            if let dateString = data["date"] as? String ?? eventDetails?["dateTime"] as? String {
                print("📄 Found date string: \(dateString)")
                startsAt = parseDateTimeString(dateString)
            } else if let timeString = data["time"] as? String {
                print("📄 Found time string: \(timeString)")
                startsAt = parseDateTimeString(timeString)
            } else if let startTimeString = data["startTime"] as? String {
                print("📄 Found startTime string: \(startTimeString)")
                startsAt = parseDateTimeString(startTimeString)
            } else if let eventDateString = data["eventDate"] as? String {
                print("📄 Found eventDate string: \(eventDateString)")
                startsAt = parseDateTimeString(eventDateString)
            } else if let startString = data["start"] as? String {
                print("📄 Found start string: \(startString)")
                startsAt = parseDateTimeString(startString)
            } else if let normalizedStartTime = normalized?["startTimeLocal"] as? String {
                print("📄 Found normalized startTimeLocal: \(normalizedStartTime)")
                startsAt = parseDateTimeString(normalizedStartTime)
            } else if let normalizedStartTimeISO = normalized?["startTimeISO"] as? String {
                print("📄 Found normalized startTimeISO: \(normalizedStartTimeISO)")
                startsAt = parseDateTimeString(normalizedStartTimeISO)
            }
        }
        
        // If no dateTime field, try to extract from description
        if startsAt == nil && !description.isEmpty {
            print("📄 Attempting to extract date from description")
            startsAt = extractDateFromDescription(description)
        }
        
        print("📄 Final parsed date: \(startsAt?.description ?? "nil")")
        
        // Default coordinates (can be geocoded later if needed)
        // Using UNT main campus coordinates as default
        let latitude = 33.210081
        let longitude = -97.147700
        
        // Fetch going count for this party
        let goingCount = try? await getPartyGoingCount(partyId: id)
        
        return CrowdEvent(
            id: id,
            title: title,
            hostId: "",
            hostName: hostName,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: 0,
            startsAt: startsAt,
            endsAt: nil,
            createdAt: Date(),
            signalStrength: 0,
            attendeeCount: goingCount ?? 0,
            tags: ["party"],
            category: "Party",
            description: description,
            sourceURL: nil,
            rawLocationName: address,
            imageURL: imageURL,
            ticketURL: ticketURL
        )
    }
    
    // MARK: - Party "I'm Going" Functions
    
    /// Mark that a user is going to a party
    func markPartyGoing(partyId: String, userId: String) async throws {
        print("🎉 Marking party going: partyId=\(partyId), userId=\(userId)")
        
        // Check if user already marked going
        let existingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        if !existingQuery.documents.isEmpty {
            print("⚠️ User \(userId) already marked going for party \(partyId)")
            return // Already marked, no error
        }
        
        // Create going record
        let goingData: [String: Any] = [
            "partyId": partyId,
            "userId": userId,
            "clickedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("partyGoing").addDocument(data: goingData)
        print("✅ Successfully marked party going")
    }
    
    /// Unmark that a user is going to a party
    func unmarkPartyGoing(partyId: String, userId: String) async throws {
        print("🎉 Unmarking party going: partyId=\(partyId), userId=\(userId)")
        
        // Find user's going record
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        // Delete all matching records (should only be one)
        for document in goingQuery.documents {
            try await document.reference.delete()
        }
        
        print("✅ Successfully unmarked party going")
    }
    
    /// Get the count of users going to a party
    func getPartyGoingCount(partyId: String) async throws -> Int {
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .getDocuments()
        
        return goingQuery.documents.count
    }
    
    /// Check if a user is going to a party
    func isUserGoingToParty(partyId: String, userId: String) async throws -> Bool {
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        return !goingQuery.documents.isEmpty
    }
    
    /// Listen to party going count changes in real-time
    func listenToPartyGoingCount(partyId: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        return db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to party going count: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                onChange(count)
            }
    }
    
    /// Delete expired parties from events_from_linktree_raw collection
    func deleteExpiredParties() async {
        print("🧹 Starting cleanup of expired parties...")
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        do {
            let partiesSnapshot = try await db.collection("events_from_linktree_raw").getDocuments()
            var deletedCount = 0
            
            for document in partiesSnapshot.documents {
                let data = document.data()
                
                // Try to parse the date from the document
                var partyDate: Date?
                
                // Check dateTime field in various formats
                if let dateTimeString = data["dateTime"] as? String {
                    partyDate = parseDateTimeString(dateTimeString)
                } else if let dateTimeTimestamp = data["dateTime"] as? Timestamp {
                    partyDate = dateTimeTimestamp.dateValue()
                } else if let dateTimeSeconds = data["dateTime"] as? TimeInterval {
                    partyDate = Date(timeIntervalSince1970: dateTimeSeconds)
                } else if let dateTimeMillis = data["dateTime"] as? Double {
                    if dateTimeMillis > 10000000000 {
                        partyDate = Date(timeIntervalSince1970: dateTimeMillis / 1000)
                    } else {
                        partyDate = Date(timeIntervalSince1970: dateTimeMillis)
                    }
                }
                
                // Try alternative date field names
                if partyDate == nil {
                    if let dateString = data["date"] as? String {
                        partyDate = parseDateTimeString(dateString)
                    } else if let startTimeString = data["startTime"] as? String {
                        partyDate = parseDateTimeString(startTimeString)
                    } else if let eventDateString = data["eventDate"] as? String {
                        partyDate = parseDateTimeString(eventDateString)
                    }
                }
                
                // Try to extract from description if no date field
                if partyDate == nil, let description = data["description"] as? String {
                    partyDate = extractDateFromDescription(description)
                }
                
                // Delete if party date is before today
                if let date = partyDate, date < startOfToday {
                    try await document.reference.delete()
                    deletedCount += 1
                    print("🗑️ Deleted expired party: \(document.documentID)")
                    
                    // Also delete any associated partyGoing records
                    let goingRecords = try await db.collection("partyGoing")
                        .whereField("partyId", isEqualTo: document.documentID)
                        .getDocuments()
                    
                    for goingDoc in goingRecords.documents {
                        try await goingDoc.reference.delete()
                    }
                }
            }
            
            print("✅ Party cleanup complete: Deleted \(deletedCount) expired parties")
        } catch {
            print("❌ Error during party cleanup: \(error.localizedDescription)")
        }
    }
    
    /// Parse dateTime string in various formats
    private func parseDateTimeString(_ dateTimeString: String) -> Date? {
        // First check if it's a Unix timestamp (numeric string)
        if let timestamp = Double(dateTimeString) {
            // If value is very large, it's likely milliseconds
            if timestamp > 10000000000 {
                return Date(timeIntervalSince1970: timestamp / 1000)
            } else {
                return Date(timeIntervalSince1970: timestamp)
            }
        }
        
        let formatters: [DateFormatter] = [
            // ISO 8601 formats
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Common date/time formats
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy h:mm a"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy HH:mm"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Date only formats (assume midnight)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Natural language formats
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d, yyyy"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Generic formats
            {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .short
                formatter.timeZone = TimeZone.current
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateTimeString) {
                print("✅ Successfully parsed date using format: \(formatter.dateFormat ?? "standard")")
                return date
            }
        }
        
        print("⚠️ Could not parse date string: \(dateTimeString)")
        return nil
    }
    
    /// Extract date from description text
    private func extractDateFromDescription(_ description: String) -> Date? {
        print("📄 Attempting to extract date from description: \(String(description.prefix(100)))")
        
        // Try multiple date formats on the full description first
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy h:mm a"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                formatter.defaultDate = Date()
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                formatter.defaultDate = Date()
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .none
                return formatter
            }()
        ]
        
        // Try to find date patterns in the description using formatters
        for formatter in dateFormatters {
            if let date = formatter.date(from: description) {
                print("✅ Extracted date from full description using format: \(formatter.dateFormat ?? "standard")")
                return date
            }
        }
        
        // Try to find date patterns using regex and then parse
        let patterns = [
            // Full date with time: "Nov 15, 2025 at 9:00 PM" or "November 15, 2025 at 9:00 PM"
            "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4}\\s+at\\s+\\d{1,2}:\\d{2}\\s*(AM|PM|am|pm)",
            // Date with year: "Nov 15, 2025" or "November 15, 2025"
            "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4}",
            // Date without year: "Nov 15" or "November 15"
            "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2}",
            // Numeric dates: "11/15/2025"
            "\\b\\d{1,2}/\\d{1,2}/\\d{4}\\b",
            // ISO format: "2025-11-15"
            "\\b\\d{4}-\\d{2}-\\d{2}\\b"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = description as NSString
                let range = NSRange(location: 0, length: nsString.length)
                if let match = regex.firstMatch(in: description, options: [], range: range) {
                    let matchedString = nsString.substring(with: match.range)
                    print("📄 Found date pattern: \(matchedString)")
                    
                    for formatter in dateFormatters {
                        if let date = formatter.date(from: matchedString) {
                            print("✅ Extracted date from pattern using format: \(formatter.dateFormat ?? "standard")")
                            return date
                        }
                    }
                    
                    // Try parsing the matched string directly
                    if let date = parseDateTimeString(matchedString) {
                        print("✅ Extracted date from pattern using parseDateTimeString")
                        return date
                    }
                }
            }
        }
        
        print("⚠️ Could not extract date from description")
        return nil
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
        let finalCategory = event.category ?? EventCategory.chillHangout.rawValue
        var finalTags = event.tags
        if finalTags.isEmpty {
            if let cat = EventCategory(rawValue: finalCategory) {
                finalTags = [cat.defaultTag]
            } else {
                finalTags = [EventCategory.chillHangout.defaultTag]
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
        // Try to get ID from document ID or id field
        let id = data["id"] as? String ?? data["eventId"] as? String ?? UUID().uuidString
        
        // Try multiple field name variations
        let title = data["title"] as? String ?? data["name"] as? String ?? data["eventName"] as? String
        let lat = data["latitude"] as? Double ?? data["lat"] as? Double
        let lon = data["longitude"] as? Double ?? data["lng"] as? Double ?? data["lon"] as? Double
        
        guard let title = title,
              let lat = lat,
              let lon = lon else {
            throw CrowdError.invalidResponse
        }
        
        // radiusMeters is optional for parties, default to 0
        let radiusMeters = data["radiusMeters"] as? Double ?? data["radius"] as? Double ?? 0.0
        
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
        var category = data["category"] as? String ?? EventCategory.chillHangout.rawValue
        
        // If tags are empty but category exists, generate tags from category
        if tags.isEmpty {
            if let cat = EventCategory(rawValue: category) {
                tags = [cat.defaultTag]
            } else {
                tags = [EventCategory.chillHangout.defaultTag]
                category = EventCategory.chillHangout.rawValue
            }
        }
        
        // Parse createdAt
        var createdAt = Date()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let seconds = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: seconds)
        }
        
        // Parse optional fields
        let description = data["description"] as? String
        let sourceURL = data["sourceURL"] as? String
        let rawLocationName = data["rawLocationName"] as? String
        let imageURL = data["imageURL"] as? String ?? data["imageUrl"] as? String ?? data["image"] as? String
        let ticketURL = data["ticketURL"] as? String ?? data["ticketUrl"] as? String ?? data["ticket"] as? String
        
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
            category: category,
            description: description,
            sourceURL: sourceURL,
            rawLocationName: rawLocationName,
            imageURL: imageURL,
            ticketURL: ticketURL
        )
    }
}
