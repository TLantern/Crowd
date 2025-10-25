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
    @StateObject private var appState = AppState()
    private let env = AppEnvironment.current
    
    init() {
        // Initialize Firebase and connect to emulators
        _ = FirebaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            CrowdHomeView()
                .environmentObject(appState)
                .environment(\.appEnvironment, env)
                .task { await appState.bootstrap() }
        }
    }
}
