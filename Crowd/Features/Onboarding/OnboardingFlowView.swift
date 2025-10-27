//
//  OnboardingFlowView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedInterests: [String] = []
    
    let onComplete: () -> Void
    
    enum OnboardingStep {
        case welcome
        case profile
        case interests
    }
    
    var body: some View {
        ZStack {
            // Welcome Screen
            if currentStep == .welcome {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentStep = .profile
                    }
                }
                .transition(.opacity)
            }
            
            // Profile Setup Screen
            if currentStep == .profile {
                OnboardingProfileView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentStep = .interests
                    }
                }
                .transition(.opacity)
            }
            
            // Interests Selection Screen
            if currentStep == .interests {
                InterestsView { interests in
                    selectedInterests = interests
                    withAnimation(.easeInOut(duration: 0.6)) {
                        // Save interests if needed
                        onComplete()
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    OnboardingFlowView {
        print("Onboarding complete")
    }
}

