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

    // Energy-friendly: one-time fetch with ordering and limit. Heavy work off main thread.
    func fetchOnce(limit: Int = 25) async {
        let db = Firestore.firestore()
        print("🔄 CampusEventsViewModel: One-time fetch from campus_events_live (limit: \(limit))")
        do {
            let snap = try await db.collection("campus_events_live")
                .order(by: "startTimeLocal")
                .limit(to: limit)
                .getDocuments()

            let docs = snap.documents
            print("📊 CampusEventsViewModel: Received \(docs.count) docs (one-time)")

            let mapped: [CrowdEvent] = try await Task.detached(priority: .utility) {
                var tmp: [CrowdEvent] = []
                for d in docs {
                    if let live = try? d.data(as: CampusEventLive.self),
                       let ce = mapCampusEventLiveToCrowdEvent(live) {
                        tmp.append(ce)
                    }
                }
                tmp.sort { (a, b) in
                    let aStart = a.startsAt ?? .distantFuture
                    let bStart = b.startsAt ?? .distantFuture
                    return aStart < bStart
                }
                return tmp
            }.value

            await MainActor.run {
                self.crowdEvents = mapped
                print("🎯 CampusEventsViewModel: Final mapped events count: \(mapped.count) (one-time)")
            }
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

                for d in docs {
                    do {
                        let live = try d.data(as: CampusEventLive.self)
                        print("📝 CampusEventsViewModel: Parsed CampusEventLive: \(live.title)")
                        
                        if let ce = mapCampusEventLiveToCrowdEvent(live) {
                            print("✅ CampusEventsViewModel: Mapped to CrowdEvent: \(ce.title)")
                            mapped.append(ce)
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
                for event in mapped {
                    print("   - \(event.title) (starts: \(event.startsAt?.description ?? "nil"))")
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
