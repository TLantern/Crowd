//
//  ProfileView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import FirebaseFunctions
import ComponentsKit
import CoreLocation

// MARK: - Entry
struct RootView: View {
    @State private var showProfile = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Open Profile") { showProfile = true }
                .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(viewModel: ProfileViewModel.mock)
                .modifier(Presentation75Detent())
        }
    }
}

// MARK: - 3/4 Sheet Detent
private struct Presentation75Detent: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents(Set([.fraction(0.75), .large]))
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        } else {
            content
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @StateObject private var statsService = UserStatsService.shared
    @ObservedObject private var locationService = AppEnvironment.current.location
    @State private var showInterestPicker = false
    @State private var showImagePicker = false
    @State private var isLoading = true
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var carouselOffset: CGFloat = 0
    @State private var interestCarouselTimer: Timer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isLoading {
                ProgressView("Loading profile...")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        identityCard
                        tagsCard
                        statsCard
                        debugTestBannerCard
                    }
                    .padding(16)
                }

                // Edit Mode Toggle Button
                Button(action: { 
                    if viewModel.isEditMode {
                        Task {
                            await saveChanges()
                        }
                    }
                    viewModel.toggleEditMode()
                }) {
                    Image(systemName: viewModel.isEditMode ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(viewModel.isEditMode ? Color.green : Color.accentColor)
                        .background(Circle().fill(Color(.systemBackground)).frame(width: 44, height: 44))
                }
                .padding(16)
            }
        }
        .task {
            await loadProfile()
            if let userId = FirebaseManager.shared.getCurrentUserId() {
                statsService.startListening(userId: userId)
            }
        }
        .onAppear {
            AnalyticsService.shared.trackScreenView("profile")
        }
        .onDisappear {
            statsService.stopListening()
            stopInterestCarousel()
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $viewModel.profileImage)
        }
        .sheet(isPresented: $showInterestPicker) {
            InterestPickerView(viewModel: viewModel)
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Firebase Actions
    
    private func loadProfile() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            isLoading = false
            return
        }
        
        await viewModel.loadProfile(userId: userId)
        isLoading = false
    }
    
    private func saveChanges() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        await viewModel.saveChanges(userId: userId)
    }
    
    // MARK: - Card Model
    private var cardModel: CardVM {
        CardVM {
            $0.cornerRadius = .medium
            $0.shadow = .medium
            $0.backgroundColor = .background
            $0.borderWidth = .medium
        }
    }

    // MARK: - Identity Card
    private var identityCard: some View {
        SUCard(model: cardModel) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottom) {
                    if let profileImage = viewModel.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                    } else {
                        AvatarView(
                            name: viewModel.displayName,
                            color: viewModel.avatarColor,
                            size: 90,
                            showOnlineStatus: viewModel.isActiveNow
                        )
                    }

                    if viewModel.isEditMode {
                        Button(action: { showImagePicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill").font(.system(size: 10))
                                Text("Edit").font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7), in: Capsule())
                        }
                        .offset(y: 8)
                    }
                }

                Text(viewModel.handle)
                    .font(.system(size: 18, weight: .bold))

                // bio removed

                Text(viewModel.affiliation)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 200)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Card
    private var statsCard: some View {
        let attendedEvents = AttendedEventsService.shared.getAttendedEvents()
        
        return SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Status")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    statCard(title: "Hosted", value: "\(statsService.hostedCount)")
                    statCard(title: "Joined", value: "\(statsService.joinedCount)")
                    statCard(title: "Upcoming", value: "\(statsService.upcomingCount)")
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 12) {
                    if attendedEvents.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 24))
                                .foregroundStyle(.gray.opacity(0.6))
                            
                            Text("No events attending yet")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            
                            Text("Join events from the calendar to see them here")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(attendedEvents.prefix(5)) { event in
                                AttendedEventRow(event: event)
                            }
                            
                            if attendedEvents.count > 5 {
                                Text("+ \(attendedEvents.count - 5) more events")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 18, weight: .semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
    }

    // MARK: - Tags Card
    private var tagsCard: some View {
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Interests")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                if viewModel.isEditMode {
                    // Show all interests in edit mode
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.interests) { interest in
                                TagPillView(
                                    interest: interest,
                                    isEditMode: viewModel.isEditMode,
                                    onDelete: { viewModel.removeInterest(interest) }
                                )
                            }

                            AddInterestPillView { showInterestPicker = true }
                        }
                    }
                } else {
                    // Carousel mode - show one at a time with auto-rotation
                    interestCarouselView
                }
            }
        }
        .onAppear {
            if !viewModel.isEditMode && !viewModel.interests.isEmpty {
                startInterestCarousel()
            }
        }
        .onChange(of: viewModel.isEditMode) { _, isEditMode in
            if isEditMode {
                stopInterestCarousel()
            } else if !viewModel.interests.isEmpty {
                startInterestCarousel()
            }
        }
        .onChange(of: viewModel.interests.count) { _, count in
            if count == 0 {
                stopInterestCarousel()
                carouselOffset = 0
            } else if !viewModel.isEditMode {
                startInterestCarousel()
            }
        }
    }
    
    // MARK: - Interest Carousel
    private var interestCarouselView: some View {
        Group {
            if viewModel.interests.isEmpty {
                Text("No interests yet")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                GeometryReader { geometry in
                    let spacing: CGFloat = 8
                    
                    // Create duplicated array for seamless looping (3 copies)
                    let duplicatedInterests = viewModel.interests + viewModel.interests + viewModel.interests
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(Array(duplicatedInterests.enumerated()), id: \.offset) { index, interest in
                                TagPillView(
                                    interest: interest,
                                    isEditMode: false,
                                    onDelete: {}
                                )
                                .background(
                                    GeometryReader { pillGeometry in
                                        Color.clear
                                            .preference(
                                                key: PillWidthPreferenceKey.self,
                                                value: pillGeometry.size.width
                                            )
                                    }
                                )
                            }
                        }
                        .offset(x: carouselOffset)
                        .onPreferenceChange(PillWidthPreferenceKey.self) { widths in
                            // Could use this for dynamic width calculation if needed
                        }
                    }
                    .scrollDisabled(true)
                    .onAppear {
                        // Calculate single set width based on actual pill sizes
                        let estimatedWidth = estimateSingleSetWidth(interests: viewModel.interests, spacing: spacing)
                        carouselOffset = -estimatedWidth // Start at middle set
                        startContinuousCarousel(singleSetWidth: estimatedWidth)
                    }
                }
                .frame(height: 50)
                .clipped()
            }
        }
    }
    
    private func estimateSingleSetWidth(interests: [Interest], spacing: CGFloat) -> CGFloat {
        // Estimate: each pill is roughly 80-120px wide depending on text length
        // Use average of 100px per pill
        let averagePillWidth: CGFloat = 100
        let totalSpacing = CGFloat(max(0, interests.count - 1)) * spacing
        return CGFloat(interests.count) * averagePillWidth + totalSpacing
    }
    
    // MARK: - Interest Carousel Timer
    private func startInterestCarousel() {
        stopInterestCarousel()
        
        guard viewModel.interests.count > 1 else { return }
        
        let singleSetWidth = estimateSingleSetWidth(interests: viewModel.interests, spacing: 8)
        startContinuousCarousel(singleSetWidth: singleSetWidth)
    }
    
    private func startContinuousCarousel(singleSetWidth: CGFloat) {
        stopInterestCarousel()
        
        guard viewModel.interests.count > 1 else { return }
        
        // Initialize offset to middle set if not already set
        if carouselOffset == 0 {
            carouselOffset = -singleSetWidth
        }
        
        // Continuous smooth scrolling - slower and smoother animation
        interestCarouselTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            DispatchQueue.main.async {
                // Check if we need to reset before animating
                if carouselOffset <= -singleSetWidth * 2 {
                    // Jump back without animation for seamless loop
                    carouselOffset = -singleSetWidth
                } else {
                    // Smooth continuous scroll - slower speed with easeInOut for smoother feel
                    withAnimation(.easeInOut(duration: 0.03)) {
                        carouselOffset -= 0.2
                    }
                }
            }
        }
        
        // Add timer to common run loop modes so it continues during scrolling
        if let timer = interestCarouselTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopInterestCarousel() {
        interestCarouselTimer?.invalidate()
        interestCarouselTimer = nil
    }
    
    // MARK: - Debug Test Banner Card
    @ViewBuilder
    private var debugTestBannerCard: some View {
        #if DEBUG
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                Button(action: {
                    // Create mock event for testing
                    let mockEvent = CrowdEvent(
                        id: UUID().uuidString,
                        title: "Test Event",
                        hostId: FirebaseManager.shared.getCurrentUserId() ?? "test",
                        hostName: "Test Host",
                        latitude: locationService.lastKnown?.latitude ?? 33.2100,
                        longitude: locationService.lastKnown?.longitude ?? -97.1500,
                        radiusMeters: 60,
                        startsAt: Date(),
                        endsAt: Date().addingTimeInterval(3600),
                        createdAt: Date(),
                        signalStrength: 3,
                        attendeeCount: 0,
                        tags: ["party"],
                        category: "party"
                    )
                    
                    // Post notification to trigger banner
                    NotificationCenter.default.post(
                        name: .testNewEventBanner,
                        object: mockEvent
                    )
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Test New Event Banner")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        #else
        EmptyView()
        #endif
    }
    
}

// MARK: - Preference Key for Pill Width
private struct PillWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Attended Event Row
struct AttendedEventRow: View {
    let event: CrowdEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Event icon
            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .medium))
                )
            
            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let startsAt = event.startsAt {
                    Text(formatEventDate(startsAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                
                Text("Attending")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews
#Preview {
    RootView()
}
