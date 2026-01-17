//
//  CampusEventsViewModel.swift
//  Crowd
//
//  Listens to Firestore `events_from_official_raw` (official school events).
//  Produces [CrowdEvent] ready for UI and map.
//

import Foundation
import FirebaseFirestore
import Combine
import MapKit

final class CampusEventsViewModel: ObservableObject {
    @Published var crowdEvents: [CrowdEvent] = []

    private var listener: ListenerRegistration?
    private var geocodedIds: Set<String> = []
    
    // Cache key for persisting events to UserDefaults
    private let cacheKey = "campus_events_cache_v1"
    private let cacheTimestampKey = "campus_events_cache_timestamp"
    
    // Shared singleton instance for preloading events
    // Step 1: Load minimal local cache immediately on initialization
    @MainActor
    static let shared: CampusEventsViewModel = {
        let vm = CampusEventsViewModel()
        // Load from cache synchronously on MainActor - this is fast and shows data immediately
        vm.loadFromCache()
        return vm
    }()

    /// Step 2 & 3: Fetch fresh data from Firebase and replace cache
    /// This is called in parallel after cache load to refresh with latest server data
    func fetchOnce(limit: Int = 25) async {
        // Don't clear existing events - they might be from cache (Step 1)
        // Step 3: Server data will replace cache when it arrives
        await MainActor.run {
            self.geocodedIds.removeAll()
        }
        
        let db = Firestore.firestore()
        print("🔄 CampusEventsViewModel: One-time fetch from events_from_official_raw (limit: \(limit))")
        
        do {
            // Fetch all documents from events_from_official_raw collection
            // This collection contains official school events scraped from UNT sources
            let snap = try await db.collection("events_from_official_raw")
                .limit(to: 200)
                .getDocuments()

            let docs = snap.documents
            let now = Date()
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            
            // Parse events from events_from_official_raw collection
            let mapped: [CrowdEvent] = try await Task.detached(priority: .utility) { () async -> [CrowdEvent] in
                var tmp: [CrowdEvent] = []
                var geocodingCount = 0
                for d in docs {
                    let data = d.data()
                    do {
                        var event = try await self.parseOfficialEvent(from: data, documentId: d.documentID)
                        
                        // Only include future events (today or later)
                        if let startDate = event.time, startDate >= startOfToday {
                            // Try to geocode if coordinates are missing
                            if event.latitude == 33.2100 && event.longitude == -97.1500 { // Default fallback coordinates
                                if let locationName = event.rawLocationName, !locationName.isEmpty {
                                    geocodingCount += 1
                                    if let predefined = matchUNTLocationCoordinate(for: locationName) {
                                        event.coordinates = predefined
                                    } else {
                                        if let geocoded = await searchLocationOnAppleMapsCampus(locationName) {
                                            event.coordinates = geocoded
                                        }
                                    }
                                }
                            }
                            tmp.append(event)
                        }
                    } catch {
                        print("❌ Failed to parse official event: \(error)")
                    }
                }
                tmp.sort { a, b in
                    let aStart = a.time ?? .distantFuture
                    let bStart = b.time ?? .distantFuture
                    return aStart < bStart
                }
                return tmp
            }.value

            await MainActor.run { 
                self.crowdEvents = mapped
                // Save to cache after successful fetch
                self.saveToCache(mapped)
            }
            print("🎯 CampusEventsViewModel: Final mapped events count: \(mapped.count) (one-time)")
            await resolveMissingCoordinates(docs: docs)
        } catch {
            print("❌ CampusEventsViewModel: One-time fetch failed: \(error)")
            // On error, keep existing cache data if available
        }
    }

