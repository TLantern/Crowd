//
//  TutorialStep.swift
//  Crowd
//
//  Created by Cursor on 11/7/25.
//

import SwiftUI

enum ArrowDirection {
    case top, bottom, left, right, none
}

enum CardPosition {
    case topCenter
    case bottomCenter
    case center
    case custom(x: CGFloat, y: CGFloat)
}

struct TutorialStep: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let cardPosition: CardPosition
    let arrowDirection: ArrowDirection
    
    static func == (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        lhs.id == rhs.id
    }
}

extension TutorialStep {
    static let allSteps: [TutorialStep] = [
        TutorialStep(
            id: 1,
            title: "Welcome to Crowd! 🎉",
            description: "No more guessing what's going on. Crowd helps you see real-time campus activity so you can decide where to go next.",
            cardPosition: .topCenter,
            arrowDirection: .bottom
        ),
        TutorialStep(
            id: 2,
            title: "Create Your Own Event",
            description: "Have plans already? Tap the glowing fire, name your crowd! and boom you have a crowd!",
            cardPosition: .bottomCenter,
            arrowDirection: .top
        ),
        TutorialStep(
            id: 3,
            title: "Visibility Mode 👁️",
            description: "Tap the eye icon to see other users on the map and share your location.",
            cardPosition: .custom(x: 0, y: 0), // Will be positioned near eye icon at top right
            arrowDirection: .top
        ),
        TutorialStep(
            id: 4,
            title: "You're All Set! 🚀",
            description: "Start exploring events around you and connect with your campus community.",
            cardPosition: .center,
            arrowDirection: .none
        )
    ]
}

#Preview {
    VStack(spacing: 20) {
        ForEach(TutorialStep.allSteps) { step in
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.headline)
                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    Text("Position: \(String(describing: step.cardPosition))")
                        .font(.caption)
                    Spacer()
                    Text("Arrow: \(String(describing: step.arrowDirection))")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

