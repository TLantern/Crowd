//
//  EventDetailSheet.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import FirebaseFirestore
import ComponentsKit

extension Notification.Name {
    static let eventDeleted = Notification.Name("eventDeleted")
    static let navigateToEventFromNotification = Notification.Name("navigateToEventFromNotification")
    static let showHostSheetFromNotification = Notification.Name("showHostSheetFromNotification")
    static let testNewEventBanner = Notification.Name("testNewEventBanner")
}


struct EventDetailView: View {
    @State var event: CrowdEvent
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = EventDetailViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showCancelConfirmation = false
    @State private var showNavigationModal = false
    @ObservedObject private var attendedEventsService = AttendedEventsService.shared
    @State private var liveAttendeeCount: Int = 0
    @State private var attendees: [UserProfile] = []
    @State private var eventListener: ListenerRegistration?
    @State private var isFollowingHost = false
    @State private var shareButtonScale: CGFloat = 0.9
    
    var currentUserName: String {
        appState.sessionUser?.displayName ?? "You"
    }
    
    var isHost: Bool {
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId() else {
            return false
        }
        return event.hostId == currentUserId
    }
    
    var emoji: String { TagEmoji.emoji(for: event.tags, fallbackCategory: event.category) }
    
    var hasJoined: Bool {
        attendedEventsService.isAttendingEvent(event.id)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header: Compact (one row) or expanded (title below) based on title length
                        ViewThatFits(in: .horizontal) {
                            // Compact: Everything on one row
                            headerRow(includeTitle: true)
                            
                            // Expanded: Title moves below
                            VStack(spacing: 12) {
                                headerRow(includeTitle: false)
                                
                                HStack(spacing: 8) {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                    Text(event.title)
                                        .font(.system(size: 22, weight: .bold))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 32)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Event details
                    VStack(spacing: 20) {
                        // People here now (centered)
                        VStack(spacing: 8) {
                            Text("People here now")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            CrowdAvatarGroup(
                                members: attendees.map {
                                    Member(
                                        id: $0.id,
                                        imageURL: $0.profileImageURL,
                                        initials: String($0.displayName.prefix(2)).uppercased()
                                    )
                                },
                                totalCount: liveAttendeeCount
                            )
                        }
                        
                        // Time
                        if let start = event.startsAt, let end = event.endsAt {
                            VStack(spacing: 8) {
                                Text("Time")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(formatTimeWithContext(start: start, end: end))
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Location
                        VStack(spacing: 8) {
                            Text("Location")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Group {
                                if let raw = event.rawLocationName, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(raw)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                } else if let closestName = findClosestLocationName(for: event.coordinates) {
                                    Text(closestName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        // Description - only show if user added one during creation
                        if let description = event.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(spacing: 8) {
                                Text("Description")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                
                                Text(description)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 5)
                            }
                        }
                        
                        // Vibe Chips - "Perfect for" section
                        let chips = generateVibeChips(
                            tags: event.tags,
                            title: event.title,
                            description: event.description
                        )
                        if !chips.isEmpty {
                            VStack(alignment: .center, spacing: 6) {
                                Text("Perfect for")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 8) {
                                    ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                                        SUBadge(model: BadgeVM {
                                            $0.title = chip
                                            $0.color = vibeChipColor(for: index)
                                            $0.style = .light
                                            $0.font = .smButton
                                            $0.cornerRadius = .full
                                            $0.paddings = .init(horizontal: 10, vertical: 6)
                                        })
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            
            // Action buttons
            VStack(spacing: 10) {
                // Value statement - only show when not joined
                if !hasJoined {
                    Text("Join to see who's here and drop a message.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if hasJoined {
                    // Leave button (red)
                    Button {
                        leaveEvent()
                    } label: {
                        Text("Leave")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                }
                
                // Join/Joined button
                Button {
                    if hasJoined {
                        // Already joined - open navigation modal
                        showNavigationModal = true
                    } else {
                        // Prepare haptic for instant feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        
                        Task {
                            // Check if this is the first event join (before leaving any previous event)
                            let wasFirstEvent = AttendedEventsService.shared.getAttendedEvents().isEmpty
                            
                            // Leave previous event if user is already in one
                            let attendedEvents = AttendedEventsService.shared.getAttendedEvents()
                            if let previousEvent = attendedEvents.first(where: { $0.id != event.id }) {
                                print("🔄 Leaving previous event before joining new one: \(previousEvent.id)")
                                await viewModel.leaveEvent(event: previousEvent)
                                
                                // Clear currentJoinedEvent if it matches
                                await MainActor.run {
                                    if appState.currentJoinedEvent?.id == previousEvent.id {
                                        appState.currentJoinedEvent = nil
                                    }
                                }
                            }
                            
                            let success = await viewModel.joinEvent(event: event)
                            if success {
                                await MainActor.run {
                                    appState.currentJoinedEvent = event
                                    
                                    // Request app rating if this is the first event
                                    if wasFirstEvent {
                                        AppRatingService.shared.requestRatingIfNeeded(isFirstEvent: true)
                                    }
                                    
                                    showNavigationModal = true
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .controlSize(.small)
                        } else if hasJoined {
                            Text("Joined")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .semibold))
                        } else {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Join this Crowd")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x027838), Color(hex: 0x03A04E)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                }
                .disabled(viewModel.isJoining)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            }
        }
        .task {
            await viewModel.loadHostProfile(hostId: event.hostId)
            AnalyticsService.shared.trackScreenView("event_detail")
            if let fetched = try? await EventAttendeesService.shared.fetchAttendees(eventId: event.id) {
                attendees = fetched
            }
        }
        .onAppear {
            // Initialize with current event count
            liveAttendeeCount = event.attendeeCount
            startEventListener()
            
            // Check if following host
            isFollowingHost = FollowService.shared.isFollowing(hostId: event.hostId)
        }
        .onDisappear {
            eventListener?.remove()
            eventListener = nil
        }
        .alert("Error", isPresented: .constant(viewModel.joinError != nil)) {
            Button("OK") {
                viewModel.joinError = nil
            }
        } message: {
            Text(viewModel.joinError ?? "Unknown error")
        }
        .alert("Error", isPresented: .constant(viewModel.leaveError != nil)) {
            Button("OK") {
                viewModel.leaveError = nil
            }
        } message: {
            Text(viewModel.leaveError ?? "Unknown error")
        }
        .confirmationDialog("Cancel Crowd", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel Crowd", role: .destructive) {
                cancelEvent()
            }
            Button("Keep Crowd", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this crowd? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showNavigationModal) {
            EventNavigationModal(event: event)
        }
    }
    
    @ViewBuilder
    private func headerRow(includeTitle: Bool) -> some View {
        HStack(spacing: 12) {
            // Host avatar and info
            if viewModel.isLoadingHost {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 36, height: 36)
            } else {
                HStack(spacing: 8) {
                    HostAvatarView(host: viewModel.hostProfile, fallbackName: event.hostName)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hosted by")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(viewModel.hostProfile?.displayName ?? event.hostName)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                    }
                }
            }
            
            if includeTitle {
                Spacer(minLength: 8)
                
                HStack(spacing: 6) {
                    Text(emoji)
                        .font(.system(size: 28))
                    Text(event.title)
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 8)
            
            // Follow button (if not host)
            if !isHost && !viewModel.isLoadingHost {
                FollowButton(isFollowing: isFollowingHost) {
                    toggleFollowHost()
                }
            }
            
            // Moderation menu (if not host)
            if !isHost {
                EventModerationMenu(
                    event: event,
                    hostName: viewModel.hostProfile?.displayName ?? event.hostName
                )
            }
            
            // Share button
            Button(action: shareEvent) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(.systemGray6))
                    )
            }
            .scaleEffect(shareButtonScale)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    shareButtonScale = 1.0
                }
            }
            
            // X button (right of share) - only for hosts or joined users
            if isHost || hasJoined {
                Button {
                    if isHost {
                        showCancelConfirmation = true
                    } else {
                        leaveEvent()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color(.systemBackground)))
                }
            }
        }
    }
    
    private func eventShareURL() -> URL {
        let base = "https://crowdapp.io/event"
        return URL(string: "\(base)/\(event.id)")!
    }
    
    private func shareEvent() {
        let url = eventShareURL()
        let message = "Pull up: \(event.title) at \(event.rawLocationName ?? "campus") on Crowd."
        
        let items: [Any] = [message, url]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
    
    private func formatTimeWithContext(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        
        // Determine day prefix
        let dayPrefix: String
        if calendar.isDateInToday(start) {
            dayPrefix = "Today"
        } else if calendar.isDateInTomorrow(start) {
            dayPrefix = "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            dayPrefix = formatter.string(from: start)
        }
        
        // Format time based on minutes
        func formatTimeComponent(_ date: Date) -> String {
            let minute = calendar.component(.minute, from: date)
            let formatter = DateFormatter()
            formatter.dateFormat = minute == 0 ? "h a" : "h:mm a"
            return formatter.string(from: date)
        }
        
        return "\(dayPrefix) · \(formatTimeComponent(start)) – \(formatTimeComponent(end))"
    }
    
    private func generateVibeChips(tags: [String], title: String, description: String?) -> [String] {
        // Comprehensive tag-to-chips mapping
        let tagMapping: [String: [String]] = [
            // Study/Academic
            "study": ["Exam prep", "Quiet grind"],
            "academic": ["Exam prep", "Quiet grind"],
            "Study Sessions": ["Exam prep", "Quiet grind"],
            
            // Chill
            "chillHangout": ["Chill crowd", "Low-pressure hang"],
            "Chill Spots": ["Chill crowd", "Low-pressure hang"],
            
            // Party/Nightlife
            "party": ["Meet new people", "Late-night vibe"],
            "parties": ["Meet new people", "Late-night vibe"],
            "Parties": ["Meet new people", "Late-night vibe"],
            "Nightlife": ["Meet new people", "Late-night vibe"],
            
            // Sports
            "gym": ["Run it back", "Pickup runs"],
            "Gym Life": ["Run it back", "Pickup runs"],
            "Basketball": ["Run it back", "Pickup runs"],
            "Football": ["Run it back", "Pickup runs"],
            "Soccer": ["Run it back", "Pickup runs"],
            "Tennis": ["Run it back", "Pickup runs"],
            "Running": ["Run it back", "Pickup runs"],
            
            // Gaming
            "Gaming": ["Gamers welcome", "Squad up"],
            "Esports": ["Gamers welcome", "Squad up"],
            "Retro Games": ["Gamers welcome", "Squad up"],
            
            // Startups/Business
            "Startups": ["Builders & founders", "Talk ideas"],
            "Entrepreneurship": ["Builders & founders", "Talk ideas"],
            "Business": ["Builders & founders", "Talk ideas"],
            "Investing": ["Builders & founders", "Talk ideas"],
            
            // Tech
            "AI & Tech": ["Tech crowd", "Laptop gang"],
            "Coding": ["Tech crowd", "Laptop gang"],
            
            // Music/Arts
            "Music": ["Creative vibes", "Artists welcome"],
            "Singing": ["Creative vibes", "Artists welcome"],
            "Guitar": ["Creative vibes", "Artists welcome"],
            "Band Life": ["Creative vibes", "Artists welcome"],
            "Dance": ["Creative vibes", "Artists welcome"],
            "Theatre": ["Creative vibes", "Artists welcome"],
            "Art & Design": ["Creative vibes", "Artists welcome"],
            "Photography": ["Creative vibes", "Artists welcome"],
            "Filmmaking": ["Creative vibes", "Artists welcome"],
            "Writing": ["Creative vibes", "Artists welcome"],
            "Graphic Design": ["Creative vibes", "Artists welcome"],
            
            // Food/Coffee
            "Coffee Runs": ["Foodies unite", "Good eats"],
            "Foodie": ["Foodies unite", "Good eats"],
            "Late-Night Eats": ["Foodies unite", "Good eats"],
            "Cooking": ["Foodies unite", "Good eats"],
            
            // Outdoor/Adventure
            "Adventure": ["Adventure seekers", "Outdoor crew"],
            "Biking": ["Adventure seekers", "Outdoor crew"],
            "Travel": ["Adventure seekers", "Outdoor crew"],
            "Beach Days": ["Adventure seekers", "Outdoor crew"],
            "Camping": ["Adventure seekers", "Outdoor crew"],
            
            // Social/Media
            "Public Speaking": ["Content creators", "Networkers"],
            "Podcasts": ["Content creators", "Networkers"],
            "Social Media": ["Content creators", "Networkers"],
            "Campus News": ["Content creators", "Networkers"],
            "Campus Events": ["Content creators", "Networkers"],
            
            // Wellness
            "Wellness": ["Self-care crew", "Mindful vibes"],
            
            // Pets
            "Pets": ["Pet lovers", "Bring your furry friend"],
            
            // Dating/Social
            "Dating & Friends": ["Meet new people", "Chill hangout"],
            "social": ["Meet new people", "Chill hangout"],
            
            // Culture/Sustainability
            "Culture": ["Culture enthusiasts", "Expand your horizons"],
            "Sustainability": ["Eco-conscious crew", "Green vibes"],
            "Science": ["Curious minds", "Learn something new"]
        ]
        
        // All InterestsView titles for direct pass-through
        let interestTitles: Set<String> = [
            "Gaming", "Basketball", "Soccer", "Tennis", "Football", "Wellness",
            "Music", "Singing", "Guitar", "Band Life", "Dance", "Theatre",
            "Art & Design", "Photography", "Filmmaking", "Coding", "AI & Tech",
            "Science", "Study Sessions", "Coffee Runs", "Foodie", "Late-Night Eats",
            "Gym Life", "Running", "Adventure", "Biking", "Travel", "Beach Days",
            "Camping", "Chill Spots", "Parties", "Esports", "Startups",
            "Entrepreneurship", "Business", "Investing", "Public Speaking",
            "Podcasts", "Campus News", "Social Media", "Retro Games", "Cooking",
            "Pets", "Nightlife", "Dating & Friends", "Writing", "Graphic Design",
            "Culture", "Sustainability", "Campus Events"
        ]
        
        var chips: [String] = []
        var addedChipSets: Set<String> = [] // Track which chip sets we've added to avoid duplicates
        
        for tag in tags {
            // Check if tag is in mapping
            if let mappedChips = tagMapping[tag] {
                let chipSetKey = mappedChips.joined(separator: "|")
                if !addedChipSets.contains(chipSetKey) {
                    chips.append(contentsOf: mappedChips)
                    addedChipSets.insert(chipSetKey)
                }
            } else if interestTitles.contains(tag) {
                // If tag matches an InterestsView title exactly but isn't in dictionary, use it directly
                if !chips.contains(tag) {
                    chips.append(tag)
                }
            }
            
            // Stop if we have enough chips
            if chips.count >= 3 {
                break
            }
        }
        
        // If chips from tags are less than 3, derive more from title/description
        if chips.count < 3 {
            let titleLower = title.lowercased()
            let descLower = (description ?? "").lowercased()
            let combined = titleLower + " " + descLower
            
            if chips.count < 3 && (combined.contains("csci") || combined.contains("computer science")) {
                chips.append("For CSCI majors")
            }
            if chips.count < 3 && (combined.contains("review") || combined.contains("midterm") || combined.contains("final")) {
                chips.append("Midterm prep")
            }
            if chips.count < 3 && (combined.contains("workout") || combined.contains("lift")) {
                chips.append("Fitness crew")
            }
        }
        
        // Generic fallbacks to ensure minimum 3 chips
        let genericFallbacks = ["Chill crowd", "Good vibes", "All welcome"]
        var fallbackIndex = 0
        while chips.count < 3 && fallbackIndex < genericFallbacks.count {
            if !chips.contains(genericFallbacks[fallbackIndex]) {
                chips.append(genericFallbacks[fallbackIndex])
            }
            fallbackIndex += 1
        }
        
        return Array(chips.prefix(3))
    }
    
    private func vibeChipColor(for index: Int) -> ComponentColor {
        let colors: [ComponentColor] = [.success, .accent, .warning]
        return colors[index % colors.count]
    }
    
    private func leaveEvent() {
        Task {
            let success = await viewModel.leaveEvent(event: event)
            if success {
                // Clear currentJoinedEvent if it matches
                if appState.currentJoinedEvent?.id == event.id {
                    appState.currentJoinedEvent = nil
                }
            }
        }
    }
    
    private func toggleFollowHost() {
        if isFollowingHost {
            FollowService.shared.unfollow(hostId: event.hostId)
            NotificationService.shared.unsubscribeFromHost(hostId: event.hostId)
        } else {
            FollowService.shared.follow(hostId: event.hostId)
            NotificationService.shared.subscribeToHost(hostId: event.hostId)
        }
        isFollowingHost.toggle()
    }
    
    private func cancelEvent() {
        // Get current user ID with detailed logging
        let currentUserId = FirebaseManager.shared.getCurrentUserId()
        print("🔍 Delete Event Debug:")
        print("   - Current User ID: \(currentUserId ?? "nil")")
        print("   - Event Host ID: \(event.hostId)")
        print("   - Event ID: \(event.id)")
        print("   - User authenticated: \(currentUserId != nil)")
        
        // Verify user is authenticated
        guard let currentUserId = currentUserId else {
            print("❌ User not authenticated - cannot delete event")
            // TODO: Show user-friendly error message
            return
        }
        
        // Verify user is the host
        guard currentUserId == event.hostId else {
            print("❌ User (\(currentUserId)) is not the host (\(event.hostId)) - cannot delete event")
            // TODO: Show user-friendly error message
            return
        }
        
        print("✅ User is authenticated and is the host - proceeding with deletion")
        
        Task {
            do {
                try await AppEnvironment.current.eventRepo.deleteEvent(eventId: event.id)
                
                // Track analytics
                AnalyticsService.shared.trackEventDeleted(eventId: event.id)
                
                print("✅ Event deleted: \(event.id)")
                
                // Post notification to remove from hostedEvents array
                NotificationCenter.default.post(name: .eventDeleted, object: event.id)
                
                await MainActor.run {
                    // Clear currentJoinedEvent if it matches the cancelled event
                    if appState.currentJoinedEvent?.id == event.id {
                        appState.currentJoinedEvent = nil
                    }
                    dismiss()
                }
            } catch {
                print("❌ Failed to delete event: \(error)")
                // TODO: Show user-friendly error message
            }
        }
    }
    
    // MARK: - Event Listener
    
    private func startEventListener() {
        let db = FirebaseManager.shared.db
        
        // Try events collection first
        let eventRef = db.collection("events").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ EventDetailSheet: Error listening to event: \(error)")
                    // Try userEvents collection as fallback
                    tryUserEventsListener()
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                    print("📊 EventDetailSheet: Updated attendee count to \(attendeeCount)")
                } else if !(snapshot?.exists ?? false) {
                    // Document doesn't exist in events, try userEvents
                    tryUserEventsListener()
                }
            }
        }
    }
    
    private func tryUserEventsListener() {
        let db = FirebaseManager.shared.db
        eventListener?.remove()
        
        let eventRef = db.collection("userEvents").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ EventDetailSheet: Error listening to userEvent: \(error)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                    print("📊 EventDetailSheet: Updated attendee count to \(attendeeCount)")
                }
            }
        }
    }
}


struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Follow Button

struct FollowButton: View {
    let isFollowing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 13, weight: .semibold))
                if isFollowing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(isFollowing ? Color(hex: 0xD4A017) : Color(hex: 0x02853E))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isFollowing ? Color(hex: 0xD4A017).opacity(0.15) : Color(hex: 0x02853E).opacity(0.15))
            )
        }
    }
}

// MARK: - Host Avatar View

struct HostAvatarView: View {
    let host: UserProfile?
    let fallbackName: String
    
    private var initials: String {
        let name = host?.displayName ?? fallbackName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    private var avatarColor: Color {
        host?.avatarColor ?? Color.gray
    }
    
    var body: some View {
        if let imageURL = host?.profileImageURL, !imageURL.isEmpty {
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                initialsView
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            initialsView
        }
    }
    
    private var initialsView: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 36, height: 36)
            .overlay(
                Text(initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Preview
#Preview {
    EventDetailView(event: CrowdEvent(
        id: "preview-event-1",
        title: "Study Session",
        hostId: "preview-host-123",
        hostName: "Alex Johnson",
        latitude: 33.2099,
        longitude: -97.1515,
        radiusMeters: 60,
        startsAt: Date().addingTimeInterval(3600),
        endsAt: Date().addingTimeInterval(7200),
        createdAt: Date(),
        signalStrength: 4,
        attendeeCount: 8,
        tags: ["study", "academic"],
        category: EventCategory.studySession.rawValue,
        description: "Come join us for a productive study session!",
        rawLocationName: "Willis Library"
    ))
    .environmentObject(AppState())
}
