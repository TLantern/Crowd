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
    } else {
        descPieces.append("Hosted by \(live.sourceOrg)")
    }
    var description = descPieces.joined(separator: " • ")

    // parse start/end from the time range string
    let (startsAtDate, endsAtDate) = parseTimeRange(live.startTimeLocal)

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

    var ev = CrowdEvent.newDraft(
        at: fallbackCoord,
        title: displayTitle,
        hostId: live.sourceOrg,
        hostName: live.sourceOrg,
        category: cat.rawValue,
        description: description.isEmpty ? nil : description,
        startsAt: startsAtDate,
        endsAt: endsAtDate,
        tags: tags,
        sourceURL: validSource
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
