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
    @Published var interests: [Interest]
    @Published var mutuals: [MiniUser]
    @Published var gallery: [CrowdEvent]
    @Published var suggestedUsers: [MiniUser]
    @Published var isEditMode: Bool = false
    @Published var profileImage: UIImage?

    let availableInterests: [Interest] = Interest.allInterests

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
         interests: [Interest] = [],
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
        self.interests = interests
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
    
    var unselectedInterests: [Interest] {
        availableInterests.filter { interest in
            !interests.contains(where: { $0.id == interest.id })
        }
    }
    
    // MARK: - Edit Mode Methods
    func toggleEditMode() {
        withAnimation(.spring(response: 0.3)) {
            isEditMode.toggle()
        }
    }
    
    func addInterest(_ interest: Interest) {
        guard !interests.contains(where: { $0.id == interest.id }) else { return }
        withAnimation(.spring(response: 0.3)) {
            interests.append(interest)
        }
    }
    
    func removeInterest(_ interest: Interest) {
        withAnimation(.spring(response: 0.3)) {
            interests.removeAll(where: { $0.id == interest.id })
        }
    }
    
    func updateProfileImage(_ image: UIImage) {
        self.profileImage = image
        
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            return
        }
        
        Task {
            do {
                let imageURL = try await UserProfileService.shared.uploadProfileImage(userId: userId, image: image)
                print("✅ Profile image uploaded: \(imageURL)")
            } catch {
                print("❌ Failed to upload profile image: \(error)")
            }
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
        interests: [
            Interest(emoji: "💻", name: "Tech"),
            Interest(emoji: "🎵", name: "Music"),
            Interest(emoji: "🏀", name: "Basketball"),
            Interest(emoji: "🍕", name: "Food"),
            Interest(emoji: "🎨", name: "Art")
        ],
        mutuals: [
            MiniUser(id: "1", name: "Sarah Chen", avatarColor: .purple, tags: ["Music", "Art"], mutualFriendsCount: 12),
            MiniUser(id: "2", name: "Marcus Webb", avatarColor: .orange, tags: ["Sports", "Tech"], mutualFriendsCount: 8),
            MiniUser(id: "3", name: "Alex Kim", avatarColor: .pink, tags: ["Food", "Music"], mutualFriendsCount: 15),
            MiniUser(id: "4", name: "Jordan Lee", avatarColor: .green, tags: ["Tech"], mutualFriendsCount: 6),
            MiniUser(id: "5", name: "Taylor Brown", avatarColor: .blue, tags: ["Art", "Music"], mutualFriendsCount: 10)
        ],
        gallery: [
            CrowdEvent(id: "g1", title: "Study Session", hostId: "user1", hostName: "Guest", latitude: 33.2, longitude: -97.1, radiusMeters: 50, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 8, attendeeCount: 12, tags: ["Study"], category: "Study Session", description: nil),
            CrowdEvent(id: "g2", title: "Basketball Game", hostId: "user1", hostName: "Guest", latitude: 33.2, longitude: -97.1, radiusMeters: 100, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 9, attendeeCount: 24, tags: ["Sports"], category: "Pickup Game", description: nil),
            CrowdEvent(id: "g3", title: "Coffee Meetup", hostId: "user1", hostName: "Guest", latitude: 33.2, longitude: -97.1, radiusMeters: 30, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 6, attendeeCount: 8, tags: ["Social"], category: "Coffee/Hangout", description: nil),
            CrowdEvent(id: "g4", title: "Concert", hostId: "user1", hostName: "Guest", latitude: 33.2, longitude: -97.1, radiusMeters: 200, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 10, attendeeCount: 150, tags: ["Music"], category: "Music/Concert", description: nil),
            CrowdEvent(id: "g5", title: "Hackathon", hostId: "user1", hostName: "Guest", latitude: 33.2, longitude: -97.1, radiusMeters: 80, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 7, attendeeCount: 35, tags: ["Tech"], category: "Networking", description: nil),
            CrowdEvent(id: "g6", title: "Art Gallery", hostId: "user1", hostName: "Guest", latitude: 33.2, longitude: -97.1, radiusMeters: 60, startsAt: Date(), endsAt: nil, createdAt: Date(), signalStrength: 5, attendeeCount: 18, tags: ["Art"], category: "Party", description: nil)
        ],
        suggestedUsers: [
            MiniUser(id: "s1", name: "Emma Wilson", avatarColor: .indigo, tags: ["Music", "Food"], mutualFriendsCount: 5),
            MiniUser(id: "s2", name: "Ryan Garcia", avatarColor: .teal, tags: ["Tech", "Sports"], mutualFriendsCount: 9),
            MiniUser(id: "s3", name: "Maya Patel", avatarColor: .mint, tags: ["Art", "Tech"], mutualFriendsCount: 7)
        ]
    )

    // MARK: - Firebase Integration
    
    func fetchProfile(userId: String) async throws {
        let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
        
        // Update @Published properties on MainActor
        await MainActor.run {
            self.displayName = profile.displayName
            self.points = profile.auraPoints
            // Other fields can be updated when backend supports them
        }
    }
    
    func fetchGallery(userId: String) async throws -> [CrowdEvent] {
        let db = FirebaseManager.shared.db
        
        // Fetch events where user is host
        let hostedSnapshot = try await db.collection("events")
            .whereField("hostId", isEqualTo: userId)
            .limit(to: 20)
            .getDocuments()
        
        // Fetch events where user has signals
        let signalsSnapshot = try await db.collection("signals")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 20)
            .getDocuments()
        
        let eventIds = signalsSnapshot.documents.compactMap { doc -> String? in
            doc.data()["eventId"] as? String
        }
        
        var events: [CrowdEvent] = []
        
        // Parse hosted events
        for doc in hostedSnapshot.documents {
            if let event = try? parseEvent(from: doc.data()) {
                events.append(event)
            }
        }
        
        // Fetch attended events
        for eventId in eventIds {
            let eventDoc = try await db.collection("events").document(eventId).getDocument()
            if let data = eventDoc.data(),
               let event = try? parseEvent(from: data) {
                events.append(event)
            }
        }
        
        // Remove duplicates and sort by date
        let uniqueEvents = Array(Set(events.map { $0.id })).compactMap { id in
            events.first(where: { $0.id == id })
        }.sorted { $0.createdAt > $1.createdAt }
        
        await MainActor.run {
            self.gallery = uniqueEvents
        }
        
        return uniqueEvents
    }
    
    func fetchMutuals(userId: String) async throws -> [MiniUser] {
        // Fetch user's friends list
        let db = FirebaseManager.shared.db
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = userDoc.data(),
              let friendIds = data["friends"] as? [String] else {
            return []
        }
        
        // Fetch profiles for friends
        let profiles = try await UserProfileService.shared.fetchProfiles(userIds: friendIds)
        
        let miniUsers = profiles.map { profile in
            MiniUser(
                id: profile.id,
                name: profile.displayName,
                avatarColor: profile.avatarColor,
                tags: [], // TODO: Fetch user interests
                mutualFriendsCount: 0 // TODO: Calculate mutual friends
            )
        }
        
        await MainActor.run {
            self.mutuals = miniUsers
        }
        
        return miniUsers
    }
    
    func fetchSuggestions(userId: String) async throws -> [MiniUser] {
        let db = FirebaseManager.shared.db
        
        // Fetch top users by aura points (excluding current user)
        let snapshot = try await db.collection("users")
            .order(by: "auraPoints", descending: true)
            .limit(to: 10)
            .getDocuments()
        
        let profiles = snapshot.documents.compactMap { doc -> UserProfile? in
            let data = doc.data()
            let id = doc.documentID
            
            guard id != userId else { return nil }
            
            return try? UserProfile(
                id: id,
                displayName: data["displayName"] as? String ?? "User",
                auraPoints: data["auraPoints"] as? Int ?? 0,
                avatarColorHex: data["avatarColorHex"] as? String ?? "#808080",
                profileImageURL: data["profileImageURL"] as? String
            )
        }
        
        let miniUsers = profiles.map { profile in
            MiniUser(
                id: profile.id,
                name: profile.displayName,
                avatarColor: profile.avatarColor,
                tags: [],
                mutualFriendsCount: 0
            )
        }
        
        await MainActor.run {
            self.suggestedUsers = miniUsers
        }
        
        return miniUsers
    }
    
    private func parseEvent(from data: [String: Any]) throws -> CrowdEvent {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String,
              let lat = data["latitude"] as? Double,
              let lon = data["longitude"] as? Double,
              let radiusMeters = data["radiusMeters"] as? Double else {
            throw CrowdError.invalidResponse
        }
        
        let signalStrength = data["signalStrength"] as? Int ?? 0
        let attendeeCount = data["attendeeCount"] as? Int ?? 0
        let hostId = data["hostId"] as? String ?? ""
        let hostName = data["hostName"] as? String ?? "Guest"
        let tags = data["tags"] as? [String] ?? []
        
        return CrowdEvent(
            id: id,
            title: title,
            hostId: hostId,
            hostName: hostName,
            latitude: lat,
            longitude: lon,
            radiusMeters: radiusMeters,
            startsAt: nil,
            endsAt: nil,
            createdAt: Date(),
            signalStrength: signalStrength,
            attendeeCount: attendeeCount,
            tags: tags
        )
    }
}
