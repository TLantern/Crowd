//
//  CampusEventsViewModel.swift
//  Crowd
//
//  Listens to Firestore `campus_events_live` (the unified feed from IG + official).
//  Produces [CrowdEvent] ready for UI and map.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

final class CampusEventsViewModel: ObservableObject {
    @Published var crowdEvents: [CrowdEvent] = []

    private var listener: ListenerRegistration?

    func start() {
        let db = Firestore.firestore()

        listener = db.collection("campus_events_live")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                guard err == nil else { return }
                guard let docs = snap?.documents else { return }

                var mapped: [CrowdEvent] = []

                for d in docs {
                    if let live = try? d.data(as: CampusEventLive.self) {
                        if let ce = mapCampusEventLiveToCrowdEvent(live) {
                            mapped.append(ce)
                        }
                    }
                }

                // sort by soonest start time
                mapped.sort { a, b in
                    let aStart = a.startsAt ?? .distantFuture
                    let bStart = b.startsAt ?? .distantFuture
                    return aStart < bStart
                }

                self.crowdEvents = mapped
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}
