import Foundation

enum TagEmoji {
    private static let tagEmojis: [String: String] = [
        // Music & Entertainment
        "music": "🎵", "concert": "🎤", "party": "🎉", "festival": "🎪", "dance": "💃",
        "dancing": "💃", "live": "🎵", "performance": "🎭",
        // Food & Dining
        "food": "🍕", "dining": "🍽️", "restaurant": "🍽️", "cafe": "☕", "coffee": "☕",
        "lunch": "🍽️", "dinner": "🍽️", "breakfast": "🥞", "snack": "🍿",
        // Sports & Fitness
        "sports": "⚽", "basketball": "🏀", "football": "🏈", "soccer": "⚽", "tennis": "🎾",
        "volleyball": "🏐", "baseball": "⚾", "fitness": "💪", "gym": "💪", "workout": "💪",
        "yoga": "🧘", "running": "🏃", "cycling": "🚴",
        // Academic & Education
        "study": "📚", "academic": "🎓", "lecture": "🎓", "workshop": "🔧", "seminar": "🎓",
        "conference": "🎓", "education": "🎓", "learning": "📚", "research": "🔬", "science": "🔬",
        "tech": "💻", "technology": "💻", "coding": "💻", "programming": "💻",
        // Arts & Culture
        "art": "🎨", "creative": "🎨", "culture": "🌍", "cultural": "🌍", "international": "🌍",
        "language": "🗣️", "film": "🎬", "movie": "🎬", "theater": "🎭", "drama": "🎭",
        "comedy": "😂", "standup": "🎤", "photography": "📸", "gallery": "🖼️",
        // Social & Networking
        "networking": "🤝", "meetup": "👥", "community": "🏘️", "volunteer": "🤝", "charity": "❤️",
        "fundraising": "💰", "career": "💼", "job": "💼", "business": "💼", "entrepreneur": "🚀",
        "startup": "🚀",
        // Health & Wellness
        "health": "🏥", "wellness": "💚", "mental": "🧠", "spiritual": "🙏", "religious": "⛪",
        "faith": "⛪", "meditation": "🧘", "mindfulness": "🧘",
        // Outdoor & Nature
        "outdoor": "🏔️", "hiking": "🥾", "camping": "⛺", "nature": "🌿", "environment": "🌱",
        "sustainability": "🌱", "travel": "✈️", "adventure": "🗺️",
        // Gaming & Entertainment
        "gaming": "🎮", "esports": "🎮", "board": "🎲", "trivia": "🧠", "puzzle": "🧩", "card": "🃏",
        // Lifestyle & Hobbies
        "fashion": "👗", "beauty": "💄", "cooking": "👨‍🍳", "baking": "🧁", "wine": "🍷",
        "beer": "🍺", "tea": "🍵", "book": "📖", "reading": "📖", "writing": "✍️",
        "poetry": "📝", "blog": "✍️",
        // Politics & Activism
        "politics": "🏛️", "debate": "🗣️", "activism": "✊", "protest": "✊", "voting": "🗳️",
        "election": "🗳️",
        // Special Events
        "graduation": "🎓", "celebration": "🎉", "anniversary": "🎂", "birthday": "🎂",
        "holiday": "🎄", "christmas": "🎄", "halloween": "🎃", "valentine": "💕", "newyear": "🎊",
        // Source Types
        "official": "🏛️", "student": "🎓", "instagram": "📸", "social": "👥"
    ]

    static func emoji(for tags: [String], fallbackCategory: String?) -> String {
        // First, try to match tags directly
        for tag in tags {
            let key = tag.lowercased()
            if let e = tagEmojis[key] { return e }
        }
        // Then try partial matches in tags
        if let first = tags.first?.lowercased() {
            for (keyword, e) in tagEmojis where first.contains(keyword) { return e }
        }
        // Fallback to category emoji if category exists
        if let cat = fallbackCategory, let ec = EventCategory(rawValue: cat) {
            // Try to get emoji from category's default tag first
            let defaultTag = ec.defaultTag
            if let e = tagEmojis[defaultTag.lowercased()] {
                return e
            }
            // Otherwise use category's emoji directly
            return ec.emoji
        }
        // Last resort: use "Just Vibing" category emoji instead of calendar
        return EventCategory.other.emoji
    }
}



