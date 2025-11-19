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
    case studySession = "Study Session"
    case gymMeetup = "Gym Meetup"
    case foodRun = "Food Run"
    case chillHangout = "Chill Hangout"
    case gameNight = "Game Night"
    case kickback = "Kickback"
    case party = "Party"
    case clubEvent = "Club Event"
    case outdoorActivity = "Outdoor Activity"
    case careerAcademic = "Career and Academic Boost"
    case artActivity = "Art & Creative Session"
    case politicalDiscussion = "Politics & Debate"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .studySession: return "📚"
        case .gymMeetup: return "💪"
        case .foodRun: return "🍔"
        case .chillHangout: return "🛋️"
        case .gameNight: return "🎮"
        case .kickback: return "🥤"
        case .party: return "🎉"
        case .clubEvent: return "🏛️"
        case .outdoorActivity: return "🏀"
        case .careerAcademic: return "💼"
        case .artActivity: return "🎨"
        case .politicalDiscussion: return "🗳️"
        }
    }

    var displayName: String {
        "\(emoji) \(rawValue)"
    }
    
    // Get a default tag keyword for this category (used when creating events)
    var defaultTag: String {
        switch self {
        case .studySession: return "study"
        case .gymMeetup: return "gym"
        case .foodRun: return "food"
        case .chillHangout: return "chill"
        case .gameNight: return "gaming"
        case .kickback: return "social"
        case .party: return "party"
        case .clubEvent: return "club"
        case .outdoorActivity: return "outdoor"
        case .careerAcademic: return "career"
        case .artActivity: return "art"
        case .politicalDiscussion: return "politics"
        }
    }
    
    // Tag mapping for each category
    private var tagKeywords: [String] {
        switch self {
        case .studySession:
            return ["study", "homework", "exam", "project", "academic", "learning"]
        case .gymMeetup:
            return ["gym", "lift", "workout", "fitness", "train", "exercise"]
        case .foodRun:
            return ["food", "snack", "drink", "restaurant", "cafe", "dining"]
        case .chillHangout:
            return ["chill", "hangout", "relax", "social", "talk", "music"]
        case .gameNight:
            return ["game", "gaming", "board", "card", "video", "esports"]
        case .kickback:
            return ["kickback", "social", "meetup", "dorm", "apartment"]
        case .party:
            return ["party", "pregame", "music", "drinks", "celebration"]
        case .clubEvent:
            return ["club", "organization", "meeting", "practice", "event"]
        case .outdoorActivity:
            return ["outdoor", "basketball", "soccer", "frisbee", "walking", "sports"]
        case .careerAcademic:
            return ["career", "resume", "interview", "tutoring", "academic", "support"]
        case .artActivity:
            return ["art", "creative", "drawing", "painting", "photography", "crafting"]
        case .politicalDiscussion:
            return ["politics", "debate", "discussion", "political", "voting"]
        }
    }
    
    // Check if event tags match this category
    func matchesTags(_ tags: [String]) -> Bool {
        for tag in tags {
            let lowercaseTag = tag.lowercased()
            for keyword in tagKeywords {
                if lowercaseTag.contains(keyword.lowercased()) {
                    return true
                }
            }
        }
        return false
    }

    // Simple classifier that defaults to chillHangout since we now use tag-based matching
    static func guess(from title: String, sourceType: String, locationName: String?) -> EventCategory {
        return .chillHangout
    }
}
