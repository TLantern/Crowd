//
//  TutorialCardView.swift
//  Crowd
//
//  Created by Cursor on 11/7/25.
//

import SwiftUI

struct TutorialCardView: View {
    let step: TutorialStep
    let isLastStep: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Arrow pointer at top (if direction is bottom)
            if step.arrowDirection == .bottom {
                ArrowPointer(direction: .bottom)
                    .offset(y: 1)
            }
            
            // Card content
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(step.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                // Description
                Text(step.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Action buttons
                HStack(spacing: 12) {
                    // Skip button
                    if !isLastStep {
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    
                    // Next/Got it button
                    Button(action: onNext) {
                        Text(isLastStep ? "Got it!" : "Next")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: 0x02853E))
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            
            // Arrow pointer at bottom (if direction is top)
            if step.arrowDirection == .top {
                ArrowPointer(direction: .top)
                    .offset(y: -1)
            }
        }
        .frame(maxWidth: 340)
    }
}

struct ArrowPointer: View {
    let direction: ArrowDirection
    
    var body: some View {
        Triangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Triangle()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .frame(width: 20, height: 16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(rotationDegrees))
    }
    
    private var rotationDegrees: Double {
        switch direction {
        case .top: return 180
        case .bottom: return 0
        case .left: return 90
        case .right: return -90
        case .none: return 0
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            TutorialCardView(
                step: TutorialStep.allSteps[0],
                isLastStep: false,
                onNext: { print("Next") },
                onSkip: { print("Skip") }
            )
            
            TutorialCardView(
                step: TutorialStep.allSteps[1],
                isLastStep: false,
                onNext: { print("Next") },
                onSkip: { print("Skip") }
            )
        }
    }
}

