//
//  ProfileViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI
import Combine   // <- required for ObservableObject/@Published

final class ProfileViewModel: ObservableObject {
    @Published var displayName: String
    @Published var handle: String
    @Published var points: Int
    @Published var weeklyStreak: Int
    @Published var joinedCount: Int
    @Published var hostedCount: Int
    @Published var avatarColor: Color

    init(displayName: String,
         handle: String,
         points: Int,
         weeklyStreak: Int,
         joinedCount: Int,
         hostedCount: Int,
         avatarColor: Color = .blue) {
        self.displayName = displayName
        self.handle = handle
        self.points = points
        self.weeklyStreak = weeklyStreak
        self.joinedCount = joinedCount
        self.hostedCount = hostedCount
        self.avatarColor = avatarColor
    }

    static let mock = ProfileViewModel(
        displayName: "Teni Owojori",
        handle: "@teni",
        points: 1280,
        weeklyStreak: 4,
        joinedCount: 18,
        hostedCount: 5,
        avatarColor: .cyan
    )
}
