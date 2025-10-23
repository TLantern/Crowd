//
//  ProfileViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Mini User Model
struct MiniUser: Identifiable, Hashable {
    let id: String
    let name: String
    let avatarColor: Color
    let tags: [String]
    let mutualFriendsCount: Int
}

// MARK: - Profile ViewModel
final class ProfileViewModel: ObservableObject {
    @Published var displayName: String
    @Published var handle: String
    @Published var bio: String
    @Published var affiliation: String
    @Published var points: Int
    @Published var weeklyStreak: Int
    @Published var joinedCount: Int
    @Published var hostedCount: Int
    @Published var upcomingEventsCount: Int
    @Published var friendsCount: Int
    @Published var avatarColor: Color
    @Published var lastActive: Date
    @Published var tags: [String]
    @Published var mutuals: [MiniUser]
    @Published var gallery: [CrowdEvent]
    @Published var suggestedUsers: [MiniUser]

    init(displayName: String,
         handle: String,
         bio: String,
         affiliation: String,
         points: Int,
         weeklyStreak: Int,
         joinedCount: Int,
         hostedCount: Int,
         upcomingEventsCount: Int,
         friendsCount: Int,
         avatarColor: Color = .blue,
         lastActive: Date = Date(),
         tags: [String] = [],
         mutuals: [MiniUser] = [],
         gallery: [CrowdEvent] = [],
         suggestedUsers: [MiniUser] = []) {
        self.displayName = displayName
        self.handle = handle
        self.bio = bio
        self.affiliation = affiliation
        self.points = points
        self.weeklyStreak = weeklyStreak
        self.joinedCount = joinedCount
        self.hostedCount = hostedCount
        self.upcomingEventsCount = upcomingEventsCount
        self.friendsCount = friendsCount
        self.avatarColor = avatarColor
        self.lastActive = lastActive
        self.tags = tags
        self.mutuals = mutuals
        self.gallery = gallery
        self.suggestedUsers = suggestedUsers
    }

    // MARK: - Computed Properties
    var isActiveNow: Bool {
        let minutesAgo = Calendar.current.dateComponents([.minute], from: lastActive, to: Date()).minute ?? 0
        return minutesAgo < 5
    }

    var activeStatusText: String {
        if isActiveNow {
            return "Active now"
        }
        
        let components = Calendar.current.dateComponents([.hour, .day], from: lastActive, to: Date())
        
        if let days = components.day, days > 0 {
            return "Last seen \(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "Last seen \(hours)h ago"
        } else {
            return "Last seen recently"
        }
    }

    var auraRank: String {
        switch points {
        case 0..<100: return "Novice"
        case 100..<500: return "Regular"
        case 500..<1000: return "Champion"
        case 1000..<2000: return "Legend"
        default: return "Mythic"
        }
    }

    // MARK: - Mock Data
    static let mock = ProfileViewModel(
        displayName: "Teni Owojori",
        handle: "@teni",
        bio: "Building apps that bring people together ✨ UNT CS '25",
        affiliation: "University of North Texas",
        points: 1280,
        weeklyStreak: 4,
        joinedCount: 18,
        hostedCount: 5,
        upcomingEventsCount: 3,
        friendsCount: 47,
        avatarColor: .cyan,
        lastActive: Date().addingTimeInterval(-3600), // 1 hour ago
        tags: ["Tech", "Music", "Sports", "Food", "Art"],
        mutuals: [
            MiniUser(id: "1", name: "Sarah Chen", avatarColor: .purple, tags: ["Music", "Art"], mutualFriendsCount: 12),
            MiniUser(id: "2", name: "Marcus Webb", avatarColor: .orange, tags: ["Sports", "Tech"], mutualFriendsCount: 8),
            MiniUser(id: "3", name: "Alex Kim", avatarColor: .pink, tags: ["Food", "Music"], mutualFriendsCount: 15),
            MiniUser(id: "4", name: "Jordan Lee", avatarColor: .green, tags: ["Tech"], mutualFriendsCount: 6),
            MiniUser(id: "5", name: "Taylor Brown", avatarColor: .blue, tags: ["Art", "Music"], mutualFriendsCount: 10)
        ],
        gallery: [
            CrowdEvent(id: "g1", title: "Study Session", hostId: "user1", latitude: 33.2, longitude: -97.1, radiusMeters: 50, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 8, attendeeCount: 12, tags: ["Study"]),
            CrowdEvent(id: "g2", title: "Basketball Game", hostId: "user1", latitude: 33.2, longitude: -97.1, radiusMeters: 100, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 9, attendeeCount: 24, tags: ["Sports"]),
            CrowdEvent(id: "g3", title: "Coffee Meetup", hostId: "user1", latitude: 33.2, longitude: -97.1, radiusMeters: 30, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 6, attendeeCount: 8, tags: ["Social"]),
            CrowdEvent(id: "g4", title: "Concert", hostId: "user1", latitude: 33.2, longitude: -97.1, radiusMeters: 200, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 10, attendeeCount: 150, tags: ["Music"]),
            CrowdEvent(id: "g5", title: "Hackathon", hostId: "user1", latitude: 33.2, longitude: -97.1, radiusMeters: 80, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 7, attendeeCount: 35, tags: ["Tech"]),
            CrowdEvent(id: "g6", title: "Art Gallery", hostId: "user1", latitude: 33.2, longitude: -97.1, radiusMeters: 60, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 5, attendeeCount: 18, tags: ["Art"])
        ],
        suggestedUsers: [
            MiniUser(id: "s1", name: "Emma Wilson", avatarColor: .indigo, tags: ["Music", "Food"], mutualFriendsCount: 5),
            MiniUser(id: "s2", name: "Ryan Garcia", avatarColor: .teal, tags: ["Tech", "Sports"], mutualFriendsCount: 9),
            MiniUser(id: "s3", name: "Maya Patel", avatarColor: .mint, tags: ["Art", "Tech"], mutualFriendsCount: 7)
        ]
    )

    // MARK: - Firebase Integration (Stubbed)
    // Uncomment and implement when Firebase is ready
    
//    func fetchProfile() async throws {
//        // let profile = try await FirebaseService.shared.fetchUserProfile()
//        // Update @Published properties on MainActor
//    }
//
//    func fetchGallery() async throws -> [CrowdEvent] {
//        // let events = try await FirebaseService.shared.fetchUserEvents()
//        // return events
//        return []
//    }
//
//    func fetchMutuals() async throws -> [MiniUser] {
//        // let users = try await FirebaseService.shared.fetchMutualFriends()
//        // return users
//        return []
//    }
//
//    func fetchSuggestions() async throws -> [MiniUser] {
//        // let users = try await FirebaseService.shared.fetchSuggestedUsers()
//        // return users
//        return []
//    }
}
