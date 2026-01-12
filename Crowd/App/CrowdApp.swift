//
//  CrowdApp.swift
//  Crowd
//
//  Created by Teni Owojori on 10/18/25.
//
//  NEW ONBOARDING FLOW:
//  - Campus Selection → Map → Parties Guide → Intent Action → Signup
//  - Signup is DEFERRED until user attempts a meaningful action
//  - This increases conversion by showing value before asking for commitment
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics

@main
struct CrowdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator.shared
    
    // NEW: Campus selection gate (replaces mandatory onboarding)
    @AppStorage("hasCompletedCampusSelection") private var hasCompletedCampusSelection = false
    @AppStorage("hasCompletedPartiesOnboarding") private var hasCompletedPartiesOnboarding = false
    @AppStorage("useNewOnboarding") private var useNewOnboarding = true
    
    // LEGACY: Keep for backwards compatibility with existing users
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    @State private var showTermsAgreement = false
    @State private var isCheckingTerms = true
    @State private var accountDeleted = false
    @State private var showPartiesOnboarding = false
    
    private let env = AppEnvironment.current
    
    init() {
        // Initialize Firebase and connect to emulators
        _ = FirebaseManager.shared
        
        // Configure push notifications
        NotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // MIGRATION: Existing users who completed old onboarding skip campus selection
                if hasSeenOnboarding && !hasCompletedCampusSelection {
                    // Migrate existing users - they already completed onboarding
                    Color.clear.onAppear {
                        hasCompletedCampusSelection = true
                        hasCompletedPartiesOnboarding = true
                    }
                }
                
                // NEW FLOW: Campus selection is the first gate
                // No account required to see the map!
                if hasCompletedCampusSelection {
                    mainAppView
                } else if useNewOnboarding {
                    // New users see campus selection first
                    CampusSelectionView {
                        // After campus selection, go straight to map
                        // NO signup required at this point!
                        hasCompletedCampusSelection = true
                        hasSeenOnboarding = true // Mark old flag too for safety
                        
                        // Show parties onboarding after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if !hasCompletedPartiesOnboarding {
                                showPartiesOnboarding = true
                            }
                        }
                    }
                    .onAppear {
                        AnalyticsService.shared.track("app_opened", props: ["flow": "new_onboarding"])
                        AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                    }
                } else {
                    // Legacy flow for A/B testing (disabled by default)
                    OnboardingFlowView {
                        hasSeenOnboarding = true
                        hasCompletedCampusSelection = true
                        hasCompletedPartiesOnboarding = true
                        showTermsAgreement = true
                        isCheckingTerms = false
                    }
                    .onAppear {
                        AnalyticsService.shared.track("app_opened", props: ["flow": "legacy_onboarding"])
                        AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                    }
                }
            }
            .onChange(of: accountDeleted) { _, deleted in
                if deleted {
                    // Reset all onboarding flags on account deletion
                    hasSeenOnboarding = false
                    hasCompletedCampusSelection = false
                    hasCompletedPartiesOnboarding = false
                    showTermsAgreement = false
                    showPartiesOnboarding = false
                    isCheckingTerms = true
                    accountDeleted = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .accountDeleted)) { _ in
                accountDeleted = true
            }
        }
    }
    
    // MARK: - Main App View
    
    @ViewBuilder
    private var mainAppView: some View {
        ZStack {
            CrowdHomeView()
                .environmentObject(appState)
                .environmentObject(onboardingCoordinator)
                .environment(\.appEnvironment, env)
                .task { await appState.bootstrap() }
                .onAppear {
                    AnalyticsService.shared.track("app_opened", props: [:])
                    AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                }
                // Attach intent auth gate for signup-at-intent
                .withIntentAuthGate()
            
            // Terms checking overlay
            if isCheckingTerms {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .task {
            await checkTermsAcceptance()
        }
        .fullScreenCover(isPresented: $showTermsAgreement) {
            TermsAgreementView {
                showTermsAgreement = false
            }
        }
        // Parties onboarding for first-time users
        .fullScreenCover(isPresented: $showPartiesOnboarding) {
            PartiesOnboardingView(
                onComplete: {
                    showPartiesOnboarding = false
                    hasCompletedPartiesOnboarding = true
                },
                onIntentAction: { action in
                    // Attempt the intent action - may trigger signup
                    if onboardingCoordinator.attemptIntentAction(action) {
                        // User is authenticated - execute action
                        action.completion?()
                        showPartiesOnboarding = false
                        hasCompletedPartiesOnboarding = true
                    }
                    // If not authenticated, signup sheet will be shown via IntentAuthGate
                }
            )
            .environmentObject(appState)
            .withIntentAuthGate()
        }
        // Listen for parties guide trigger from coordinator
        .onReceive(onboardingCoordinator.$shouldShowPartiesGuide) { shouldShow in
            if shouldShow && !hasCompletedPartiesOnboarding {
                showPartiesOnboarding = true
            }
        }
    }
    
    // MARK: - Terms Acceptance Check
    
    private func checkTermsAcceptance() async {
        // Only check terms if user is authenticated
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            // No user logged in - that's OK in the new flow!
            // They can browse without signing up
            await MainActor.run {
                isCheckingTerms = false
            }
            return
        }
        
        do {
            let accepted = try await UserProfileService.shared.checkTermsAccepted(userId: userId)
            await MainActor.run {
                isCheckingTerms = false
                if !accepted {
                    showTermsAgreement = true
                }
            }
        } catch {
            print("⚠️ Failed to check terms acceptance: \(error.localizedDescription)")
            await MainActor.run {
                isCheckingTerms = false
                // Default to showing terms if we can't verify
                showTermsAgreement = true
            }
        }
    }
}
