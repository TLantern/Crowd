//
//  CrowdApp.swift
//  Crowd
//
//  Created by Teni Owojori on 10/18/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics

@main
struct CrowdApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showTermsAgreement = false
    @State private var isCheckingTerms = true
    @State private var accountDeleted = false
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
                if hasSeenOnboarding {
                    ZStack {
                        CrowdHomeView()
                            .environmentObject(appState)
                            .environment(\.appEnvironment, env)
                            .task { await appState.bootstrap() }
                            .onAppear {
                                AnalyticsService.shared.track("app_opened", props: [:])
                                AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                            }
                        
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
                } else {
                    OnboardingFlowView {
                        hasSeenOnboarding = true
                        // After onboarding, show terms agreement
                        showTermsAgreement = true
                        isCheckingTerms = false
                    }
                    .onAppear {
                        AnalyticsService.shared.track("app_opened", props: [:])
                        AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                    }
                }
            }
            .onChange(of: accountDeleted) { _, deleted in
                if deleted {
                    hasSeenOnboarding = false
                    showTermsAgreement = false
                    isCheckingTerms = true
                    accountDeleted = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .accountDeleted)) { _ in
                accountDeleted = true
            }
        }
    }
    
    private func checkTermsAcceptance() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            isCheckingTerms = false
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
