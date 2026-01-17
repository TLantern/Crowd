//
//  CrowdEventMapping.swift
//  Crowd
//
//  Convert CampusEventLive (Firestore normalized feed)
//  -> CrowdEvent (app internal model with coords etc.)
//  Adds emoji via EventCategory.guess
//

import Foundation
import CoreLocation

// UNT fallback coordinate for now.
// Later replace with geocoded building coords.
private let fallbackCoord = CLLocationCoordinate2D(
    latitude: 33.2100,
    longitude: -97.1500
)

// University Union coordinates from HostEventSheet.swift line 29
// Any location containing "union" should use these coordinates
private let universityUnionCoord = CLLocationCoordinate2D(
    latitude: 33.2098926,
    longitude: -97.1514762
)

// Try to match raw location text to predefined UNT locations (see HostEventSheet.untLocations)
func matchUNTLocationCoordinate(for raw: String?) -> CLLocationCoordinate2D? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    let text = raw.lowercased()
    
    // Any location containing "union" should use University Union coordinates (no geocoding)
    if text.contains("union") {
        return universityUnionCoord
    }

    // Simple aliases for common variations
    let aliasToCanonical: [String: String] = [
        "union": "university union",
        "union main floor": "union main floor",
        "union – main floor": "union main floor",
        "university union – main floor": "union main floor",
        "super pit": "super pit (unt coliseum)",
        "coliseum": "super pit (unt coliseum)",
        "library": "willis library",
        "willis library, floor": "willis library",
        "willis library floor": "willis library",
        "eagle landing": "eagle landing dining hall",
        "b.l.b": "business leadership building",
        "blb": "business leadership building",
        "stadium": "datcu stadium",
        "rec": "pohl recreation center",
        "pohl rec center": "pohl recreation center",
        "basketball courts": "pohl recreation center",
        "music": "unt music building",
        "art": "art building",
        "square": "denton square"
    ]

    let normalizedTarget: String = {
        for (alias, canonical) in aliasToCanonical {
            if text.contains(alias) { return canonical }
        }
        return text
    }()

    // Iterate untLocations defined in HostEventSheet.swift
    for loc in untLocations {
        let candidate = loc.name.lowercased()
        if candidate == normalizedTarget || normalizedTarget.contains(candidate) || candidate.contains(normalizedTarget) {
            return loc.coordinate
        }
    }
    return nil
}

// Find closest known location based on coordinates
func findClosestLocationName(for coordinate: CLLocationCoordinate2D) -> String? {
    let eventLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    var closestLocation: PredefinedLocation?
    var closestDistance: CLLocationDistance = Double.infinity
    
    for location in untLocations {
        let locationPoint = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let distance = eventLocation.distance(from: locationPoint)
        
        if distance < closestDistance {
            closestDistance = distance
            closestLocation = location
        }
    }
    
    // Only return if within reasonable distance (500 meters)
    if let closest = closestLocation, closestDistance <= 500 {
        return closest.name
    }
    
    return nil
}

func mapCampusEventLiveToCrowdEvent(_ live: CampusEventLive) -> CrowdEvent? {
    let rawTitle = live.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawTitle.isEmpty else { return nil }

    // choose category + emoji
    let cat = EventCategory.guess(
        from: rawTitle,
        sourceType: live.sourceType,
        locationName: live.locationName
    )
    let emoji = cat.emoji

    // build a human-readable short description
    // Line 1: "Union rm 241 • Posted by @bsu_unt"
    // Line 2: "Oct 31, 7:00 PM – 11:00 PM" (if available)
    var descPieces: [String] = []
    if let loc = live.locationName, !loc.isEmpty { descPieces.append(loc) }
    if live.sourceType == "instagram" {
        descPieces.append("Posted by @\(live.sourceOrg)")
    }
    var description = descPieces.joined(separator: " • ")

    // parse start/end from the rawDateTime field (Firebase dateTime for school events)
    let (startsAtDate, endsAtDate) = parseTimeRange(live.rawDateTime)

    if let startsAtDate {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        var timeLine = fmt.string(from: startsAtDate)
        if let endsAtDate { timeLine += " – " + fmt.string(from: endsAtDate) }
        description = [description, timeLine].joined(separator: "\n")
    }

    // Use tags from Firebase, fallback to generated tags if none provided
    var tags: [String] = live.tags ?? []
    if tags.isEmpty {
        if live.sourceType == "official" {
            tags.append("official")
        } else {
            tags.append("student")
        }
    }

    // Use clean title without emoji
    let displayTitle = rawTitle

    // Only keep a valid http(s) source URL
    let cleanedSource = live.sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    let validSource: String? = {
        guard !cleanedSource.isEmpty else { return nil }
        if cleanedSource.lowercased().hasPrefix("http://") || cleanedSource.lowercased().hasPrefix("https://") {
            return cleanedSource
        }
        return nil
    }()

    // Prefer backend geocoded coordinates if provided on the live doc
    let coord: CLLocationCoordinate2D = {
        if let lat = live.latitude, let lon = live.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let byLocName = matchUNTLocationCoordinate(for: live.locationName ?? live.location) {
            return byLocName
        }
        return fallbackCoord
    }()

    // Extract image URL from Firestore (handles both imageUrl and imageURL)
    let imageURL: String? = {
        if let url = live.imageUrl, !url.isEmpty {
            return url.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }()
    
    var ev = CrowdEvent.newDraft(
        at: coord,
        title: displayTitle,
        hostId: live.sourceOrg,
        hostName: live.sourceOrg,
        category: cat.rawValue,
        description: description.isEmpty ? nil : description,
        time: startsAtDate,
        tags: tags,
        sourceURL: validSource,
        rawLocationName: (live.locationName?.isEmpty == false ? live.locationName : live.location),
        imageURL: imageURL,
        rawDateTime: live.rawDateTime
    )
    // Use source document id when available so the same event keeps a stable id across fetches
    if let liveId = live.id, !liveId.isEmpty { ev.id = liveId }
    return ev
}

// Parse time range string like "Tuesday, October 28, 2025 at 10:00 AM to Tuesday, October 28, 2025 at 11:00 AM"
// or single time like "Tuesday, October 28, 2025 at 12:00 AM"
private func parseTimeRange(_ timeString: String?) -> (start: Date?, end: Date?) {
    guard let timeString = timeString else {
        return (nil, nil)
    }
    
    // Create formatter for the date format
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    
    // Check if it's a range (contains " to ")
    if timeString.contains(" to ") {
        let components = timeString.components(separatedBy: " to ")
        guard components.count == 2 else {
            return (nil, nil)
        }
        
        let startDate = formatter.date(from: components[0].trimmingCharacters(in: .whitespaces))
        let endDate = formatter.date(from: components[1].trimmingCharacters(in: .whitespaces))
        
        return (startDate, endDate)
    } else {
        // Single time point
        let date = formatter.date(from: timeString.trimmingCharacters(in: .whitespaces))
        return (date, nil)
    }
}
