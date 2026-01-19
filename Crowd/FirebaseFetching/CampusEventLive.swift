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

    // Made optional to support both campus_events_live and events_from_official_raw schemas
    let sourceType: String?
    let sourceOrg: String?
    let sourceUrl: String?
    // events_from_official_raw uses different field names
    let organization: String?  // alias for sourceOrg
    let url: String?           // alias for sourceUrl
    
    let tags: [String]?
    let imageUrl: String?

    let confidence: Double?
    let createdAt: Timestamp?
    let lastSeenAt: Timestamp?

    // Optional coordinates persisted by backend geocoding
    let latitude: Double?
    let longitude: Double?
    let geohash: String?
}
