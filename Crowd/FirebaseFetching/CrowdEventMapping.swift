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
    // Example: "Union rm 241 • Posted by @bsu_unt"
    var descPieces: [String] = []
    if let loc = live.locationName, !loc.isEmpty {
        descPieces.append(loc)
    }
    if live.sourceType == "instagram" {
        descPieces.append("Posted by @\(live.sourceOrg)")
    } else {
        descPieces.append("Hosted by \(live.sourceOrg)")
    }
    let description = descPieces.joined(separator: " • ")

    // parse start/end
    let startsAtDate = isoToDate(live.startTimeLocal)
    let endsAtDate   = isoToDate(live.endTimeLocal)

    // tags array can include emoji and maybe source info
    var tags: [String] = [emoji]
    if live.sourceType == "official" {
        tags.append("official")
    } else {
        tags.append("student")
    }

    // title shown to user should include emoji up front for fast scanning
    // Example: "🎉 Halloween Bash"
    let displayTitle = "\(emoji) \(rawTitle)"

    let ev = CrowdEvent.newDraft(
        at: fallbackCoord,
        title: displayTitle,
        hostId: live.sourceOrg,
        hostName: live.sourceOrg,
        category: cat.rawValue,
        description: description.isEmpty ? nil : description,
        startsAt: startsAtDate,
        endsAt: endsAtDate,
        tags: tags
    )

    return ev
}

// ISO8601 -> Date helper
private func isoToDate(_ iso: String?) -> Date? {
    guard let iso = iso else { return nil }

    // First with fractional seconds
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds,
        .withColonSeparatorInTimeZone
    ]
    if let d = fmt.date(from: iso) { return d }

    // Fallback without fractional seconds
    let fmt2 = ISO8601DateFormatter()
    fmt2.formatOptions = [
        .withInternetDateTime,
        .withColonSeparatorInTimeZone
    ]
    return fmt2.date(from: iso)
}
