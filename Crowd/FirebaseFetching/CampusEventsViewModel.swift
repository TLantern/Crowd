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

    // Energy-friendly single fetch used by calendar view (14-day feed already in Firestore)
    func fetchOnce(limit: Int = 25) async {
        let db = Firestore.firestore()
        print("🔄 CampusEventsViewModel: One-time fetch from campus_events_live (limit: \(limit))")
        
        do {
            let snap = try await db.collection("campus_events_live")
                .limit(to: limit * 2)
                .getDocuments()

            let docs = snap.documents
            let now = Date()
            
            let mapped: [CrowdEvent] = try await Task.detached(priority: .utility) { () async -> [CrowdEvent] in
                var tmp: [CrowdEvent] = []
                for d in docs {
                    if var live = try? d.data(as: CampusEventLive.self) {
                        live.id = d.documentID
                        var geocoded: CLLocationCoordinate2D?
                        if (live.latitude == nil || live.longitude == nil),
                           let name = (live.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? live.locationName : live.location),
                           let query = name, !query.isEmpty {
                            geocoded = await searchLocationOnAppleMapsCampus(query)
                        }
                        if var ce = mapCampusEventLiveToCrowdEvent(live) {
                            if let coord = geocoded { ce.coordinates = coord }
                            if let startDate = ce.startsAt, startDate >= now { tmp.append(ce) }
                        }
                    }
                }
                tmp.sort { a, b in
                    let aStart = a.startsAt ?? .distantFuture
                    let bStart = b.startsAt ?? .distantFuture
                    return aStart < bStart
                }
                return Array(tmp.prefix(limit))
            }.value

            await MainActor.run { self.crowdEvents = mapped }
            print("🎯 CampusEventsViewModel: Final mapped events count: \(mapped.count) (one-time)")
            await resolveMissingCoordinates(docs: docs)
        } catch {
            print("❌ CampusEventsViewModel: One-time fetch failed: \(error)")
        }
    }

    func start() {
        let db = Firestore.firestore()
        
        print("🔄 CampusEventsViewModel: Starting listener for campus_events_live collection")

        listener = db.collection("campus_events_live")
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
                            if let startDate = ce.startsAt, startDate >= now {
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
                    let aStart = a.startsAt ?? .distantFuture
                    let bStart = b.startsAt ?? .distantFuture
                    return aStart < bStart
                }

                print("🎯 CampusEventsViewModel: Final mapped events count: \(mapped.count)")
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                df.locale = Locale(identifier: "en_US_POSIX")
                df.timeZone = .current
                for event in mapped {
                    let startText = event.startsAt.map { df.string(from: $0) } ?? "nil"
                    print("   - \(event.title) (starts: \(startText))")
                }
                
                let previousCount = self.crowdEvents.count
                self.crowdEvents = mapped
                
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
}

// MARK: - Apple Maps Geocoding (reuse HostedEventSheet logic)

fileprivate func searchLocationOnAppleMapsCampus(_ locationName: String) async -> CLLocationCoordinate2D? {
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
            if (live.latitude == nil || live.longitude == nil),
               let name = (live.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? live.locationName : live.location),
               let query = name, !query.isEmpty {
                if let coord = await searchLocationOnAppleMapsCampus(query) {
                    updates.append((id, coord))
                    geocodedIds.insert(id)
                }
            }
        }
        if !updates.isEmpty { await MainActor.run { applyCoordinateUpdates(updates) } }
    }
}
