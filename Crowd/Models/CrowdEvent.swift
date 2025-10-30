//
//  CrowdEvent.swift
//  Crowd
//
//  Core in-app event model used by map/list UI.
//

import Foundation
import CoreLocation

struct CrowdEvent: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var hostId: String
    var hostName: String

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
    var sourceURL: String?

    var coordinates: CLLocationCoordinate2D {
        get { .init(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    /// Formatted date string for display (e.g., "Today at 3:00 PM", "Tomorrow at 2:30 PM")
    var dateFormatted: String? {
        guard let date = startsAt else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if calendar.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // Within this week - show day name
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE 'at' "
            return dayFormatter.string(from: date) + formatter.string(from: date)
        } else {
            // Future date - show month/day
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d 'at' "
            return dateFormatter.string(from: date) + formatter.string(from: date)
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
        endsAt: Date? = nil,
        tags: [String] = [],
        sourceURL: String? = nil
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
            tags: tags,
            category: category,
            description: description,
            sourceURL: sourceURL
        )
    }
}
