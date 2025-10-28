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

                self.crowdEvents = mapped
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}
