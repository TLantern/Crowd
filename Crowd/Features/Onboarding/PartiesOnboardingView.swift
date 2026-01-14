//
//  PartiesOnboardingView.swift
//  Crowd
//
//  Guided parties swipe experience for new users.
//  Shows at least 3 events with social proof to demonstrate app value.
//  User can exit at any time but encouraged to complete swiping.
//

import SwiftUI
import Combine

struct PartiesOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PartiesOnboardingViewModel()
    @State private var currentIndex: Int = 0
    @State private var showIntentCTA: Bool = false
    @State private var hasViewedMinimumEvents: Bool = false // Track if user has swiped enough
    @State private var eventsViewedCount: Int = 0 // Count of events user has seen
    @State private var showCalendarHighlight: Bool = false // Show calendar tab highlight on last event
    @State private var showFinalCalendarReminder: Bool = false // Final reminder before completion
    @State private var isInFinalEventsPhase: Bool = false // After account creation, show 3 more events
    @State private var finalEventsViewed: Int = 0 // Count of final events viewed
    @State private var showAccountCreation: Bool = false // Show account creation overlay
    
    let onComplete: () -> Void
    let onIntentAction: (IntentAction) -> Void
    let onRequestAccountCreation: (() -> Void)? // Callback to trigger account creation
    
    // Minimum events user must view before account creation (4 events)
    private let minimumEventsToView = 4
    // Number of final events to show after account creation
    private let finalEventsCount = 3
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Header with progress and exit
                headerView
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.events.isEmpty {
                    emptyStateView
                } else {
                    // Swipe cards
                    swipeCardsView
                    
                    // Progress dots
                    progressDotsView
                    
                    // Action buttons
                    actionButtonsView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            
            // Calendar tab highlight overlay (shown on 4th event)
            if showCalendarHighlight {
                calendarHighlightOverlay
            }
            
            // Account creation overlay (if using inline flow)
            if showAccountCreation {
                AccountCreationView { name, interests in
                    // Account created - start final events phase
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAccountCreation = false
                        isInFinalEventsPhase = true
                        finalEventsViewed = 0
                        // Reset to show next events after current position
                        if currentIndex < viewModel.events.count - 1 {
                            currentIndex += 1
                        }
                    }
                    
                    AnalyticsService.shared.track("account_created_in_onboarding", props: [
                        "name": name,
                        "interests_count": interests.count
                    ])
                }
                .transition(.opacity)
            }
            
            // Final calendar reminder before completion
            if showFinalCalendarReminder {
                finalCalendarReminderOverlay
            }
        }
        .onAppear {
            viewModel.loadEvents()
            eventsViewedCount = 1 // User sees first event on load
            
            AnalyticsService.shared.trackScreenView("parties_onboarding")
        }
        // Track swiping progress and check for intent CTA
        .onChange(of: currentIndex) { oldVal, newVal in
            // Update events viewed count
            eventsViewedCount = newVal + 1
            
            // If in final events phase, track those separately
            if isInFinalEventsPhase {
                finalEventsViewed += 1
                
                // After 3 final events, show the final calendar reminder
                if finalEventsViewed >= finalEventsCount {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFinalCalendarReminder = true
                    }
                }
            } else {
                // Show calendar highlight on the 4th event (last required event before account creation)
                if eventsViewedCount == minimumEventsToView && !showCalendarHighlight && !isInFinalEventsPhase {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCalendarHighlight = true
                    }
                }
                
                // Check if user has viewed minimum events
                if eventsViewedCount >= minimumEventsToView {
                    withAnimation {
                        hasViewedMinimumEvents = true
                    }
                }
            }
            
            checkForIntentCTA()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isInFinalEventsPhase ? "Almost Done!" : "What's Happening")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Dynamic instruction text
                    if isInFinalEventsPhase {
                        let remaining = max(0, finalEventsCount - finalEventsViewed)
                        if remaining > 0 {
                            Text("Check out \(remaining) more event\(remaining == 1 ? "" : "s")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: 0x02853E))
                        } else {
                            Text("You're all set!")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: 0x02853E))
                        }
                    } else if !hasViewedMinimumEvents && !viewModel.events.isEmpty {
                        let remaining = max(0, minimumEventsToView - eventsViewedCount)
                        Text("Swipe through \(remaining) more event\(remaining == 1 ? "" : "s") to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: 0x02853E))
                    } else {
                        Text("Swipe through events near you")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Exit button - only visible after viewing minimum events
                if hasViewedMinimumEvents {
                    Button(action: {
                        OnboardingCoordinator.shared.skipPartiesGuide()
                        onComplete()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Progress indicator showing how many events they need to view
            if !hasViewedMinimumEvents && !viewModel.events.isEmpty {
                HStack(spacing: 8) {
                    ForEach(0..<minimumEventsToView, id: \.self) { index in
                        Circle()
                            .fill(index < eventsViewedCount ? Color(hex: 0x02853E) : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 20)
        .animation(.spring(response: 0.3), value: hasViewedMinimumEvents)
    }
    
    // MARK: - Calendar Highlight Overlay
    
    private var calendarHighlightOverlay: some View {
        ZStack {
            // Dark overlay behind
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss on tap anywhere
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCalendarHighlight = false
                    }
                }
            
            VStack {
                Spacer()
                
                // Calendar tab highlight at bottom
                VStack(spacing: 16) {
                    // Arrow pointing down to tab
                    Image(systemName: "arrow.down")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x02853E))
                    
                    // Message box
                    VStack(spacing: 12) {
                        // Calendar icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: 0x02853E).opacity(0.2))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(Color(hex: 0x02853E))
                        }
                        
                        Text("📅 The Parties Tab")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("This is where all the parties\nand future events are located!")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                        
                        // Got it button - triggers account creation
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCalendarHighlight = false
                            }
                            AnalyticsService.shared.track("calendar_highlight_dismissed", props: [:])
                            
                            // Trigger account creation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                if let onRequestAccountCreation = onRequestAccountCreation {
                                    onRequestAccountCreation()
                                } else {
                                    // Fallback: show inline account creation
                                    showAccountCreation = true
                                }
                            }
                        }) {
                            Text("Got it!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: 0x02853E))
                                )
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: 0x1C1C1E))
                    )
                    .padding(.horizontal, 40)
                    
                    // Highlighted calendar tab mockup
                    HStack(spacing: 0) {
                        Spacer()
                        
                        // Calendar tab (highlighted)
                        VStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: 0x02853E))
                            Text("Parties")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: 0x02853E))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: 0x02853E).opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: 0x02853E), lineWidth: 2)
                                )
                        )
                        
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Final Calendar Reminder Overlay
    
    private var finalCalendarReminderOverlay: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
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
                        Text("One last thing! 👆")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Remember, you can always find\nparties and events here!")
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
                    
                    // Calendar tab highlight
                    VStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: 0x02853E))
                        Text("Parties")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: 0x02853E))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: 0x02853E).opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: 0x02853E), lineWidth: 2)
                            )
                    )
                    
                    // All set button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFinalCalendarReminder = false
                        }
                        
                        AnalyticsService.shared.track("final_calendar_reminder_dismissed", props: [:])
                        
                        // Complete onboarding
                        OnboardingCoordinator.shared.completePartiesGuide()
                        onComplete()
                    }) {
                        Text("All Set! 🎉")
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
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading events...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "party.popper")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
            
            Text("Nothing popping right now")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Check back soon — events are added daily!")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: {
                viewModel.loadEvents()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(hex: 0x02853E))
                )
            }
            .padding(.top, 8)
            
            Spacer()
            
            // When no events, allow user to continue (they've seen the parties tab)
            Button(action: {
                // Mark as viewed since there's nothing to show
                hasViewedMinimumEvents = true
                OnboardingCoordinator.shared.skipPartiesGuide()
                onComplete()
            }) {
                Text("Continue to Map")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: 0x02853E))
                    )
            }
        }
    }
    
    // MARK: - Swipe Cards View
    
    private var swipeCardsView: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(viewModel.events.indices.reversed(), id: \.self) { index in
                    if index >= currentIndex && index < currentIndex + 3 {
                        EventOnboardingCard(
                            event: viewModel.events[index],
                            isTopCard: index == currentIndex
                        )
                        .offset(y: CGFloat(index - currentIndex) * 8)
                        .scaleEffect(1.0 - CGFloat(index - currentIndex) * 0.05)
                        .opacity(index == currentIndex ? 1.0 : 0.7)
                        .gesture(
                            index == currentIndex ? swipeGesture : nil
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 420)
    }
    
    // MARK: - Swipe Gesture
    
    @State private var dragOffset: CGSize = .zero
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                
                if abs(value.translation.width) > threshold {
                    // Swipe detected - move to next card
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        if currentIndex < viewModel.events.count - 1 {
                            currentIndex += 1
                        }
                    }
                    
                    AnalyticsService.shared.track("party_card_swiped", props: [
                        "event_index": currentIndex,
                        "swipe_direction": value.translation.width > 0 ? "right" : "left"
                    ])
                }
                
                dragOffset = .zero
            }
    }
    
    // MARK: - Progress Dots
    
    private var progressDotsView: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(viewModel.events.count, 10), id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
            }
            
            if viewModel.events.count > 10 {
                Text("+\(viewModel.events.count - 10)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if showIntentCTA && hasViewedMinimumEvents {
                // Show intent action CTA after swiping through required events
                intentCTAView
            } else {
                // Instruction text for what user needs to do
                if !hasViewedMinimumEvents {
                    Text("👆 Tap Next to see more events")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: 0x02853E))
                        .padding(.bottom, 4)
                }
                
                // Navigation buttons
                HStack(spacing: 16) {
                    // Previous button
                    Button(action: {
                        if currentIndex > 0 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                currentIndex -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(currentIndex > 0 ? .white : .white.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .disabled(currentIndex == 0)
                    
                    // Main action button - changes based on progress
                    if hasViewedMinimumEvents {
                        // After minimum events, show Save button
                        Button(action: {
                            let event = viewModel.events[currentIndex]
                            onIntentAction(IntentAction(
                                type: "save_event",
                                eventId: event.id
                            ))
                        }) {
                            HStack {
                                Image(systemName: "bookmark")
                                Text("Save Event")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
                        }
                    } else {
                        // Before minimum events, show prominent NEXT button
                        Button(action: {
                            if currentIndex < viewModel.events.count - 1 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    currentIndex += 1
                                }
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: 0x02853E))
                            )
                        }
                    }
                    
                    // Next button (small) - only after minimum viewed
                    if hasViewedMinimumEvents {
                        Button(action: {
                            if currentIndex < viewModel.events.count - 1 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    currentIndex += 1
                                }
                            } else {
                                // Last card - show completion
                                showIntentCTA = true
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Intent CTA View
    
    private var intentCTAView: some View {
        VStack(spacing: 16) {
            // Success message
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: 0x02853E))
                
                Text("Nice! You've seen the events")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Ready to join the crowd?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Primary CTA - This triggers the signup if not authenticated
            Button(action: {
                onIntentAction(IntentAction(
                    type: "pulling_up",
                    eventId: viewModel.events.last?.id,
                    completion: {
                        // Show final calendar reminder before completing
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFinalCalendarReminder = true
                        }
                    }
                ))
            }) {
                HStack {
                    Image(systemName: "flame.fill")
                    Text("I'm pulling up")
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: 0x02853E))
                )
            }
            
            // Secondary - Continue to explore (shows final reminder first)
            Button(action: {
                // Show final calendar reminder before completing
                withAnimation(.easeInOut(duration: 0.3)) {
                    showFinalCalendarReminder = true
                }
            }) {
                Text("Continue to Map")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func checkForIntentCTA() {
        // Show intent CTA after viewing at least 3 events or reaching the end
        let minEventsViewed = min(3, viewModel.events.count)
        if currentIndex >= minEventsViewed - 1 && currentIndex == viewModel.events.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                showIntentCTA = true
            }
        }
    }
}

