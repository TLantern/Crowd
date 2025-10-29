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

final class CampusEventsViewModel: ObservableObject {
    @Published var crowdEvents: [CrowdEvent] = []

    private var listener: ListenerRegistration?

    // Energy-friendly single fetch used by calendar view
    func fetchOnce(limit: Int = 25) async {
        let db = Firestore.firestore()
        print("🔄 CampusEventsViewModel: One-time fetch from campus_events_live (limit: \(limit))")
        
        do {
            // Fetch more docs since we'll filter in-memory for future events
            let snap = try await db.collection("campus_events_live")
                .limit(to: limit * 2)
                .getDocuments()

            let docs = snap.documents
            let now = Date()
            
            let mapped: [CrowdEvent] = try await Task.detached(priority: .utility) {
                var tmp: [CrowdEvent] = []
                for d in docs {
                    if let live = try? d.data(as: CampusEventLive.self),
                       let ce = mapCampusEventLiveToCrowdEvent(live) {
                        // Filter for future events only
                        if let startDate = ce.startsAt, startDate >= now {
                            tmp.append(ce)
                        }
                    }
                }
                // Sort by start time
                tmp.sort { a, b in
                    let aStart = a.startsAt ?? .distantFuture
                    let bStart = b.startsAt ?? .distantFuture
                    return aStart < bStart
                }
                // Return only requested limit of future events
                return Array(tmp.prefix(limit))
            }.value

            await MainActor.run { self.crowdEvents = mapped }
            print("🎯 CampusEventsViewModel: Final mapped events count: \(mapped.count) (one-time)")
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
                        let live = try d.data(as: CampusEventLive.self)
                        print("📝 CampusEventsViewModel: Parsed CampusEventLive: \(live.title)")
                        
                        if let ce = mapCampusEventLiveToCrowdEvent(live) {
                            // Filter for future events only
                            if let startDate = ce.startsAt, startDate >= now {
                                print("✅ CampusEventsViewModel: Mapped to CrowdEvent: \(ce.title)")
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
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}
