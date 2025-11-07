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
            description: "Tap on any event pin to see details and join the crowd. Events show where people are gathering right now.",
            cardPosition: .topCenter,
            arrowDirection: .bottom
        ),
        TutorialStep(
            id: 2,
            title: "Create Your Own Event",
            description: "Tap the green plus button to host an event. It's free and takes less than a minute!",
            cardPosition: .bottomCenter,
            arrowDirection: .top
        ),
        TutorialStep(
            id: 3,
            title: "Filter Events",
            description: "Use the filter dropdown to see only user-created or school-hosted events.",
            cardPosition: .topCenter,
            arrowDirection: .bottom
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

