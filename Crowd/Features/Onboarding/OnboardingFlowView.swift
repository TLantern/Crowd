//
//  OnboardingFlowView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var displayName: String = ""
    @State private var campus: String = "UNT"
    @State private var selectedInterests: [String] = []
    @State private var isCreatingProfile = false
    @State private var errorMessage: String?
    
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
                OnboardingProfileView(
                    displayName: $displayName,
                    campus: $campus
                ) {
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
                    Task {
                        await createUserProfile()
                    }
                }
                .transition(.opacity)
            }
            
            // Loading overlay
            if isCreatingProfile {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Creating your profile...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func createUserProfile() async {
        isCreatingProfile = true
        defer { isCreatingProfile = false }
        
        do {
            let profile = try await UserProfileService.shared.createUser(
                displayName: displayName.isEmpty ? "Guest" : displayName,
                campus: campus,
                interests: selectedInterests
            )
            
            // Track analytics
            AnalyticsService.shared.trackUserCreated(userId: profile.id, displayName: profile.displayName)
            
            // Update app state with new profile
            await MainActor.run {
                AppEnvironment.current.appState.sessionUser = profile
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                
                withAnimation(.easeInOut(duration: 0.6)) {
                    onComplete()
                }
            }
            
            print("✅ Onboarding complete for user: \(profile.displayName)")
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create profile: \(error.localizedDescription)"
            }
            print("❌ Onboarding failed: \(error)")
        }
    }
}

#Preview {
    OnboardingFlowView {
        print("Onboarding complete")
    }
}

