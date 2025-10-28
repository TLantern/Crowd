//
//  EventCategory.swift
//  Crowd
//
//  Maps high-level buckets to emoji.
//  Also provides a static classifier guess(from:)
//  so we can assign an emoji to scraped events.
//

import Foundation

enum EventCategory: String, CaseIterable, Identifiable {
    case party = "Party"
    case studySession = "Study Session"
    case sports = "Sports/Fitness"
    case food = "Food/Dining"
    case gaming = "Gaming"
    case music = "Music/Concert"
    case hangout = "Coffee/Hangout"
    case coffeeHangout = "Coffee Meetup"
    case outdoors = "Outdoors"
    case pickupGame = "Pickup Game"
    case movie = "Movie/Watch Party"
    case networking = "Networking"
    case official = "Official/University"
    case unknown = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .party: return "🎉"
        case .studySession: return "📚"
        case .sports: return "⚽"
        case .food: return "🍕"
        case .gaming: return "🎮"
        case .music: return "🎵"
        case .hangout: return "☕"
        case .coffeeHangout: return "☕"
        case .outdoors: return "🌲"
        case .pickupGame: return "🏀"
        case .movie: return "🎬"
        case .networking: return "💼"
        case .official: return "🏫"
        case .unknown: return "📍"
        }
    }

    var displayName: String {
        "\(emoji) \(rawValue)"
    }

    // crude text-based classifier
    static func guess(from title: String, sourceType: String, locationName: String?) -> EventCategory {
        let lower = title.lowercased()
        let locLower = (locationName ?? "").lowercased()
        let combined = lower + " " + locLower

        if sourceType == "official" {
            return .official
        }
        if combined.contains("party")
            || combined.contains("bash")
            || combined.contains("kickback")
            || combined.contains("mixer")
            || combined.contains("fest") {
            return .party
        }
        if combined.contains("study")
            || combined.contains("tutoring")
            || combined.contains("exam prep") {
            return .studySession
        }
        if combined.contains("basketball")
            || combined.contains("soccer")
            || combined.contains("pickup")
            || combined.contains("open gym")
            || combined.contains("workout")
            || combined.contains("intramural") {
            return .pickupGame
        }
        if combined.contains("game night")
            || combined.contains("smash")
            || combined.contains("tourney")
            || combined.contains("2k")
            || combined.contains("lan party")
            || combined.contains("gaming") {
            return .gaming
        }
        if combined.contains("live music")
            || combined.contains("concert")
            || combined.contains("open mic")
            || combined.contains("dj")
            || combined.contains("showcase") {
            return .music
        }
        if combined.contains("movie")
            || combined.contains("watch party")
            || combined.contains("screening") {
            return .movie
        }
        if combined.contains("meet and greet")
            || combined.contains("info session")
            || combined.contains("interest meeting")
            || combined.contains("network")
            || combined.contains("career") {
            return .networking
        }
        if combined.contains("pizza")
            || combined.contains("wings")
            || combined.contains("food")
            || combined.contains("bbq")
            || combined.contains("cookout")
            || combined.contains("taco") {
            return .food
        }
        if combined.contains("coffee")
            || combined.contains("hangout")
            || combined.contains("chill")
            || combined.contains("link up") {
            return .hangout
        }

        return .unknown
    }
}
