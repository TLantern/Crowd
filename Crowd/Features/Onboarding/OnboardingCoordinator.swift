//
//  OnboardingCoordinator.swift
//  Crowd
//
//  State machine for managing onboarding flow.
//  Tracks progress through: Campus Selection → Map Exploration → Parties Guide → Complete
//
//  WHY SIGNUP IS DELAYED:
//  - Shows immediate value before asking for commitment
//  - Allows users to explore and see "proof of life"
//  - Converts users at moment of intent (higher quality signups)
//  - Reduces friction for first-time users
//

import SwiftUI
import Combine

// MARK: - Onboarding State

enum OnboardingState: String, Codable {
    case campusSelection = "campus_selection"
    case mapExploration = "map_exploration"
    case partiesGuide = "parties_guide"
    case complete = "complete"
    
    var next: OnboardingState? {
        switch self {
        case .campusSelection: return .mapExploration
        case .mapExploration: return .partiesGuide
        case .partiesGuide: return .complete
        case .complete: return nil
        }
    }
}

// MARK: - Onboarding Coordinator

@MainActor
class OnboardingCoordinator: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var currentState: OnboardingState = .campusSelection
    @Published var shouldShowPartiesGuide: Bool = false
    @Published var shouldPromptForSignup: Bool = false
    @Published var pendingIntentAction: IntentAction? = nil
    
    // MARK: - Storage Keys
    
    @AppStorage("hasCompletedCampusSelection") private var hasCompletedCampusSelection: Bool = false
    @AppStorage("hasCompletedPartiesOnboarding") private var hasCompletedPartiesOnboarding: Bool = false
    @AppStorage("selectedCampusId") private var selectedCampusId: String = "UNT"
    @AppStorage("useNewOnboarding") private var useNewOnboarding: Bool = true
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = OnboardingCoordinator()
    
    // MARK: - Initialization
    
    init() {
        // Restore state from storage
        restoreState()
    }
    
    // MARK: - State Management
    
    private func restoreState() {
        // Determine initial state based on stored values
        if !hasCompletedCampusSelection {
            currentState = .campusSelection
        } else if !hasCompletedPartiesOnboarding {
            // User has selected campus but hasn't seen parties guide
            currentState = .mapExploration
        } else {
            currentState = .complete
        }
        
        print("📍 Onboarding restored to state: \(currentState.rawValue)")
    }
    
    /// Advance to next onboarding state
    func advance() {
        guard let nextState = currentState.next else {
            print("📍 Onboarding already complete")
            return
        }
        
        let previousState = currentState
        currentState = nextState
        
        // Update storage based on new state
        switch nextState {
        case .mapExploration:
            hasCompletedCampusSelection = true
        case .partiesGuide:
            shouldShowPartiesGuide = true
        case .complete:
            hasCompletedPartiesOnboarding = true
            shouldShowPartiesGuide = false
        case .campusSelection:
            break // Shouldn't happen
        }
        
        // Track analytics
        AnalyticsService.shared.track("onboarding_state_changed", props: [
            "from_state": previousState.rawValue,
            "to_state": nextState.rawValue,
            "campus_id": selectedCampusId
        ])
        
        print("📍 Onboarding advanced: \(previousState.rawValue) → \(nextState.rawValue)")
    }
    
    /// Complete the parties guide step
    func completePartiesGuide() {
        shouldShowPartiesGuide = false
        hasCompletedPartiesOnboarding = true
        currentState = .complete
        
        AnalyticsService.shared.track("parties_onboarding_completed", props: [
            "campus_id": selectedCampusId
        ])
        
        print("📍 Parties onboarding completed")
    }
    
    /// Skip the parties guide
    func skipPartiesGuide() {
        shouldShowPartiesGuide = false
        hasCompletedPartiesOnboarding = true
        currentState = .complete
        
        AnalyticsService.shared.track("parties_onboarding_skipped", props: [
            "campus_id": selectedCampusId
        ])
        
        print("📍 Parties onboarding skipped")
    }
    
    // MARK: - Intent Action Handling
    
    /// Attempt an intent action (Save Event, I'm pulling up, etc.)
    /// If user is not authenticated, this will trigger signup flow
    func attemptIntentAction(_ action: IntentAction) -> Bool {
        // Check if user is authenticated
        if let userId = FirebaseManager.shared.getCurrentUserId(), !userId.isEmpty {
            // User is authenticated - execute action immediately
            print("✅ User authenticated, executing intent action: \(action.type)")
            pendingIntentAction = nil
            return true
        } else {
            // User is NOT authenticated - store action and prompt signup
            // DELAYED SIGNUP: This is the key moment where we finally ask for signup
            // The user has explored the app and shown intent - they're more likely to convert
            print("🔐 User not authenticated, storing intent action and prompting signup")
            pendingIntentAction = action
            shouldPromptForSignup = true
            
            AnalyticsService.shared.track("signup_prompted_at_intent", props: [
                "action_type": action.type,
                "event_id": action.eventId ?? "unknown"
            ])
            
            return false
        }
    }
    
    /// Called after successful signup to complete the pending action
    func completePendingAction() {
        if let action = pendingIntentAction {
            AnalyticsService.shared.track("pending_action_completed", props: [
                "action_type": action.type,
                "event_id": action.eventId ?? "unknown"
            ])
            print("✅ Completing pending intent action: \(action.type)")
        }
        shouldPromptForSignup = false
        pendingIntentAction = nil
    }
    
    /// Called when user cancels signup - action is cancelled but browsing continues
    func cancelSignup() {
        AnalyticsService.shared.track("signup_cancelled", props: [
            "had_pending_action": pendingIntentAction != nil,
            "action_type": pendingIntentAction?.type ?? "none"
        ])
        
        shouldPromptForSignup = false
        pendingIntentAction = nil
        print("❌ Signup cancelled, browsing continues")
    }
    
    // MARK: - Campus Management
    
    /// Update the selected campus
    func selectCampus(_ campusId: String) {
        let previousCampus = selectedCampusId
        selectedCampusId = campusId
        
        AnalyticsService.shared.track("campus_changed", props: [
            "from_campus": previousCampus,
            "to_campus": campusId
        ])
        
        // Post notification so map and parties can refresh
        NotificationCenter.default.post(name: .campusChanged, object: campusId)
        
        print("📍 Campus changed: \(previousCampus) → \(campusId)")
    }
    
    /// Get the current campus ID
    var currentCampusId: String {
        selectedCampusId
    }
    
    // MARK: - Feature Flag
    
    var isNewOnboardingEnabled: Bool {
        useNewOnboarding
    }
    
    /// Reset onboarding (for testing)
    func resetOnboarding() {
        hasCompletedCampusSelection = false
        hasCompletedPartiesOnboarding = false
        selectedCampusId = "UNT"
        currentState = .campusSelection
        shouldShowPartiesGuide = false
        shouldPromptForSignup = false
        pendingIntentAction = nil
        
        print("📍 Onboarding reset")
    }
}

// MARK: - Intent Action

struct IntentAction {
    let type: String // "save_event", "pulling_up", "join_chat", etc.
    let eventId: String?
    let completion: (() -> Void)?
    
    init(type: String, eventId: String? = nil, completion: (() -> Void)? = nil) {
        self.type = type
        self.eventId = eventId
        self.completion = completion
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let campusChanged = Notification.Name("campusChanged")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
