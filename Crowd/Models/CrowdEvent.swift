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
    var hostName: String

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
    var category: String?
    var description: String?

    // Convenience computed property for MapKit
    var coordinates: CLLocationCoordinate2D {
        get { .init(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    static func newDraft(
        at coord: CLLocationCoordinate2D,
        title: String,
        hostId: String = "anon",
        hostName: String = "Guest",
        category: String? = nil,
        description: String? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil
    ) -> Self {
        CrowdEvent(
            id: UUID().uuidString,
            title: title,
            hostId: hostId,
            hostName: hostName,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: 60,
            startsAt: startsAt,
            endsAt: endsAt,
            createdAt: Date(),
            signalStrength: 0,
            attendeeCount: 0,
            tags: [],
            category: category,
            description: description
        )
    }
}
