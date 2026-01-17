//
//  CampusEventsViewModel.swift
//  Crowd
//
//  Listens to Firestore `campus_events_live` (the unified feed from IG + official).
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
        print("🔄 CampusEventsViewModel: One-time fetch from campus_events_live (limit: \(limit))")
        
        do {
            // Fetch all documents (or a large batch) since we filter for future events client-side
            // Order by createdAt descending to get most recent events first
            // Use a high limit to ensure we get all future events even if many are past
            let snap = try await db.collection("campus_events_live")
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
                .getDocuments()

            let docs = snap.documents
            let now = Date()
            // Fast path: map immediately without geocoding or attendance so UI populates instantly
            var quickMapped: [CrowdEvent] = []
            for d in docs {
                if var live = try? d.data(as: CampusEventLive.self) {
                    live.id = d.documentID
                    if let ce = mapCampusEventLiveToCrowdEvent(live),
                       let startDate = ce.time, startDate >= now {
                        quickMapped.append(ce)
                    }
                }
            }
            quickMapped.sort { (a, b) in
                let aStart = a.time ?? .distantFuture
                let bStart = b.time ?? .distantFuture
                return aStart < bStart
            }
            // Don't limit here - show all future events found
            await MainActor.run { self.crowdEvents = quickMapped }
            
            // Slow path: fetch with attendance counts and geocoding
            let mapped: [CrowdEvent] = try await Task.detached(priority: .utility) { () async -> [CrowdEvent] in
                var tmp: [CrowdEvent] = []
                for d in docs {
                    if var live = try? d.data(as: CampusEventLive.self) {
                        live.id = d.documentID
                        var geocoded: CLLocationCoordinate2D?
                        if (live.latitude == nil || live.longitude == nil) {
                            let trimmedName = live.locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
                            let name: String? = (trimmedName?.isEmpty == false) ? live.locationName : live.location
                            if let query = name, !query.isEmpty {
                                // Check predefined locations first (e.g., Union) to avoid geocoding
                                if let predefined = matchUNTLocationCoordinate(for: query) {
                                    geocoded = predefined
                                } else {
                                    geocoded = await searchLocationOnAppleMapsCampus(query)
                                }
                            }
                        }
                        // Use async version to fetch attendance count
                        if var ce = await mapCampusEventLiveToCrowdEventAsync(live) {
                            if let coord = geocoded { ce.coordinates = coord }
                            if let startDate = ce.time, startDate >= now { tmp.append(ce) }
                        }
                    }
                }
                tmp.sort { a, b in
                    let aStart = a.time ?? .distantFuture
                    let bStart = b.time ?? .distantFuture
                    return aStart < bStart
                }
                // Don't limit here - return all future events found
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
        
        print("🔄 CampusEventsViewModel: Starting listener for campus_events_live collection")

        // Order by createdAt to get most recent events first
        listener = db.collection("campus_events_live")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                
                if let err = err {
                    print("❌ CampusEventsViewModel: Error fetching campus_events_live: \(err)")
                    return
                }
                
                guard let docs = snap?.documents else {
                    print("⚠️ CampusEventsViewModel: No documents in campus_events_live collection")
                    return
                }
                
                print("📊 CampusEventsViewModel: Received \(docs.count) documents from campus_events_live")
                print("📊 CampusEventsViewModel: Previous events count: \(self.crowdEvents.count)")

                var mapped: [CrowdEvent] = []
                let now = Date()

                for d in docs {
                    do {
                        var live = try d.data(as: CampusEventLive.self)
                        // Use Firestore document ID as stable identifier
                        live.id = d.documentID
                        print("📝 CampusEventsViewModel: Parsed CampusEventLive: \(live.title) (id: \(d.documentID))")
                        
                        if let ce = mapCampusEventLiveToCrowdEvent(live) {
                            // Filter for future events only
                            if let startDate = ce.time, startDate >= now {
                                print("✅ CampusEventsViewModel: Mapped to CrowdEvent: \(ce.title) (id: \(ce.id))")
                                mapped.append(ce)
                            } else {
                                print("⏭️ CampusEventsViewModel: Skipping past event: \(ce.title)")
                            }
                        } else {
                            print("❌ CampusEventsViewModel: Failed to map CampusEventLive to CrowdEvent: \(live.title)")
                        }
                    } catch {
                        print("❌ CampusEventsViewModel: Failed to parse document as CampusEventLive: \(error)")
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
                
                let previousCount = self.crowdEvents.count
                self.crowdEvents = mapped
                
                // Save to cache after successful fetch
                self.saveToCache(mapped)
                
                if previousCount != mapped.count {
                    print("🔄 CampusEventsViewModel: Event count changed from \(previousCount) to \(mapped.count)")
                }
                Task { await self.resolveMissingCoordinates(docs: docs) }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
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
