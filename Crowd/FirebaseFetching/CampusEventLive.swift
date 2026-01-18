//
//  CampusEventLive.swift
//  Crowd
//
//  Mirrors Firestore docs in `campus_events_live`
//

import Foundation
import FirebaseFirestore
struct CampusEventLive: Codable, Identifiable {
    var id: String?

    let title: String
    let locationName: String?
    let location: String?
    let rawDateTime: String?  // Firebase dateTime field for school events
    let endTimeLocal: String?

    let sourceType: String        // "instagram" or "official"
    let sourceOrg: String         // "bsu_unt" or "UNT Official"
    let sourceUrl: String
    let tags: [String]?           // Tags from Firebase
    let imageUrl: String?         // Image URL from Firestore (note: lowercase 'u' in Url)

    let confidence: Double?
    let createdAt: Timestamp?
    let lastSeenAt: Timestamp?

    // Optional coordinates persisted by backend geocoding
    let latitude: Double?
    let longitude: Double?
    let geohash: String?
}
