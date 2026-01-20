//
//  UserProfileSheetView.swift
//  Crowd
//
//  Sheet view for displaying user profiles when tapping on visible user annotations
//

import SwiftUI

struct UserProfileSheetView: View {
    let user: UserProfile
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(user: UserProfile) {
        self.user = user
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            displayName: user.displayName,
            handle: user.handle ?? "@\(user.displayName.lowercased())",
            bio: user.bio ?? "Hey there! I'm using Crowd.",
            affiliation: user.campus ?? "University",
            points: user.auraPoints,
            weeklyStreak: 0, // Can be loaded from profile if available
            joinedCount: user.joinedCount,
            hostedCount: user.hostedCount,
            upcomingEventsCount: 0,
            friendsCount: user.friendsCount,
            lastActive: user.lastActive ?? Date(),
            interests: user.interests.compactMap { interestName in
                Interest.allInterests.first { $0.name == interestName }
            },
            mutuals: [],
            gallery: [],
            suggestedUsers: []
        ))
    }
    
    var body: some View {
        NavigationStack {
            ProfileView(viewModel: viewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .task {
                    // Load full profile data from Firebase (skip mock users)
                    guard !user.id.hasPrefix("mock_") else { return }
                    await viewModel.loadProfile(userId: user.id)
                }
        }
    }
}

#Preview {
    // TODO: Remove after testing - Simplified preview using only essential UserProfile properties
    UserProfileSheetView(user: UserProfile(
        id: "mock1",
        displayName: "Alex Chen",
        handle: "@alexchen",
        bio: "CS major, love to code and play basketball 🏀",
        campus: "University of North Texas",
        interests: ["Tech", "Music", "Basketball"],
        auraPoints: 100,
        avatarColorHex: "#00CED1",
        hostedCount: 3,
        joinedCount: 12,
        friendsCount: 10,
        createdAt: Date(),
        latitude: 33.2073,
        longitude: -97.1474,
        termsAccepted: true,
        isVisible: true
    ))
}
