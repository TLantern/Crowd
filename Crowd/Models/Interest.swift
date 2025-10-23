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
    
    // MARK: - Preloaded Interests (50)
    static let allInterests: [Interest] = [
        // Entertainment & Arts
        Interest(emoji: "🎵", name: "Music"),
        Interest(emoji: "🎸", name: "Rock"),
        Interest(emoji: "🎹", name: "Jazz"),
        Interest(emoji: "🎤", name: "Karaoke"),
        Interest(emoji: "🎬", name: "Movies"),
        Interest(emoji: "📺", name: "TV Shows"),
        Interest(emoji: "🎨", name: "Art"),
        Interest(emoji: "🖼️", name: "Museums"),
        Interest(emoji: "📸", name: "Photography"),
        Interest(emoji: "🎭", name: "Theater"),
        
        // Sports & Fitness
        Interest(emoji: "🏀", name: "Basketball"),
        Interest(emoji: "⚽", name: "Soccer"),
        Interest(emoji: "🏈", name: "Football"),
        Interest(emoji: "⚾", name: "Baseball"),
        Interest(emoji: "🎾", name: "Tennis"),
        Interest(emoji: "🏊", name: "Swimming"),
        Interest(emoji: "🏋️", name: "Gym"),
        Interest(emoji: "🧘", name: "Yoga"),
        Interest(emoji: "🚴", name: "Cycling"),
        Interest(emoji: "🏃", name: "Running"),
        
        // Food & Drink
        Interest(emoji: "🍕", name: "Pizza"),
        Interest(emoji: "🍔", name: "Burgers"),
        Interest(emoji: "🍣", name: "Sushi"),
        Interest(emoji: "🍜", name: "Ramen"),
        Interest(emoji: "☕", name: "Coffee"),
        Interest(emoji: "🍵", name: "Tea"),
        Interest(emoji: "🍷", name: "Wine"),
        Interest(emoji: "🍰", name: "Desserts"),
        Interest(emoji: "🌮", name: "Tacos"),
        Interest(emoji: "🥗", name: "Healthy Food"),
        
        // Technology & Gaming
        Interest(emoji: "💻", name: "Tech"),
        Interest(emoji: "🎮", name: "Gaming"),
        Interest(emoji: "📱", name: "Mobile Apps"),
        Interest(emoji: "🤖", name: "AI"),
        Interest(emoji: "🚀", name: "Startups"),
        Interest(emoji: "⌨️", name: "Coding"),
        
        // Learning & Social
        Interest(emoji: "📚", name: "Reading"),
        Interest(emoji: "✍️", name: "Writing"),
        Interest(emoji: "🧠", name: "Study"),
        Interest(emoji: "💬", name: "Social"),
        Interest(emoji: "🎓", name: "Academia"),
        Interest(emoji: "🌍", name: "Travel"),
        Interest(emoji: "🗺️", name: "Adventure"),
        Interest(emoji: "🏕️", name: "Camping"),
        
        // Lifestyle & Hobbies
        Interest(emoji: "🎲", name: "Board Games"),
        Interest(emoji: "🧩", name: "Puzzles"),
        Interest(emoji: "🐕", name: "Pets"),
        Interest(emoji: "🌱", name: "Gardening"),
        Interest(emoji: "👗", name: "Fashion"),
        Interest(emoji: "💄", name: "Beauty")
    ]
}

