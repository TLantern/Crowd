//
//  EventAnnotationView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct EventAnnotationView: View {
    let event: CrowdEvent
    
    var emoji: String {
        guard let category = event.category else { return "🔥" }
        
        // Match category string to EventCategory enum emoji
        switch category.lowercased() {
        case let cat where cat.contains("party"): return "🎉"
        case let cat where cat.contains("study"): return "📚"
        case let cat where cat.contains("sport") || cat.contains("fitness"): return "⚽"
        case let cat where cat.contains("food") || cat.contains("dining"): return "🍕"
        case let cat where cat.contains("gaming") || cat.contains("game"): return "🎮"
        case let cat where cat.contains("music") || cat.contains("concert"): return "🎵"
        case let cat where cat.contains("coffee") || cat.contains("hangout"): return "☕"
        case let cat where cat.contains("pickup"): return "🏀"
        case let cat where cat.contains("movie") || cat.contains("watch"): return "🎬"
        case let cat where cat.contains("network"): return "💼"
        default: return "🔥"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(emoji) \(event.title)")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                )
            Text("\(event.attendeeCount) • sig \(event.signalStrength)")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .shadow(radius: 4)
    }
}
