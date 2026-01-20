//
//  TutorialOverlayView.swift
//  Crowd
//
//  Created by Cursor on 11/7/25.
//

import SwiftUI

struct TutorialOverlayView: View {
    let steps: [TutorialStep]
    let targetPositions: [Int: CGPoint] // Map step ID to target position
    let onComplete: () -> Void
    let onStepComplete: ((Int) -> Void)? // Optional callback when a specific step is completed
    
    @State private var currentStepIndex: Int = 0
    @State private var isVisible: Bool = false
    
    var currentStep: TutorialStep {
        steps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex == steps.count - 1
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed background
                Color.black
                    .opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow tap to dismiss on background
                    }
                
                // Tutorial card positioned based on step
                VStack {
                    TutorialCardView(
                        step: currentStep,
                        isLastStep: isLastStep,
                        onNext: handleNext,
                        onSkip: handleSkip
                    )
                    .position(cardPosition(in: geo))
                }
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isVisible)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStepIndex)
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    private func cardPosition(in geo: GeometryProxy) -> CGPoint {
        let safeTop = geo.safeAreaInsets.top
        let safeBottom = geo.safeAreaInsets.bottom
        let width = geo.size.width
        let height = geo.size.height
        
        switch currentStep.cardPosition {
        case .topCenter:
            return CGPoint(
                x: width / 2,
                y: safeTop + 120
            )
        case .bottomCenter:
            // Position above the FAB button area
            return CGPoint(
                x: width / 2,
                y: height - safeBottom - 200
            )
        case .center:
            return CGPoint(
                x: width / 2,
                y: height / 2
            )
        case .custom(_, _):
            // Special handling for step 3 (Visibility Mode) - position near eye icon at top right
            if currentStep.id == 3 {
                return CGPoint(
                    x: width / 2,
                    y: safeTop + 140  // Position below the eye icon
                )
            }
            return CGPoint(x: width / 2, y: safeTop + 120)
        }
    }
    
    private func handleNext() {
        Haptics.light()
        
        // Call step completion callback if provided
        onStepComplete?(currentStep.id)
        
        if isLastStep {
            // Complete tutorial
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onComplete()
            }
        } else {
            // Move to next step
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentStepIndex += 1
            }
        }
    }
    
    private func handleSkip() {
        Haptics.light()
        
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        TutorialOverlayView(
            steps: TutorialStep.allSteps,
            targetPositions: [:],
            onComplete: { print("Tutorial completed") },
            onStepComplete: nil
        )
    }
}

