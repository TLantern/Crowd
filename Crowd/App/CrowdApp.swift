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
import FirebaseAuth

@main
struct CrowdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator.shared
    @StateObject private var deepLinks = DeepLinkManager.shared
    
    // NEW: Campus selection gate (replaces mandatory onboarding)
    @AppStorage("hasCompletedCampusSelection") private var hasCompletedCampusSelection = false
    @AppStorage("hasCompletedPartiesOnboarding") private var hasCompletedPartiesOnboarding = false
    @AppStorage("hasCompletedAccountCreation") private var hasCompletedAccountCreation = false
    @AppStorage("hasSeenSplashScreen") private var hasSeenSplashScreen = false
    @AppStorage("useNewOnboarding") private var useNewOnboarding = true
    @AppStorage("userDisplayName") private var userDisplayName = ""
    
    // LEGACY: Keep for backwards compatibility with existing users
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    @State private var showTermsAgreement = false
    @State private var isCheckingTerms = true
    @State private var accountDeleted = false
    @State private var showPartiesOnboarding = false
    @State private var showAccountCreation = false
    @State private var showSplashScreen = true
    @State private var showCalendarReminderOverMap = false // Show calendar reminder over map after parties onboarding
    
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
                // MIGRATION: Existing users who completed old onboarding skip everything
                if hasSeenOnboarding && !hasCompletedCampusSelection {
                    // Migrate existing users - they already completed onboarding
                    Color.clear.onAppear {
                        hasSeenSplashScreen = true
                        hasCompletedCampusSelection = true
                        hasCompletedPartiesOnboarding = true
                        hasCompletedAccountCreation = true
                    }
                }
                
                // STEP 1: Show splash screen with Crowd logo (2 seconds)
                if !hasSeenSplashScreen && useNewOnboarding {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenSplashScreen = true
                        }
                    }
                    .onAppear {
                        AnalyticsService.shared.track("app_opened", props: ["flow": "new_onboarding"])
                        AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                    }
                }
                // STEP 2: Campus selection - "Join the Crowd"
                else if !hasCompletedCampusSelection && useNewOnboarding {
                    CampusSelectionView {
                        // After campus selection, go to parties onboarding
                        // NO signup required at this point!
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedCampusSelection = true
                            hasSeenOnboarding = true // Mark old flag too for safety
                        }
                        
                        // REQUIRED: Show parties onboarding - user MUST go through it
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPartiesOnboarding = true
                        }
                    }
                    .transition(.opacity)
                }
                // STEP 3: Main app (after all onboarding steps complete)
                else if hasCompletedCampusSelection {
                    mainAppView
                } else {
                    // Legacy flow for A/B testing (disabled by default)
                    OnboardingFlowView {
                        hasSeenOnboarding = true
                        hasSeenSplashScreen = true
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
            .preferredColorScheme(.light)
            .onChange(of: accountDeleted) { _, deleted in
                if deleted {
                    // Reset all onboarding flags on account deletion
                    hasSeenOnboarding = false
                    hasSeenSplashScreen = false
                    hasCompletedCampusSelection = false
                    hasCompletedPartiesOnboarding = false
                    hasCompletedAccountCreation = false
                    userDisplayName = ""
                    showTermsAgreement = false
                    showPartiesOnboarding = false
                    showAccountCreation = false
                    showSplashScreen = true
                    isCheckingTerms = true
                    accountDeleted = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .accountDeleted)) { _ in
                accountDeleted = true
            }
            .onOpenURL { url in
                DeepLinkManager.shared.handle(url: url)
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
            
            // Calendar reminder overlay (shown over map after parties onboarding)
            if showCalendarReminderOverMap {
                calendarReminderOverlay
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
                    
                    // After parties onboarding, show calendar reminder over map
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCalendarReminderOverMap = true
                        }
                    }
                },
                onIntentAction: { action in
                    // Attempt the intent action - may trigger signup
                    if onboardingCoordinator.attemptIntentAction(action) {
                        // User is authenticated - execute action
                        action.completion?()
                        showPartiesOnboarding = false
                        hasCompletedPartiesOnboarding = true
                        
                        // Show calendar reminder over map
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCalendarReminderOverMap = true
                            }
                        }
                    }
                    // If not authenticated, signup sheet will be shown via IntentAuthGate
                },
                onRequestAccountCreation: {
                    // First dismiss parties onboarding, then show account creation
                    // SwiftUI only allows one fullScreenCover at a time
                    showPartiesOnboarding = false
                    
                    // Wait for dismissal animation, then show account creation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showAccountCreation = true
                    }
                }
            )
            .environmentObject(appState)
            .withIntentAuthGate()
        }
        // Account creation during onboarding
        .fullScreenCover(isPresented: $showAccountCreation) {
            AccountCreationView { name, interests, profileImage in
                // Save the display name locally
                userDisplayName = name
                hasCompletedAccountCreation = true
                
                // Smooth transition: close account creation first
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAccountCreation = false
                }
                
                // Save interest IDs to UserDefaults (for local reference)
                let interestIds = interests.map { $0.id }
                UserDefaults.standard.set(interestIds, forKey: "selectedInterestIds")
                
                // ACTUALLY CREATE ACCOUNT IN FIREBASE
                // Note: Firebase stores interest NAMES, not IDs
                let interestNames = interests.map { $0.name }
                Task {
                    await createFirebaseAccount(
                        name: name,
                        interests: interestNames,
                        profileImage: profileImage
                    )
                }
                
                // Complete parties onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    OnboardingCoordinator.shared.completePartiesGuide()
                    hasCompletedPartiesOnboarding = true
                }
                
                AnalyticsService.shared.track("account_created", props: [
                    "name_length": name.count,
                    "interests_count": interests.count,
                    "has_profile_image": profileImage != nil
                ])
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
        // Listen for parties guide trigger from coordinator
        .onReceive(onboardingCoordinator.$shouldShowPartiesGuide) { shouldShow in
            if shouldShow && !hasCompletedPartiesOnboarding {
                showPartiesOnboarding = true
            }
        }
    }
    
    // MARK: - Calendar Reminder Overlay (shown over map)
    
    private var calendarReminderOverlay: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Reminder content
                VStack(spacing: 20) {
                    // Calendar icon with pulsing effect
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0x02853E).opacity(0.15))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(Color(hex: 0x02853E).opacity(0.25))
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(Color(hex: 0x02853E))
                    }
                    
                        // Message
                        VStack(spacing: 8) {
                            Text("Good to know 📅")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        
                        Text("You can always find parties/school\nevents in the calendar!")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // Arrow pointing to calendar
                    Image(systemName: "arrow.down")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: 0x02853E))
                        .padding(.top, 8)
                    
                    // Calendar tab highlight (icon only, no text)
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: 0x02853E))
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color(hex: 0x02853E).opacity(0.2))
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: 0x02853E), lineWidth: 2)
                                )
                        )
                    
                    // Got it button - dismisses and completes onboarding
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCalendarReminderOverMap = false
                        }
                        
                        AnalyticsService.shared.track("calendar_reminder_dismissed", props: [:])
                    }) {
                        Text("Got it!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: 0x02853E))
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .transition(.opacity)
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
    
    // MARK: - Create Firebase Account
    
    private func createFirebaseAccount(
        name: String,
        interests: [String],
        profileImage: UIImage?
    ) async {
        do {
            // Step 1: Get or create Firebase user (anonymous if not signed in)
            var userId = FirebaseManager.shared.getCurrentUserId()
            
            if userId == nil {
                // Create anonymous user
                print("📱 Creating anonymous Firebase user...")
                let result = try await Auth.auth().signInAnonymously()
                userId = result.user.uid
                print("✅ Anonymous user created: \(userId ?? "nil")")
            }
            
            guard let finalUserId = userId else {
                print("❌ Failed to get or create user ID")
                return
            }
            
            // Step 2: Create user profile in Firestore
            print("📝 Creating user profile in Firestore...")
            let campus = OnboardingCoordinator.shared.currentCampusId
            
            try await UserProfileService.shared.createProfile(
                userId: finalUserId,
                displayName: name,
                campus: campus,
                interests: interests,
                profileImage: profileImage
            )
            
            print("✅ User profile created successfully!")
            
            // Track success
            AnalyticsService.shared.track("firebase_account_created", props: [
                "user_id": finalUserId,
                "campus": campus,
                "interests_count": interests.count,
                "has_profile_image": profileImage != nil
            ])
            
        } catch {
            print("❌ Failed to create Firebase account: \(error.localizedDescription)")
            
            // Track failure
            AnalyticsService.shared.track("firebase_account_creation_failed", props: [
                "error": error.localizedDescription
            ])
        }
    }
}