// MARK: - Event Onboarding Card

struct EventOnboardingCard: View {
    let event: CrowdEvent
    let isTopCard: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event image
            ZStack(alignment: .topTrailing) {
                if let imageUrl = event.imageURL, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderImage
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.gray.opacity(0.2))
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .frame(height: 200)
                    .clipped()
                } else {
                    placeholderImage
                        .frame(height: 200)
                }
                
                // Category badge
                if let categoryStr = event.category, 
                   let category = EventCategory(rawValue: categoryStr) {
                    Text(category.emoji)
                        .font(.system(size: 24))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .padding(12)
                }
            }
            
            // Event info
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                // Date and time
                if let startsAt = event.startsAt {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                        Text(formatDate(startsAt))
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray)
                }
                
                // Location
                if let location = event.rawLocationName {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 14))
                        Text(location)
                            .font(.system(size: 14))
                            .lineLimit(1)
                    }
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Social proof row
                HStack(spacing: 16) {
                    // Interest count (attendee count)
                    if event.attendeeCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                            Text("\(event.attendeeCount) interested")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: 0x02853E))
                    }
                    
                    // Signal strength as engagement indicator
                    if event.signalStrength > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                            Text("Hot")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
    }
    
    private var placeholderImage: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "party.popper.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - View Model

