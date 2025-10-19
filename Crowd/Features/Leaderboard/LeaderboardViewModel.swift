//
//  LeaderboardViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI
import Combine  

struct LeaderboardEntry: Identifiable, Hashable {
    let id = UUID()
    let rank: Int
    let name: String
    let handle: String
    let points: Int
    let isYou: Bool
    let tint: Color
}

final class LeaderboardViewModel: ObservableObject {
    @Published var timeframe: Timeframe = .week
    @Published var entries: [LeaderboardEntry] = []

    enum Timeframe: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        var id: String { rawValue }
    }

    init(entries: [LeaderboardEntry] = []) {
        self.entries = entries.isEmpty ? Self.mockEntries : entries
    }

    func switchTo(_ tf: Timeframe) {
        timeframe = tf
        // Swap with real fetch later
        entries = Self.mockEntries
    }

    static let mockEntries: [LeaderboardEntry] = [
        .init(rank: 1, name: "Maya J.", handle: "@maya",  points: 1640, isYou: false, tint: .orange),
        .init(rank: 2, name: "Aiden C.", handle: "@aiden", points: 1530, isYou: false, tint: .yellow),
        .init(rank: 3, name: "You",     handle: "@teni",  points: 1490, isYou: true,  tint: .green),
        .init(rank: 4, name: "Rhea P.", handle: "@rhea",  points: 1210, isYou: false, tint: .blue),
        .init(rank: 5, name: "Zane L.", handle: "@zane",  points: 980,  isYou: false, tint: .purple),
    ]
}
