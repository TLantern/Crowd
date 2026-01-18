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

    var time: Date?             // Deprecated: use startTime instead (kept for backward compatibility)
    var startTime: Date?        // Event start time
    var endTime: Date?          // Event end time
    var createdAt: Date

    var signalStrength: Int
    var attendeeCount: Int

    var tags: [String]
    var category: String?
    var description: String?
    var sourceURL: String?
    var rawLocationName: String?
    var imageURL: String?
    var ticketURL: String?
    var dateTime: String?      // Unformatted dateTime string from Firebase (for parties)
    var rawDateTime: String?   // Unformatted dateTime string from Firebase (for school events)

    var coordinates: CLLocationCoordinate2D {
        get { .init(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    /// Formatted date string for display (e.g., "Today at 3:00 PM", "Tomorrow at 2:30 PM")
    var dateFormatted: String? {
        // Use startTime if available, fallback to legacy time field
        guard let date = startTime ?? time else { return nil }
        
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
        time: Date? = nil,          // Deprecated: use startTime/endTime
        startTime: Date? = nil,
        endTime: Date? = nil,
        tags: [String] = [],
        sourceURL: String? = nil,
        rawLocationName: String? = nil,
        imageURL: String? = nil,
        dateTime: String? = nil,
        rawDateTime: String? = nil
    ) -> Self {
        // Ensure category is never nil - default to "Chill Hangout"
        let finalCategory = category ?? EventCategory.chillHangout.rawValue
        
        // Ensure tags are never empty - generate from category if needed
        var finalTags = tags
        if finalTags.isEmpty {
            if let cat = EventCategory(rawValue: finalCategory) {
                finalTags = [cat.defaultTag]
            } else {
                finalTags = [EventCategory.chillHangout.defaultTag]
            }
        }
        
        return CrowdEvent(
            id: UUID().uuidString,
            title: title,
            hostId: hostId,
            hostName: hostName,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: 0,
            time: time ?? startTime,  // For backward compatibility, set time to startTime
            startTime: startTime ?? time,  // Use startTime if provided, fallback to time
            endTime: endTime,
            createdAt: Date(),
            signalStrength: 0,
            attendeeCount: 0,
            tags: finalTags,
            category: finalCategory,
            description: description,
            sourceURL: sourceURL,
            rawLocationName: rawLocationName,
            imageURL: imageURL,
            ticketURL: nil,
            dateTime: dateTime,
            rawDateTime: rawDateTime
        )
    }
}
