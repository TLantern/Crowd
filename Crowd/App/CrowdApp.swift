//
//  CrowdApp.swift
//  Crowd
//
//  Created by Teni Owojori on 10/18/25.
//

import SwiftUI
import FirebaseCore

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
            } else {
                OnboardingFlowView {
                    hasSeenOnboarding = true
                }
            }
        }
    }
}