    func start() {
        let db = Firestore.firestore()
        
        print("🔄 CampusEventsViewModel: Starting listener for events_from_official_raw collection")

        // Listen to events_from_official_raw collection for real-time updates
        listener = db.collection("events_from_official_raw")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                
                if let err = err {
                    print("❌ CampusEventsViewModel: Error fetching events_from_official_raw: \(err)")
                    return
                }
                
                guard let docs = snap?.documents else {
                    print("⚠️ CampusEventsViewModel: No documents in events_from_official_raw collection")
                    return
                }
                
                print("📊 CampusEventsViewModel: Received \(docs.count) documents from events_from_official_raw")
                print("📊 CampusEventsViewModel: Previous events count: \(self.crowdEvents.count)")

                // Wrap async parsing in Task since listener closure must be synchronous
                Task {
                    var mapped: [CrowdEvent] = []
                    let calendar = Calendar.current
                    let startOfToday = calendar.startOfDay(for: Date())

                    for d in docs {
                        let data = d.data()
                        do {
                            let event = try await self.parseOfficialEvent(from: data, documentId: d.documentID)
                            
                            // Filter for future events only (today or later)
                            if let startDate = event.time, startDate >= startOfToday {
                                mapped.append(event)
                            }
                        } catch {
                            print("❌ CampusEventsViewModel: Failed to parse official event: \(error)")
                        }
                    }

                    // sort by soonest start time
                    mapped.sort { a, b in
                        let aStart = a.time ?? .distantFuture
                        let bStart = b.time ?? .distantFuture
                        return aStart < bStart
                    }

                    print("🎯 CampusEventsViewModel: Final mapped events count: \(mapped.count)")
                    let df = DateFormatter()
                    df.dateStyle = .medium
                    df.timeStyle = .short
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.timeZone = .current
                    for event in mapped {
                        let startText = event.time.map { df.string(from: $0) } ?? "nil"
                        print("   - \(event.title) (starts: \(startText))")
                    }
                    
                    await MainActor.run {
                        let previousCount = self.crowdEvents.count
                        self.crowdEvents = mapped
                        
                        // Save to cache after successful fetch
                        self.saveToCache(mapped)
                        
                        if previousCount != mapped.count {
                            print("🔄 CampusEventsViewModel: Event count changed from \(previousCount) to \(mapped.count)")
                        }
                    }
                    
                    await self.resolveMissingCoordinates(docs: docs)
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Official Event Parsing
    
    /// Parse an official school event from events_from_official_raw collection
    /// Collection structure:
    /// - eventId: unique ID from source
    /// - title: event title
    /// - location: location name
    /// - rawDateTime: "Thursday, January 22, 2026 at 7:30 PM to Thursday, January 22, 2026 at 9:00 PM"
    /// - imageUrl: event image URL
    /// - url: source URL (event page)
    /// - tags: array of tags
    /// - organization: "UNT Official"
    private func parseOfficialEvent(from data: [String: Any], documentId: String) async throws -> CrowdEvent {
        // Extract title - required field
        guard let title = data["title"] as? String else {
            throw CrowdError.invalidResponse
        }
        
        // Use eventId from document if available, otherwise use Firestore document ID
        let id = data["eventId"] as? String ?? documentId
        
        // Extract location
        let rawLocationName = data["location"] as? String
        
        // Extract image URL
        let imageURL = data["imageUrl"] as? String
        
        // Extract source URL (event page)
        let sourceURL = data["url"] as? String
        
        // Extract and clean rawDateTime
        // Transform "Thursday, January 22, 2026 at 7:30 PM to Thursday, January 22, 2026 at 9:00 PM"
        // into "Thursday, January 22, 2026 at 7:30 PM"
        var rawDateTime: String?
        var time: Date?
        
        if let dateTimeStr = data["rawDateTime"] as? String {
            // Remove everything after " to " using regex
            let cleanedDateTime = dateTimeStr.replacingOccurrences(
                of: " to .*$",
                with: "",
                options: .regularExpression
            )
            rawDateTime = cleanedDateTime
            time = parseDateTimeString(cleanedDateTime)
        }
        
        // Extract tags (we'll use these later)
        let tags = data["tags"] as? [String] ?? ["official", "school"]
        
        // Default coordinates (UNT main campus) - will be geocoded if location name exists
        let latitude = 33.2100
        let longitude = -97.1500
        
        // Fetch going count for this school event
        let goingCount = try? await getSchoolEventGoingCount(eventId: id)
        
        return CrowdEvent(
            id: id,
            title: title,
            hostId: "UNT Official",
            hostName: "UNT Official",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: 0,
            time: time,
            createdAt: Date(),
            signalStrength: 0,
            attendeeCount: goingCount ?? 0,
            tags: tags.isEmpty ? ["official", "school"] : tags,
            category: "School Event",
            description: nil,
            sourceURL: sourceURL,
            rawLocationName: rawLocationName,
            imageURL: imageURL,
            ticketURL: nil,
            dateTime: nil,
            rawDateTime: rawDateTime
        )
    }
    
    /// Parse dateTime string in various formats for official events
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
            // Format from CrowdEventMapping: "Tuesday, October 28, 2025 at 10:00 AM"
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
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
            // Date only formats (assume start of day)
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
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateTimeString) {
                return date
            }
        }
        return nil
    }
    
    /// Get the count of users going to a school event from partyGoing collection
    private func getSchoolEventGoingCount(eventId: String) async throws -> Int {
        let db = Firestore.firestore()
        let goingQuery = try await db.collection("partyGoing")
            .whereField("partyId", isEqualTo: eventId)
            .getDocuments()
        
        return goingQuery.documents.count
    }
    
    // MARK: - Cache Management
    
    /// Step 1: Load events from local cache
    /// This loads cached events immediately on app start to show data instantly
    /// The cache is then replaced with fresh server data when it arrives (Step 3)
    @MainActor
    func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CrowdEvent].self, from: data) else {
            print("📦 No cached events found")
            return
        }
        
        // Filter out expired events from cache
        let now = Date()
        let validCached = cached.filter { event in
            guard let startsAt = event.time else { return true }
            return startsAt >= now
        }
        
        if !validCached.isEmpty {
            self.crowdEvents = validCached
            print("📦 Loaded \(validCached.count) events from cache (Step 1)")
        } else {
            print("📦 Cache contained only expired events")
        }
    }
    
    /// Save events to local cache
    private func saveToCache(_ events: [CrowdEvent]) {
        guard let data = try? JSONEncoder().encode(events) else {
            print("⚠️ Failed to encode events for caching")
            return
        }
        
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        print("💾 Saved \(events.count) events to cache")
    }
}

