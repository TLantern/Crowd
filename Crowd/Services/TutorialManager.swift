//
//  TutorialManager.swift
//  Crowd
//
//  Created by Cursor on 11/7/25.
//

import Foundation

final class TutorialManager {
    static let shared = TutorialManager()
    
    private let hasCompletedTutorialKey = "hasCompletedTutorial"
    private let hasSeenEventNavigationOnboardingKey = "hasSeenEventNavigationOnboarding"
    
    private init() {}
    
    /// Check if the tutorial should be shown to the user
    func shouldShowTutorial() -> Bool {
        return !UserDefaults.standard.bool(forKey: hasCompletedTutorialKey)
    }
    
    /// Mark the tutorial as completed
    func markTutorialComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedTutorialKey)
        print("✅ Tutorial marked as completed")
    }
    
    /// Reset tutorial state (for testing or replay from settings)
    func resetTutorial() {
        UserDefaults.standard.set(false, forKey: hasCompletedTutorialKey)
        print("🔄 Tutorial reset - will show again")
    }
    
    /// Check if EventNavigationModal onboarding should be shown
    func shouldShowEventNavigationOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: hasSeenEventNavigationOnboardingKey)
    }
    
    /// Mark EventNavigationModal onboarding as completed
    func markEventNavigationOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: hasSeenEventNavigationOnboardingKey)
        print("✅ EventNavigationModal onboarding marked as completed")
    }
}

