//
//  CampusEventLive.swift
//  Crowd
//
//  Mirrors Firestore docs in `campus_events_live`
//

import Foundation
import FirebaseFirestore
// import FirebaseFirestoreSwift//

struct CampusEventLive: Codable, Identifiable {
    @DocumentID var id: String?

    let title: String
    let locationName: String?
    let startTimeLocal: String?
    let endTimeLocal: String?

    let sourceType: String        // "instagram" or "official"
    let sourceOrg: String         // "bsu_unt" or "UNT Official"
    let sourceUrl: String

    let confidence: Double?
    let createdAt: Timestamp?
    let lastSeenAt: Timestamp?
}
