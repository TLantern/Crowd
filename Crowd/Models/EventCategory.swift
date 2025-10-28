//
//  EventCategory.swift
//  Crowd
//
//  Created by Teni Owojori on 10/25/25.
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
        }
    }
    
    var displayName: String {
        "\(emoji) \(rawValue)"
    }
}

