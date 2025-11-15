//
//  Anchor.swift
//  Crowd
//
//  Anchor model for location-based map pins with time-based visibility
//

import Foundation
import CoreLocation

struct Anchor: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let location: String
    let type: String
    let daysActive: [String]
    let anchorStartLocal: String
    let anchorEndLocal: String
    let sendNotification: Bool
    let notificationTimeLocal: String?
    let notificationMessage: String?
    let description: String
    
    // Geocoded coordinates (not in JSON, populated after loading)
    var latitude: Double?
    var longitude: Double?
    
    // Make Anchor mutable for coordinate updates
    mutating func updateCoordinates(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case location
        case type
        case daysActive = "days_active"
        case anchorStartLocal = "anchor_start_local"
        case anchorEndLocal = "anchor_end_local"
        case sendNotification = "send_notification"
        case notificationTimeLocal = "notification_time_local"
        case notificationMessage = "notification_message"
        case description
    }
    
    var coordinates: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Check if anchor is currently active based on day and time (America/Chicago timezone)
    var isActive: Bool {
        let chicagoTimeZone = TimeZone(identifier: "America/Chicago") ?? TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = chicagoTimeZone
        
        let now = Date()
        let chicagoNow = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        
        // Check if current day is in daysActive
        guard let currentWeekday = chicagoNow.weekday else { return false }
        // Map weekday number (1=Sunday, 2=Monday, etc.) to abbreviation
        let weekdayMap: [Int: String] = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        guard let weekdayAbbreviation = weekdayMap[currentWeekday] else { return false }
        guard daysActive.contains(weekdayAbbreviation) else { return false }
        
        // Parse time strings (HH:mm format)
        guard let startTime = parseTimeString(anchorStartLocal),
              let endTime = parseTimeString(anchorEndLocal) else {
            return false
        }
        
        let currentMinutes = (chicagoNow.hour ?? 0) * 60 + (chicagoNow.minute ?? 0)
        let startMinutes = startTime.hour * 60 + startTime.minute
        let endMinutes = endTime.hour * 60 + endTime.minute
        
        // Handle case where end time is next day (e.g., 22:00 to 02:00)
        if endMinutes < startMinutes {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour: hour, minute: minute)
    }
}

struct AnchorsConfig: Codable {
    let anchors: [Anchor]
}

