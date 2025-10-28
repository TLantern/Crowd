//
//  Interest.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import Foundation

struct Interest: Identifiable, Hashable, Codable {
    let id: String
    let emoji: String
    let name: String
    
    init(emoji: String, name: String) {
        self.id = UUID().uuidString
        self.emoji = emoji
        self.name = name
    }
    
    var displayName: String {
        "\(emoji) \(name)"
    }
    
    // MARK: - Preloaded Interests (matching onboarding)
    static let allInterests: [Interest] = [
        // Entertainment & Arts
        Interest(emoji: "🎧", name: "Music"),
        Interest(emoji: "🎤", name: "Singing"),
        Interest(emoji: "🎸", name: "Guitar"),
        Interest(emoji: "🥁", name: "Band Life"),
        Interest(emoji: "💃", name: "Dance"),
        Interest(emoji: "🎭", name: "Theatre"),
        Interest(emoji: "🎨", name: "Art & Design"),
        Interest(emoji: "📸", name: "Photography"),
        Interest(emoji: "🎥", name: "Filmmaking"),
        Interest(emoji: "🪶", name: "Writing"),
        Interest(emoji: "✏️", name: "Graphic Design"),
        
        // Sports & Fitness
        Interest(emoji: "🎮", name: "Gaming"),
        Interest(emoji: "🏀", name: "Basketball"),
        Interest(emoji: "⚽", name: "Soccer"),
        Interest(emoji: "🎾", name: "Tennis"),
        Interest(emoji: "🏈", name: "Football"),
        Interest(emoji: "🏋️", name: "Gym Life"),
        Interest(emoji: "🏃", name: "Running"),
        Interest(emoji: "🧗", name: "Adventure"),
        Interest(emoji: "🚴", name: "Biking"),
        Interest(emoji: "🧘", name: "Wellness"),
        
        // Food & Drink
        Interest(emoji: "☕", name: "Coffee Runs"),
        Interest(emoji: "🍕", name: "Foodie"),
        Interest(emoji: "🍔", name: "Late-Night Eats"),
        Interest(emoji: "🧑‍🍳", name: "Cooking"),
        
        // Technology & Business
        Interest(emoji: "🖥️", name: "Coding"),
        Interest(emoji: "🤖", name: "AI & Tech"),
        Interest(emoji: "🧬", name: "Science"),
        Interest(emoji: "💻", name: "Startups"),
        Interest(emoji: "💡", name: "Entrepreneurship"),
        Interest(emoji: "🧑‍💼", name: "Business"),
        Interest(emoji: "💸", name: "Investing"),
        Interest(emoji: "🎮", name: "Esports"),
        
        // Learning & Social
        Interest(emoji: "📚", name: "Study Sessions"),
        Interest(emoji: "💬", name: "Public Speaking"),
        Interest(emoji: "🎙️", name: "Podcasts"),
        Interest(emoji: "📰", name: "Campus News"),
        Interest(emoji: "📱", name: "Social Media"),
        Interest(emoji: "🌍", name: "Culture"),
        Interest(emoji: "♻️", name: "Sustainability"),
        Interest(emoji: "🔥", name: "Campus Events"),
        
        // Lifestyle & Fun
        Interest(emoji: "✈️", name: "Travel"),
        Interest(emoji: "🏖️", name: "Beach Days"),
        Interest(emoji: "🏕️", name: "Camping"),
        Interest(emoji: "🏡", name: "Chill Spots"),
        Interest(emoji: "🎉", name: "Parties"),
        Interest(emoji: "🕹️", name: "Retro Games"),
        Interest(emoji: "🐾", name: "Pets"),
        Interest(emoji: "🪩", name: "Nightlife"),
        Interest(emoji: "💞", name: "Dating & Friends")
    ]
}