@MainActor
class PartiesOnboardingViewModel: ObservableObject {
    @Published var events: [CrowdEvent] = []
    @Published var isLoading: Bool = false
    
    private let repository = FirebaseEventRepository()
    
    func loadEvents() {
        isLoading = true
        
        Task {
            do {
                // Use main campus region for fetching events
                // The campus ID from coordinator (e.g., "UNT") is separate from CampusRegion enum
                let region: CampusRegion = .mainCampus
                
                // Fetch parties and official events in parallel
                async let partiesResult = repository.fetchParties()
                async let eventsResult = repository.fetchEventsSeparately(in: region)
                
                let allParties = try await partiesResult
                let (officialEvents, _) = try await eventsResult
                
                // Combine parties and official events, sort by date
                var combined = allParties + officialEvents
                combined.sort { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
                
                // Show at least 3, up to 10 events
                let maxEvents = min(10, combined.count)
                events = Array(combined.prefix(maxEvents))
                
                isLoading = false
                
                AnalyticsService.shared.track("parties_onboarding_loaded", props: [
                    "event_count": events.count
                ])
            } catch {
                print("❌ Failed to load events for onboarding: \(error)")
                isLoading = false
            }
        }
    }
}

#Preview {
    PartiesOnboardingView(
        onComplete: { print("Completed") },
        onIntentAction: { action in print("Intent: \(action.type)") },
        onRequestAccountCreation: { print("Account creation requested") }
    )
    .environmentObject(AppState())
}
