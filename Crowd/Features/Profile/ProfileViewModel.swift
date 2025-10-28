//
//  ProfileViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

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
    
    #if DEBUG
    @Published var showNotificationTester: Bool = false
    #endif

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
        gallery: [], // Load from Firebase
        suggestedUsers: [
            MiniUser(id: "s1", name: "Emma Wilson", avatarColor: .indigo, tags: ["Music", "Food"], mutualFriendsCount: 5),
            MiniUser(id: "s2", name: "Ryan Garcia", avatarColor: .teal, tags: ["Tech", "Sports"], mutualFriendsCount: 9),
            MiniUser(id: "s3", name: "Maya Patel", avatarColor: .mint, tags: ["Art", "Tech"], mutualFriendsCount: 7)
        ]
    )

    // MARK: - Firebase Integration
    
    @MainActor
    func loadProfile(userId: String) async {
        do {
            let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
            
            // Update all properties from Firebase
            self.displayName = profile.displayName
            self.handle = profile.handle ?? "@\(profile.displayName.lowercased())"
            self.bio = profile.bio ?? "Hey there! I'm using Crowd."
            self.affiliation = profile.campus ?? "University"
            self.points = profile.auraPoints
            self.hostedCount = profile.hostedCount
            self.joinedCount = profile.joinedCount
            self.friendsCount = profile.friendsCount
            self.avatarColor = profile.avatarColor
            self.lastActive = profile.lastActive ?? Date()
            
            // Convert interests from strings to Interest objects
            self.interests = profile.interests.compactMap { interestName in
                Interest.allInterests.first { $0.name == interestName }
            }
            
            print("✅ Profile loaded from Firebase for: \(profile.displayName)")
            
            // Load user's hosted events for gallery
            await loadHostedEvents(userId: userId)
            
        } catch {
            print("❌ Error loading profile: \(error)")
        }
    }
    
    @MainActor
    func loadHostedEvents(userId: String) async {
        do {
            print("📸 Loading hosted events for gallery...")
            
            let snapshot = try await FirebaseManager.shared.db
                .collection("events")
                .whereField("hostId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 6)
                .getDocuments()
            
            let events = snapshot.documents.compactMap { doc -> CrowdEvent? in
                let data = doc.data()
                
                guard let id = data["id"] as? String,
                      let title = data["title"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let radiusMeters = data["radiusMeters"] as? Double,
                      let hostId = data["hostId"] as? String,
                      let hostName = data["hostName"] as? String else {
                    return nil
                }
                
                let startsAtTimestamp = data["startsAt"] as? TimeInterval
                let endsAtTimestamp = data["endsAt"] as? TimeInterval
                let createdAtTimestamp = data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                
                let startsAt = startsAtTimestamp.map { Date(timeIntervalSince1970: $0) }
                let endsAt = endsAtTimestamp.map { Date(timeIntervalSince1970: $0) }
                let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
                
                let signalStrength = data["signalStrength"] as? Int ?? 1
                let attendeeCount = data["attendeeCount"] as? Int ?? 0
                let tags = data["tags"] as? [String] ?? []
                let category = data["category"] as? String
                let description = data["description"] as? String
                
                return CrowdEvent(
                    id: id,
                    title: title,
                    hostId: hostId,
                    hostName: hostName,
                    latitude: latitude,
                    longitude: longitude,
                    radiusMeters: radiusMeters,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    createdAt: createdAt,
                    signalStrength: signalStrength,
                    attendeeCount: attendeeCount,
                    tags: tags,
                    category: category,
                    description: description
                )
            }
            
            self.gallery = events
            print("✅ Loaded \(events.count) events for gallery")
            
        } catch {
            print("❌ Failed to load hosted events: \(error.localizedDescription)")
            self.gallery = []
        }
    }
    
    @MainActor
    func saveChanges(userId: String) async {
        do {
            let updates: [String: Any] = [
                "displayName": displayName,
                "bio": bio,
                "interests": interests.map { $0.name }
            ]
            
            try await UserProfileService.shared.updateProfile(userId: userId, updates: updates)
            print("✅ Profile changes saved")
            
        } catch {
            print("❌ Error saving profile changes: \(error)")
        }
    }
    
    // Factory method to create ViewModel from Firebase
    static func fromFirebase(userId: String) async -> ProfileViewModel {
        let viewModel = ProfileViewModel.mock
        await viewModel.loadProfile(userId: userId)
        return viewModel
    }
}
