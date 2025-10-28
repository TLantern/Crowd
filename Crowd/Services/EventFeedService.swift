//
//  EventFeedService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import Foundation
import FirebaseFirestore
// import FirebaseFirestoreSwift
import CoreLocation
import Combine

// 1. Firestore model (matches documents in `events_from_instagram`)
struct InstagramEventRecord: Codable, Identifiable {
    @DocumentID var id: String?

    let orgHandle: String
    let postUrl: String
    let rawCaption: String

    let parsed: ParsedBlock
    let confidence: Double

    struct ParsedBlock: Codable {
        let title: String?
        let locationName: String?
        let startTimeLocal: String? // ISO string e.g. "2025-10-27T19:00:00-05:00"
    }
}

// 2. Utility to convert ISO timestamp from scraper into Date in local tz
private func parseStartTimeLocal(_ iso: String?) -> Date? {
    guard let iso else { return nil }

    // ISO may include offset like -05:00. Use ISO8601DateFormatter.
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds,
        .withColonSeparatorInTimeZone
    ]

    // Try with fractional seconds
    if let d = fmt.date(from: iso) {
        return d
    }

    // Try again without fractional second requirement
    let fmt2 = ISO8601DateFormatter()
    fmt2.formatOptions = [
        .withInternetDateTime,
        .withColonSeparatorInTimeZone
    ]
    return fmt2.date(from: iso)
}

// 3. Mapping InstagramEventRecord -> CrowdEvent using your newDraft initializer
//
// Assumptions you have in app somewhere:
// struct CrowdEvent { ... }
//
// extension CrowdEvent {
//     static func newDraft(
//         at coord: CLLocationCoordinate2D,
//         title: String,
//         hostId: String = "anon",
//         hostName: String = "Guest",
//         category: String? = nil,
//         description: String? = nil,
//         startsAt: Date? = nil,
//         endsAt: Date? = nil
//     ) -> CrowdEvent { ... }
// }
//
// We will map like this:
// - coord: you do NOT have a geo coordinate from IG. So we set a fallback, like campus center.
//   You should later geocode `locationName` -> coord. For now we hardcode a neutral campus centroid.
// - title: parsed.title or fallback first words of rawCaption
// - hostId / hostName: orgHandle
// - description: rawCaption
// - startsAt: parsed.startTimeLocal
// - endsAt: nil (Instagram rarely posts explicit end times)
// - category: we can attempt to infer later (ex: "party", "meeting"). For now nil.
private func mapInstagramRecordToCrowdEvent(
    _ rec: InstagramEventRecord
) -> CrowdEvent? {

    // Fallback title
    let fallbackTitle = rec.parsed.title?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty == false
        ? rec.parsed.title!
        : String(rec.rawCaption.split(separator: " ").prefix(5).joined(separator: " "))

    guard !fallbackTitle.isEmpty else {
        // If we have literally nothing meaningful, skip
        return nil
    }

    // Parse start time
    let startDate = parseStartTimeLocal(rec.parsed.startTimeLocal)

    // Fallback coordinate (UNT main campus approx). Replace with your campus region center constant.
    let fallbackCoord = CLLocationCoordinate2D(
        latitude: 33.2100,
        longitude: -97.1500
    )

    // host naming
    let hostName = rec.orgHandle
    let hostId   = rec.orgHandle

    let description = rec.rawCaption

    // build draft event
    let ev = CrowdEvent.newDraft(
        at: fallbackCoord,
        title: fallbackTitle,
        hostId: hostId,
        hostName: hostName,
        category: nil,
        description: description,
        startsAt: startDate,
        endsAt: nil
    )

    return ev
}

// 4. ViewModel to listen to Firestore, map, expose ready-to-render events.
// You can attach this to SwiftUI with @StateObject.
final class InstagramEventsViewModel: ObservableObject {
    @Published var crowdEvents: [CrowdEvent] = []

    private var listener: ListenerRegistration?

    // min confidence to trust parse
    private let minConfidence: Double = 0.6

    func startListening() {
        let db = Firestore.firestore()

        // Query high-confidence posts first so UI isn't trash.
        // You can also add a "startTimeLocal is upcoming" filter in the future
        listener = db.collection("events_from_instagram")
            .whereField("confidence", isGreaterThan: minConfidence)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard error == nil else {
                    // you could surface an error state if you want
                    return
                }
                guard let docs = snapshot?.documents else { return }

                var nextEvents: [CrowdEvent] = []

                for doc in docs {
                    do {
                        // decode Firestore -> InstagramEventRecord
                        let rec = try doc.data(as: InstagramEventRecord.self)

                        if let ev = mapInstagramRecordToCrowdEvent(rec) {
                            nextEvents.append(ev)
                        }
                    } catch {
                        // decoding failed for this doc, skip
                        continue
                    }
                }

                // Sort soonest first using startsAt if present
                nextEvents.sort { a, b in
                    let aStart = a.startsAt ?? .distantFuture
                    let bStart = b.startsAt ?? .distantFuture
                    return aStart < bStart
                }

                self.crowdEvents = nextEvents
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
