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
    case musicEntertainment = "Music & Entertainment"
    case foodDining = "Food & Dining"
    case sportsFitness = "Sports & Fitness"
    case academicEducation = "Academic & Education"
    case artsCulture = "Arts & Culture"
    case socialNetworking = "Social & Networking"
    case healthWellness = "Health & Wellness"
    case outdoorNature = "Outdoor & Nature"
    case gamingEntertainment = "Gaming & Entertainment"
    case lifestyleHobbies = "Lifestyle & Hobbies"
    case politicsActivism = "Politics & Activism"
    case specialEvents = "Special Events"
    case other = "Just Vibing"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .musicEntertainment: return "🎵"
        case .foodDining: return "🍕"
        case .sportsFitness: return "⚽"
        case .academicEducation: return "📚"
        case .artsCulture: return "🎨"
        case .socialNetworking: return "🤝"
        case .healthWellness: return "🏥"
        case .outdoorNature: return "🏔️"
        case .gamingEntertainment: return "🎮"
        case .lifestyleHobbies: return "👗"
        case .politicsActivism: return "🏛️"
        case .specialEvents: return "🎉"
        case .other: return "🫂"
        }
    }

    var displayName: String {
        "\(emoji) \(rawValue)"
    }
    
    // Tag mapping for each category
    private var tagKeywords: [String] {
        switch self {
        case .musicEntertainment:
            return ["music", "concert", "party", "festival", "dance", "dancing", "live", "performance"]
        case .foodDining:
            return ["food", "dining", "restaurant", "cafe", "coffee", "lunch", "dinner", "breakfast", "snack"]
        case .sportsFitness:
            return ["sports", "basketball", "football", "soccer", "tennis", "volleyball", "baseball", "fitness", "gym", "workout", "yoga", "running", "cycling"]
        case .academicEducation:
            return ["study", "academic", "lecture", "workshop", "seminar", "conference", "education", "learning", "research", "science", "tech", "technology", "coding", "programming"]
        case .artsCulture:
            return ["art", "creative", "culture", "cultural", "international", "language", "film", "movie", "theater", "drama", "comedy", "standup", "photography", "gallery"]
        case .socialNetworking:
            return ["networking", "meetup", "community", "volunteer", "charity", "fundraising", "career", "job", "business", "entrepreneur", "startup"]
        case .healthWellness:
            return ["health", "wellness", "mental", "spiritual", "religious", "faith", "meditation", "mindfulness"]
        case .outdoorNature:
            return ["outdoor", "hiking", "camping", "nature", "environment", "sustainability", "travel", "adventure"]
        case .gamingEntertainment:
            return ["gaming", "esports", "board", "trivia", "puzzle", "card"]
        case .lifestyleHobbies:
            return ["fashion", "beauty", "cooking", "baking", "wine", "beer", "tea", "book", "reading", "writing", "poetry", "blog"]
        case .politicsActivism:
            return ["politics", "debate", "activism", "protest", "voting", "election"]
        case .specialEvents:
            return ["graduation", "celebration", "anniversary", "birthday", "holiday", "christmas", "halloween", "valentine", "newyear"]
        case .other:
            return ["official", "student", "instagram", "social"]
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

    // Simple classifier that defaults to "other" since we now use tag-based matching
    static func guess(from title: String, sourceType: String, locationName: String?) -> EventCategory {
        return .other
    }
}
