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
    private let env = AppEnvironment.current
    
    init() {
        // Initialize Firebase and connect to emulators
        _ = FirebaseManager.shared
        
        // Configure push notifications
        NotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                CrowdHomeView()
                    .environmentObject(appState)
                    .environment(\.appEnvironment, env)
                    .task { await appState.bootstrap() }
                    .onAppear {
                        AnalyticsService.shared.track("app_opened", props: [:])
                        AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                    }
            } else {
                OnboardingFlowView {
                    hasSeenOnboarding = true
                }
                .onAppear {
                    AnalyticsService.shared.track("app_opened", props: [:])
                    AnalyticsService.shared.logToFirestore(eventName: "app_opened")
                }
            }
        }
    }
}
