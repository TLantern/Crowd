//
//  CrowdEvent.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation

struct CrowdEvent: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var hostId: String

    // Codable-friendly storage
    var latitude: Double
    var longitude: Double

    var radiusMeters: Double
    var startsAt: Date?
    var endsAt: Date?
    var createdAt: Date
    var signalStrength: Int
    var attendeeCount: Int
    var tags: [String]

    // Convenience computed property for MapKit
    var coordinates: CLLocationCoordinate2D {
        get { .init(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    static func newDraft(at coord: CLLocationCoordinate2D, title: String) -> Self {
        CrowdEvent(
            id: UUID().uuidString,
            title: title,
            hostId: "anon",
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: Date(),
            signalStrength: 0,
            attendeeCount: 0,
            tags: []
        )
    }
}
