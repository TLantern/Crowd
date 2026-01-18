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
        let partiesSnapshot = try await db.collection("events_from_linktree_raw").getDocuments()
        
        var parties: [CrowdEvent] = []
        var parseErrors = 0
        
        // Get start of today for filtering
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        for document in partiesSnapshot.documents {
            let data = document.data()
            
            do {
                let party = try await parseParty(from: data, documentId: document.documentID)
                
                // Only include upcoming parties (today or future)
                if let time = party.time {
                    if time >= startOfToday {
                        parties.append(party)
                    }
                } else {
                    // Include parties without a date (they might be ongoing/TBD)
                    parties.append(party)
                }
            } catch {
                parseErrors += 1
            }
        }
        
        // Trigger background cleanup of expired parties
        Task {
            await deleteExpiredParties()
        }
        
        return parties
    }
    
    /// Parse party from events_from_linktree_raw collection
    /// Only extracts: title, date/time, ticketURL, and attendance
    private func parseParty(from data: [String: Any], documentId: String) async throws -> CrowdEvent {
        // Extract nested dictionaries for date/time lookup
        let normalized = data["normalized"] as? [String: Any]
        let eventDetails = data["eventDetails"] as? [String: Any]
        
        // Title - check top level first, then eventDetails
        guard let title = data["title"] as? String ?? eventDetails?["title"] as? String else {
            throw CrowdError.invalidResponse
        }
        
        let id = documentId
        
        // Ticket URL - Check multiple field name variations
        let ticketURL = data["URL"] as? String ?? 
                       data["ticketURL"] as? String ?? 
                       data["ticketUrl"] as? String ??
                       data["link"] as? String ??
                       data["ticketLink"] as? String ??
                       data["eventLink"] as? String ??
                       data["url"] as? String
        
        // Image URL - Check multiple field name variations
        let imageURL: String? = {
            if let url = data["imageURL"] as? String { return url }
            if let url = data["imageUrl"] as? String { return url }
            if let url = data["image"] as? String { return url }
            if let url = data["image_url"] as? String { return url }
            if let url = data["photoURL"] as? String { return url }
            if let url = data["photoUrl"] as? String { return url }
            if let url = data["photo"] as? String { return url }
            if let url = data["thumbnailURL"] as? String { return url }
            if let url = data["thumbnailUrl"] as? String { return url }
            if let url = data["thumbnail"] as? String { return url }
            if let url = eventDetails?["imageURL"] as? String { return url }
            if let url = eventDetails?["imageUrl"] as? String { return url }
            if let url = eventDetails?["image"] as? String { return url }
            return nil
        }()
        
        // Source URL - Check multiple field name variations
        let sourceUrl: String? = {
            // Check normalized.url first (this is where it actually is!)
            if let url = normalized?["url"] as? String { return url }
            // Then check top-level fields
            if let url = data["sourceURL"] as? String { return url }
            if let url = data["sourceUrl"] as? String { return url }
            if let url = data["source"] as? String { return url }
            if let url = data["source_url"] as? String { return url }
            if let url = data["originalURL"] as? String { return url }
            if let url = data["originalUrl"] as? String { return url }
            if let url = data["eventSourceURL"] as? String { return url }
            // Then check eventDetails
            if let url = eventDetails?["sourceURL"] as? String { return url }
            if let url = eventDetails?["sourceUrl"] as? String { return url }
            // Check other normalized fields
            if let url = normalized?["sourceURL"] as? String { return url }
            if let url = normalized?["sourceUrl"] as? String { return url }
            return nil
        }()
        
        // Address/Location - Check multiple field name variations
        let rawAddress: String? = {
            // Check top-level fields first
            if let addr = data["address"] as? String, !addr.isEmpty { return addr }
            if let addr = data["location"] as? String, !addr.isEmpty { return addr }
            if let addr = data["locationName"] as? String, !addr.isEmpty { return addr }
            if let addr = data["rawLocationName"] as? String, !addr.isEmpty { return addr }
            if let addr = data["venue"] as? String, !addr.isEmpty { return addr }
            if let addr = data["venueName"] as? String, !addr.isEmpty { return addr }
            if let addr = data["place"] as? String, !addr.isEmpty { return addr }
            if let addr = data["eventLocation"] as? String, !addr.isEmpty { return addr }
            // Check nested eventDetails
            if let addr = eventDetails?["address"] as? String, !addr.isEmpty { return addr }
            if let addr = eventDetails?["location"] as? String, !addr.isEmpty { return addr }
            if let addr = eventDetails?["locationName"] as? String, !addr.isEmpty { return addr }
            if let addr = eventDetails?["venue"] as? String, !addr.isEmpty { return addr }
            if let addr = eventDetails?["venueName"] as? String, !addr.isEmpty { return addr }
            // Check normalized
            if let addr = normalized?["address"] as? String, !addr.isEmpty { return addr }
            if let addr = normalized?["location"] as? String, !addr.isEmpty { return addr }
            if let addr = normalized?["locationName"] as? String, !addr.isEmpty { return addr }
            return nil
        }()
        
        // Clean the address by removing date/time patterns
        let address = rawAddress.map { cleanAddressFromDateTime($0) }
        
        // Parse time from dateTime field - check both root level and eventDetails
        var time: Date?
        var dateTimeString: String? = nil  // Preserve the original dateTime string
        
        // Check dateTime field in various formats - try eventDetails first, then root level
        if let dateTimeStr = eventDetails?["dateTime"] as? String ?? data["dateTime"] as? String {
            dateTimeString = dateTimeStr  // Store the original string
            time = parseDateTimeString(dateTimeStr)
        } else if let dateTimeTimestamp = eventDetails?["dateTime"] as? Timestamp ?? data["dateTime"] as? Timestamp {
            time = dateTimeTimestamp.dateValue()
        } else if let dateTimeSeconds = eventDetails?["dateTime"] as? TimeInterval ?? data["dateTime"] as? TimeInterval {
            time = Date(timeIntervalSince1970: dateTimeSeconds)
        } else if let dateTimeMillis = eventDetails?["dateTime"] as? Double ?? data["dateTime"] as? Double {
            // Try as milliseconds if value is very large
            if dateTimeMillis > 10000000000 {
                time = Date(timeIntervalSince1970: dateTimeMillis / 1000)
            } else {
                time = Date(timeIntervalSince1970: dateTimeMillis)
            }
        }
        
        // Use time for both startsAt and endsAt
        
        // Default coordinates (can be geocoded later if needed)
        // Using UNT main campus coordinates as default
        let latitude = 33.210081
        let longitude = -97.147700
        
        // Fetch going count for this party (attendance)
        let goingCount = try? await getPartyGoingCount(partyId: id)
        
        return CrowdEvent(
            id: id,
            title: title,
            hostId: "",
            hostName: "Party Host",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: 0,
            time: time,
            createdAt: Date(),
            signalStrength: 0,
            attendeeCount: goingCount ?? 0,
            tags: ["party"],
            category: "Party",
            description: nil,
            sourceURL: sourceUrl,
            rawLocationName: address,
            imageURL: imageURL,
            ticketURL: ticketURL,
            dateTime: dateTimeString,
            rawDateTime: nil
        )
    }
    
    // MARK: - Party "I'm Going" Functions
    
    /// Mark that a user is going to a party
    func markPartyGoing(partyId: String, userId: String) async throws {
        // Check if user already marked going
        let existingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        if !existingQuery.documents.isEmpty {
            return // Already marked, no error
        }
        
        // Create going record
        let goingData: [String: Any] = [
            "partyId": partyId,
            "userId": userId,
            "clickedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("partyGoing").addDocument(data: goingData)
    }
    
    /// Mark that a user is going to a school event (reuses partyGoing collection)
    func markSchoolEventGoing(eventId: String, userId: String) async throws {
        // Check if user already marked going
        let existingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        if !existingQuery.documents.isEmpty {
            return // Already marked, no error
        }
        
        // Create going record (reuse partyId field for school events too)
        let goingData: [String: Any] = [
            "partyId": eventId,
            "userId": userId,
            "clickedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("partyGoing").addDocument(data: goingData)
    }
    
    /// Unmark that a user is going to a party
    func unmarkPartyGoing(partyId: String, userId: String) async throws {
        // Find user's going record
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        // Delete all matching records (should only be one)
        for document in goingQuery.documents {
            try await document.reference.delete()
        }
    }
    
    /// Unmark that a user is going to a school event
    func unmarkSchoolEventGoing(eventId: String, userId: String) async throws {
        // Find user's going record
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        // Delete all matching records (should only be one)
        for document in goingQuery.documents {
            try await document.reference.delete()
        }
    }
    
    /// Get the count of users going to a party
    func getPartyGoingCount(partyId: String) async throws -> Int {
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: partyId)
            .getDocuments()
        
        return goingQuery.documents.count
    }
    
    /// Get the count of users going to a school event (reuses partyGoing collection)
    func getSchoolEventGoingCount(eventId: String) async throws -> Int {
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: eventId)
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
    
    /// Check if a user is going to a school event
    func isUserGoingToSchoolEvent(eventId: String, userId: String) async throws -> Bool {
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: eventId)
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
    
    /// Listen to school event going count changes in real-time
    func listenToSchoolEventGoingCount(eventId: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        return db.collection("partyGoing")
            .whereField("partyId", isEqualTo: eventId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening to school event going count: \(error.localizedDescription)")
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
    /// Remove date/time information from address strings using regex patterns
    /// Example: "Vice ParkDallas, TXDec 31, 2025 at 9 pm to Jan 1 at 2 am CST" -> "Vice ParkDallas, TX"
    private func cleanAddressFromDateTime(_ address: String) -> String {
        var cleaned = address
        
        // Aggressive Pattern: Remove everything starting from a month abbreviation followed by day/year pattern
        // This catches "TXDec 31, 2025..." and removes "Dec 31, 2025..." onwards
        let aggressivePattern = #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s*\d{1,2}.*$"#
        
        if let regex = try? NSRegularExpression(pattern: aggressivePattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // Clean up any trailing commas, spaces, or extra whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #",\s*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        
        return cleaned.isEmpty ? address : cleaned
    }
    
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
            "startsAt": event.time?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "endsAt": event.time?.timeIntervalSince1970,
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
        
        // Parse time from startsAt or endsAt field (for backward compatibility)
        var time: Date?
        
        if let timestamp = data["startsAt"] as? Timestamp {
            time = timestamp.dateValue()
        } else if let seconds = data["startsAt"] as? TimeInterval {
            time = Date(timeIntervalSince1970: seconds)
        } else if let timestamp = data["endsAt"] as? Timestamp {
            time = timestamp.dateValue()
        } else if let seconds = data["endsAt"] as? TimeInterval {
            time = Date(timeIntervalSince1970: seconds)
        } else if let timestamp = data["time"] as? Timestamp {
            time = timestamp.dateValue()
        } else if let seconds = data["time"] as? TimeInterval {
            time = Date(timeIntervalSince1970: seconds)
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
        let dateTime = data["dateTime"] as? String  // For parties
        let rawDateTime = data["rawDateTime"] as? String  // For school events
        
        return CrowdEvent(
            id: id,
            title: title,
            hostId: hostId,
            hostName: hostName,
            latitude: lat,
            longitude: lon,
            radiusMeters: radiusMeters,
            time: time,
            createdAt: createdAt,
            signalStrength: signalStrength,
            attendeeCount: attendeeCount,
            tags: tags,
            category: category,
            description: description,
            sourceURL: sourceURL,
            rawLocationName: rawLocationName,
            imageURL: imageURL,
            ticketURL: ticketURL,
            dateTime: dateTime,
            rawDateTime: rawDateTime
        )
    }
}