// MARK: - Apple Maps Geocoding (reuse HostedEventSheet logic)

// Shared rate limiter to prevent GEO throttling (max ~50/min). Queues calls globally.
private actor AppleMapsSearchRateLimiter {
    static let shared = AppleMapsSearchRateLimiter()
    private var nextAllowed: Date = .distantPast
    private let minInterval: TimeInterval = 1.3 // ~46/min

    func acquire() async {
        let now = Date()
        let delay = max(0, nextAllowed.timeIntervalSince(now))
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        nextAllowed = Date().addingTimeInterval(minInterval)
    }

    func backoff(seconds: TimeInterval) {
        nextAllowed = Date().addingTimeInterval(seconds)
    }
}

// Simple persistent cache to avoid repeated Apple Maps lookups across app sessions
private actor AppleMapsGeoCache {
    static let shared = AppleMapsGeoCache()
    private var memory: [String: [Double]] = [:] // key -> [lat, lon]
    private let storageKey = "apple_maps_geo_cache_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: [Double]] {
            memory = decoded
        }
    }

    func get(_ key: String) -> CLLocationCoordinate2D? {
        if let pair = memory[key], pair.count == 2 {
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        return nil
    }

    func set(_ key: String, coord: CLLocationCoordinate2D) {
        memory[key] = [coord.latitude, coord.longitude]
        if let data = try? JSONSerialization.data(withJSONObject: memory) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

fileprivate func searchLocationOnAppleMapsCampus(_ locationName: String) async -> CLLocationCoordinate2D? {
    let trimmed = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    await AppleMapsSearchRateLimiter.shared.acquire()
    let req = MKLocalSearch.Request()
    let query: String = (
        trimmed.contains("DATCU") || trimmed.contains("Stadium") || trimmed.contains("Square")
    ) ? "\(trimmed), Denton, TX" : "\(trimmed), UNT, Denton, TX 76203"

    if let cached = await AppleMapsGeoCache.shared.get(query) { return cached }

    req.naturalLanguageQuery = query
    req.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.210081, longitude: -97.147700),
        latitudinalMeters: 3000,
        longitudinalMeters: 3000
    )
    do {
        let resp = try await MKLocalSearch(request: req).start()
        guard let item = resp.mapItems.first else { return nil }
        let coord = item.placemark.coordinate
        await AppleMapsGeoCache.shared.set(query, coord: coord)
        return coord
    } catch {
        let ns = error as NSError
        if ns.domain == "GEOErrorDomain" && ns.code == -3 { // throttled
            await AppleMapsSearchRateLimiter.shared.backoff(seconds: 60)
        }
        return nil
    }
}

extension CampusEventsViewModel {
    @MainActor private func applyCoordinateUpdates(_ updates: [(String, CLLocationCoordinate2D)]) {
        for (id, coord) in updates {
            if let idx = crowdEvents.firstIndex(where: { $0.id == id }) {
                crowdEvents[idx].coordinates = coord
            }
        }
    }

    fileprivate func resolveMissingCoordinates(docs: [QueryDocumentSnapshot]) async {
        var updates: [(String, CLLocationCoordinate2D)] = []
        for d in docs {
            let id = d.documentID
            if geocodedIds.contains(id) { continue }
            guard let live = try? d.data(as: CampusEventLive.self) else { continue }
            if (live.latitude == nil || live.longitude == nil) {
                let trimmedName = live.locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name: String? = (trimmedName?.isEmpty == false) ? live.locationName : live.location
                if let query = name, !query.isEmpty {
                    // First try predefined UNT locations to avoid network geocoding
                    if let predefined = matchUNTLocationCoordinate(for: query) {
                        updates.append((id, predefined))
                        geocodedIds.insert(id)
                    } else if let coord = await searchLocationOnAppleMapsCampus(query) {
                        updates.append((id, coord))
                        geocodedIds.insert(id)
                    }
                }
            }
        }
        if !updates.isEmpty {
            await MainActor.run { applyCoordinateUpdates(updates) }
            // Do not persist to Firestore from client; writes are disallowed by rules.
        }
    }
}
