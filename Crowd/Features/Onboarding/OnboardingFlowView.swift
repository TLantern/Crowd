//
//  OnboardingFlowView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var username: String = ""
    @State private var selectedCampus: String = ""
    @State private var selectedInterests: [String] = []
    @State private var selectedProfileImage: UIImage?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                    username: $username,
                    selectedCampus: $selectedCampus,
                    selectedProfileImage: $selectedProfileImage
                ) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentStep = .interests
                    }
                }
                .transition(.opacity)
            }
            
            // Interests Selection Screen
            if currentStep == .interests {
                InterestsView(onNext: { interests in
                    selectedInterests = interests
                    Task {
                        await saveProfileToFirebase()
                    }
                }, onBack: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentStep = .profile
                    }
                })
                .transition(.opacity)
            }
            
            // Loading overlay
            if isSaving {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView("Creating your profile...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Save Profile to Firebase
    
    private func saveProfileToFirebase() async {
        isSaving = true
        
        do {
            // Get or create user ID
            let userId: String
            if let currentUserId = FirebaseManager.shared.getCurrentUserId() {
                userId = currentUserId
            } else {
                userId = try await FirebaseManager.shared.signInAnonymously()
            }
            
            // Create profile in Firestore
            try await UserProfileService.shared.createProfile(
                userId: userId,
                displayName: username.isEmpty ? "Guest" : username,
                campus: selectedCampus.isEmpty ? "UNT" : selectedCampus,
                interests: selectedInterests,
                profileImage: selectedProfileImage
            )
            
            print("✅ Profile created successfully!")
            
            // Complete onboarding
            await MainActor.run {
                isSaving = false
                withAnimation(.easeInOut(duration: 0.6)) {
                    onComplete()
                }
            }
            
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "Failed to create profile: \(error.localizedDescription)"
                showError = true
            }
            print("❌ Error saving profile: \(error)")
        }
    }
}

#Preview {
    OnboardingFlowView {
        print("Onboarding complete")
    }
}

