//
//  LeaderboardViewModel.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFunctions

struct LeaderboardEntry: Identifiable, Hashable {
    let id = UUID()
    let rank: Int
    let name: String
    let handle: String
    let points: Int
    let isYou: Bool
    let tint: Color
}

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var timeframe: Timeframe = .week
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUserRank: Int?
    
    private let functions: Functions

    enum Timeframe: String, CaseIterable, Identifiable {
        case today = "today"
        case week = "week"
        case month = "month"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .today: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            }
        }
    }

    init(entries: [LeaderboardEntry] = []) {
        self.functions = FirebaseManager.shared.functions
        
        if entries.isEmpty {
            // Start with mock data, will be replaced by real data
            self.entries = Self.mockEntries
            
            // Fetch real data
            Task {
                await fetchLeaderboard()
            }
        } else {
            self.entries = entries
        }
    }

    func switchTo(_ tf: Timeframe) {
        timeframe = tf
        
        // Track analytics
        AnalyticsService.shared.trackLeaderboardViewed(timeframe: tf.rawValue)
        
        Task {
            await fetchLeaderboard()
        }
    }
    
    func fetchLeaderboard() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let callable = functions.httpsCallable("getLeaderboard")
            let data: [String: Any] = [
                "timeframe": timeframe.rawValue,
                "limit": 50
            ]
            
            let result = try await callable.call(data)
            
            guard let response = result.data as? [String: Any],
                  let success = response["success"] as? Bool,
                  success,
                  let leaderboardData = response["leaderboard"] as? [[String: Any]] else {
                throw CrowdError.invalidResponse
            }
            
            // Parse current user rank
            if let rank = response["currentUserRank"] as? Int {
                currentUserRank = rank
            }
            
            // Parse leaderboard entries
            let parsedEntries = leaderboardData.compactMap { dict -> LeaderboardEntry? in
                guard let rank = dict["rank"] as? Int,
                      let name = dict["displayName"] as? String,
                      let points = dict["auraPoints"] as? Int,
                      let isCurrentUser = dict["isCurrentUser"] as? Bool else {
                    return nil
                }
                
                let userId = dict["userId"] as? String ?? ""
                let handle = "@\(name.lowercased().replacingOccurrences(of: " ", with: ""))"
                let tint = Self.colorForRank(rank)
                
                return LeaderboardEntry(
                    rank: rank,
                    name: isCurrentUser ? "You" : name,
                    handle: handle,
                    points: points,
                    isYou: isCurrentUser,
                    tint: tint
                )
            }
            
            entries = parsedEntries
            
            print("✅ Leaderboard fetched: \(entries.count) entries")
        } catch {
            errorMessage = "Failed to load leaderboard"
            print("❌ Failed to fetch leaderboard: \(error)")
            
            // Fall back to mock data on error
            entries = Self.mockEntries
        }
    }
    
    private static func colorForRank(_ rank: Int) -> Color {
        let colors: [Color] = [.orange, .yellow, .green, .blue, .purple, .pink, .red, .cyan, .mint, .indigo]
        return colors[(rank - 1) % colors.count]
    }

    static let mockEntries: [LeaderboardEntry] = [
        .init(rank: 1, name: "Maya J.", handle: "@maya",  points: 1640, isYou: false, tint: .orange),
        .init(rank: 2, name: "Aiden C.", handle: "@aiden", points: 1530, isYou: false, tint: .yellow),
        .init(rank: 3, name: "You",     handle: "@teni",  points: 1490, isYou: true,  tint: .green),
        .init(rank: 4, name: "Rhea P.", handle: "@rhea",  points: 1210, isYou: false, tint: .blue),
        .init(rank: 5, name: "Zane L.", handle: "@zane",  points: 980,  isYou: false, tint: .purple),
    ]
}
