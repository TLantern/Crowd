//
//  IntentAuthGate.swift
//  Crowd
//
//  Reusable component that wraps intent actions (Save Event, I'm pulling up, etc.)
//  If the user is not authenticated, it presents a signup sheet.
//  If authenticated, it executes the action immediately.
//
//  WHY SIGNUP IS DELAYED UNTIL INTENT:
//  - Users see value before being asked to commit (higher conversion)
//  - Reduces friction for first-time exploration
//  - Creates a "moment of intent" where users are more likely to sign up
//  - Canceling signup only cancels the action, not app access
//

import SwiftUI

// MARK: - Intent Auth Gate View Modifier

struct IntentAuthGateModifier: ViewModifier {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @State private var showSignupSheet: Bool = false
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSignupSheet) {
                SignupSheetView(
                    onComplete: {
                        showSignupSheet = false
                        coordinator.completePendingAction()
                        
                        // Execute the completion handler if there was a pending action
                        coordinator.pendingIntentAction?.completion?()
                    },
                    onCancel: {
                        showSignupSheet = false
                        coordinator.cancelSignup()
                    }
                )
                .interactiveDismissDisabled()
            }
            .onChange(of: coordinator.shouldPromptForSignup) { oldVal, newVal in
                if newVal {
                    showSignupSheet = true
                }
            }
    }
}

extension View {
    /// Attaches the intent auth gate to this view.
    /// When an intent action is attempted by an unauthenticated user, a signup sheet is shown.
    func withIntentAuthGate() -> some View {
        self.modifier(IntentAuthGateModifier())
    }
}

// MARK: - Intent Auth Gate Button

/// A button that wraps an intent action with authentication check.
/// If user is not authenticated, shows signup sheet before executing action.
struct IntentAuthGateButton<Label: View>: View {
    let actionType: String
    let eventId: String?
    let action: () -> Void
    let label: () -> Label
    
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    
    init(
        actionType: String,
        eventId: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.actionType = actionType
        self.eventId = eventId
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: handleTap) {
            label()
        }
    }
    
    private func handleTap() {
        let intentAction = IntentAction(
            type: actionType,
            eventId: eventId,
            completion: action
        )
        
        // If user is authenticated, execute immediately
        // Otherwise, coordinator will trigger signup flow
        if coordinator.attemptIntentAction(intentAction) {
            action()
        }
    }
}

// MARK: - Convenience Initializers

extension IntentAuthGateButton where Label == Text {
    /// Creates an intent auth gate button with a text label.
    init(
        _ title: String,
        actionType: String,
        eventId: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(actionType: actionType, eventId: eventId, action: action) {
            Text(title)
        }
    }
}

// MARK: - Intent Action Types

enum IntentActionType: String {
    case saveEvent = "save_event"
    case pullingUp = "pulling_up"
    case joinChat = "join_chat"
    case hostEvent = "host_event"
    case followUser = "follow_user"
    case sendMessage = "send_message"
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        IntentAuthGateButton(
            "Save Event",
            actionType: IntentActionType.saveEvent.rawValue,
            eventId: "test-event-123"
        ) {
            print("Event saved!")
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(12)
        
        IntentAuthGateButton(
            actionType: IntentActionType.pullingUp.rawValue,
            eventId: "test-event-456"
        ) {
            print("User is pulling up!")
        } label: {
            HStack {
                Image(systemName: "flame.fill")
                Text("I'm pulling up")
            }
            .padding()
            .background(Color(hex: 0x02853E))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    .withIntentAuthGate()
}
