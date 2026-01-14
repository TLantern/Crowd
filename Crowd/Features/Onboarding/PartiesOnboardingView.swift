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
    @State private var eventsViewedCount: Int = 0 // Count of events user has seen
    
    let onComplete: () -> Void
    let onIntentAction: (IntentAction) -> Void
    let onRequestAccountCreation: (() -> Void)? // Callback to trigger account creation
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Header with exit button
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
        }
        .onAppear {
            viewModel.loadEvents()
            eventsViewedCount = 1 // User sees first event on load
            
            AnalyticsService.shared.trackScreenView("parties_onboarding")
        }
        .onChange(of: currentIndex) { oldVal, newVal in
            eventsViewedCount = newVal + 1
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("What's Happening")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Swipe through events near you")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Done button - always visible
            Button(action: {
                OnboardingCoordinator.shared.completePartiesGuide()
                onComplete()
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: 0x02853E))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0x02853E).opacity(0.2))
                    )
            }
        }
        .padding(.bottom, 20)
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
                OnboardingCoordinator.shared.completePartiesGuide()
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
            
            // Next button
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
                        .fill(currentIndex < viewModel.events.count - 1 ? Color(hex: 0x02853E) : Color.gray.opacity(0.5))
                )
            }
            .disabled(currentIndex >= viewModel.events.count - 1)
            
            // Next button (small)
            Button(action: {
                if currentIndex < viewModel.events.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        currentIndex += 1
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(currentIndex < viewModel.events.count - 1 ? .white : .white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.2))
                    )
            }
            .disabled(currentIndex >= viewModel.events.count - 1)
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
