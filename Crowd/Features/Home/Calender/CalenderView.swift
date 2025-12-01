//
//  CalenderView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI
import CoreLocation
import FirebaseFunctions
import FirebaseFirestore
import MapKit

struct CalenderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var campusEventsVM = CampusEventsViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategories: Set<EventCategory> = []
    @State private var displayedEventCount = 10
    @State private var selectedTab: TabSelection = .parties
    private let eventsPerPage = 10
    
    enum TabSelection {
        case parties
        case schoolEvents
    }
    
    @State private var blockedUserIds: Set<String> = []
    @State private var hiddenEventIds: Set<String> = []
    @State private var bannedUserIds: Set<String> = []
    
    // Filtered events based on selected categories
    var filteredEvents: [CrowdEvent] {
        var events = campusEventsVM.crowdEvents
        
        // Apply category filter
        if !selectedCategories.isEmpty {
            events = events.filter { event in
                selectedCategories.contains { category in
                    category.matchesTags(event.tags)
                }
            }
        }
        
        // Apply moderation filters
        return events.filter { event in
            !ContentModerationService.shared.shouldFilterEvent(
                event,
                blockedUserIds: blockedUserIds,
                hiddenEventIds: hiddenEventIds,
                bannedUserIds: bannedUserIds
            )
        }
    }
    
    // Upcoming events sorted by soonest start time
    var upcomingEvents: [CrowdEvent] {
        filteredEvents.sorted { (a, b) in
            let aStart = a.startsAt ?? .distantFuture
            let bStart = b.startsAt ?? .distantFuture
            return aStart < bStart
        }
    }

    // Paginated events for display
    var displayedEvents: [CrowdEvent] {
        Array(upcomingEvents.prefix(displayedEventCount))
    }
    
    var hasMoreEvents: Bool {
        displayedEventCount < filteredEvents.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(selectedTab == .schoolEvents ? "School Events" : "Parties")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.primary)
                                if selectedTab == .parties {
                                    Text("🎉")
                                        .font(.system(size: 24))
                                }
                            }
                            
                            if selectedTab == .schoolEvents {
                                Text("\(displayedEvents.count) of \(filteredEvents.count) events")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedTab == .schoolEvents {
                            CategoryFilterDropdown(selectedCategories: $selectedCategories)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                
                // Tab SwitcherP
                HStack(spacing: 0) {
                    CalendarTabButton(
                        title: "Parties",
                        isSelected: selectedTab == .parties,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = .parties
                            }
                        }
                    )
                    
                    CalendarTabButton(
                        title: "School Events",
                        isSelected: selectedTab == .schoolEvents,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = .schoolEvents
                            }
                        }
                    )
                }
                .frame(height: 48)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Tab Content
                Group {
                    if selectedTab == .parties {
                        PartiesView()
                    } else {
                        SchoolEventsView(
                            filteredEvents: filteredEvents,
                            displayedEvents: displayedEvents,
                            hasMoreEvents: hasMoreEvents,
                            selectedCategories: selectedCategories,
                            displayedEventCount: $displayedEventCount,
                            eventsPerPage: eventsPerPage
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await loadModerationData()
            }
            .onAppear {
                // Fetch fresh data each time calendar opens, then set up live updates
                Task {
                    // Always fetch fresh data when calendar opens
                    await campusEventsVM.fetchOnce(limit: 25)
                    campusEventsVM.start()
                    await geocodeTodaysEventsIfNeeded()
                }
                // Refresh attended events to clean up expired ones
                AttendedEventsService.shared.refreshAttendedEvents()
            }
            .onDisappear { campusEventsVM.stop() }
            .onReceive(NotificationCenter.default.publisher(for: .userBlocked)) { _ in
                Task {
                    await loadModerationData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .eventHidden)) { _ in
                Task {
                    await loadModerationData()
                }
            }
            .onChange(of: selectedCategories) { _, _ in
                // Reset pagination when filter changes
                displayedEventCount = eventsPerPage
            }
        }
    }

    // MARK: - Backend geocoding for today's events only
    private func geocodeTodaysEventsIfNeeded() async {
        let functions = Functions.functions()
        let calendar = Calendar.current
        let todays = campusEventsVM.crowdEvents.filter { ev in
            guard let s = ev.startsAt else { return false }
            return calendar.isDateInToday(s)
        }
        for ev in todays {
            do {
                _ = try await functions.httpsCallable("geocodeEventIfNeeded").call(["id": ev.id])
            } catch {
                print("❌ geocodeEventIfNeeded failed for \(ev.id): \(error)")
            }
        }
    }
    
    // MARK: - Moderation Data Loading
    
    private func loadModerationData() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        
        do {
            async let blocked = ContentModerationService.shared.getBlockedUsers(userId: userId)
            async let hidden = ContentModerationService.shared.getHiddenEvents(userId: userId)
            async let banned = ContentModerationService.shared.getBannedUsers()
            
            let (blockedResult, hiddenResult, bannedResult) = try await (blocked, hidden, banned)
            
            await MainActor.run {
                blockedUserIds = blockedResult
                hiddenEventIds = hiddenResult
                bannedUserIds = bannedResult
            }
        } catch {
            print("⚠️ Failed to load moderation data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Calendar Tab Button
struct CalendarTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    isSelected
                    ? Color.primary.opacity(0.1)
                    : Color.clear
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - Event Card View
struct EventCardView: View {
    let event: CrowdEvent
    @State private var isAttending = false
    @State private var isExpanded = false
    @State private var showEventURL = false
    private let emoji: String
    
    init(event: CrowdEvent) {
        self.event = event
        self.emoji = Self.getEventEmoji(for: event.tags)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let sourceURL = event.sourceURL {
                        Button(action: {
                            if let url = URL(string: sourceURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text(emoji)
                                .font(.system(size: 24))
                        }
                    } else {
                        Text(emoji)
                            .font(.system(size: 24))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    if let description = event.description {
                        let lines = description.components(separatedBy: "\n")
                        if let first = lines.first {
                            Text(first)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let startsAt = event.startsAt {
                            let endText = event.endsAt.map { " – " + formatEventTime($0) } ?? ""
                            Text(formatEventTime(startsAt) + endText)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        if isExpanded && lines.count > 2 {
                            Text(lines.dropFirst(2).joined(separator: "\n"))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                
                Spacer()
            }
            
            if isExpanded && showEventURL {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        Text("Event Link")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Button("Open") {
                            if let src = event.sourceURL, let url = URL(string: src) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                    }
                }
            }
            
            HStack {
                if let sourceURL = event.sourceURL {
                    Button(action: {
                        if let url = URL(string: sourceURL) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("More Info")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor)
                            )
                    }
                }
                
                Spacer()
                
                Button(action: {
                    shareEvent()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.black)
                        )
                }
                
                Button(action: {
                    Task {
                        if !isAttending {
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAttending = true
                                    AttendedEventsService.shared.addAttendedEvent(event)
                                }
                            }
                        } else {
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAttending = false
                                    AttendedEventsService.shared.removeAttendedEvent(event.id)
                                }
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isAttending ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(isAttending ? "Attending" : "I'm Attending")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isAttending ? .white : .accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isAttending ? Color.accentColor : Color.accentColor.opacity(0.1))
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            isAttending = AttendedEventsService.shared.isAttendingEvent(event.id)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private func shareEvent() {
        AnalyticsService.shared.track("invite_sent", props: [
            "event_id": event.id,
            "title": event.title
        ])
        let coordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
        let zone = coordinate.geohash(precision: 4)
        AnalyticsService.shared.logToFirestore(
            eventName: "invite_sent",
            properties: [
                "event_id": event.id,
                "title": event.title
            ],
            zone: zone
        )
        
        var shareItems: [Any] = []
        shareItems.append(event.title)
        
        if let description = event.description {
            shareItems.append(description)
        }
        
        if let startsAt = event.startsAt {
            shareItems.append("Time: \(formatEventTime(startsAt))")
        }
        
        if let sourceURL = event.sourceURL {
            shareItems.append(sourceURL)
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            topController.present(activityViewController, animated: true)
        }
    }
    
    private static let tagEmojis: [String: String] = [
        "music": "🎵", "concert": "🎤", "party": "🎉", "festival": "🎪", "dance": "💃",
        "dancing": "💃", "live": "🎵", "performance": "🎭",
        "food": "🍕", "dining": "🍽️", "restaurant": "🍽️", "cafe": "☕", "coffee": "☕",
        "lunch": "🍽️", "dinner": "🍽️", "breakfast": "🥞", "snack": "🍿",
        "sports": "⚽", "basketball": "🏀", "football": "🏈", "soccer": "⚽", "tennis": "🎾",
        "volleyball": "🏐", "baseball": "⚾", "fitness": "💪", "gym": "💪", "workout": "💪",
        "yoga": "🧘", "running": "🏃", "cycling": "🚴",
        "study": "📚", "academic": "🎓", "lecture": "🎓", "workshop": "🔧", "seminar": "🎓",
        "conference": "🎓", "education": "🎓", "learning": "📚", "research": "🔬", "science": "🔬",
        "tech": "💻", "technology": "💻", "coding": "💻", "programming": "💻",
        "art": "🎨", "creative": "🎨", "culture": "🌍", "cultural": "🌍", "international": "🌍",
        "language": "🗣️", "film": "🎬", "movie": "🎬", "theater": "🎭", "drama": "🎭",
        "comedy": "😂", "standup": "🎤", "photography": "📸", "gallery": "🖼️",
        "networking": "🤝", "meetup": "👥", "community": "🏘️", "volunteer": "🤝", "charity": "❤️",
        "fundraising": "💰", "career": "💼", "job": "💼", "business": "💼", "entrepreneur": "🚀",
        "startup": "🚀",
        "health": "🏥", "wellness": "💚", "mental": "🧠", "spiritual": "🙏", "religious": "⛪",
        "faith": "⛪", "meditation": "🧘", "mindfulness": "🧘",
        "outdoor": "🏔️", "hiking": "🥾", "camping": "⛺", "nature": "🌿", "environment": "🌱",
        "sustainability": "🌱", "travel": "✈️", "adventure": "🗺️",
        "gaming": "🎮", "esports": "🎮", "board": "🎲", "trivia": "🧠", "puzzle": "🧩", "card": "🃏",
        "fashion": "👗", "beauty": "💄", "cooking": "👨‍🍳", "baking": "🧁", "wine": "🍷",
        "beer": "🍺", "tea": "🍵", "book": "📖", "reading": "📖", "writing": "✍️",
        "poetry": "📝", "blog": "✍️",
        "politics": "🏛️", "debate": "🗣️", "activism": "✊", "protest": "✊", "voting": "🗳️",
        "election": "🗳️",
        "graduation": "🎓", "celebration": "🎉", "anniversary": "🎂", "birthday": "🎂",
        "holiday": "🎄", "christmas": "🎄", "halloween": "🎃", "valentine": "💕", "newyear": "🎊",
        "official": "🏛️", "student": "🎓", "instagram": "📸", "social": "👥"
    ]
    
    private static func getEventEmoji(for tags: [String]) -> String {
        for tag in tags {
            let lowercaseTag = tag.lowercased()
            if let emoji = tagEmojis[lowercaseTag] {
                return emoji
            }
        }
        
        if let firstTag = tags.first {
            let lowercaseTag = firstTag.lowercased()
            for (keyword, emoji) in tagEmojis where lowercaseTag.contains(keyword) {
                return emoji
            }
        }
        
        return "📅"
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func formatEventTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today \(Self.timeFormatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(Self.timeFormatter.string(from: date))"
        } else {
            return Self.dateTimeFormatter.string(from: date)
        }
    }
}

// MARK: - School Events View
struct SchoolEventsView: View {
    let filteredEvents: [CrowdEvent]
    let displayedEvents: [CrowdEvent]
    let hasMoreEvents: Bool
    let selectedCategories: Set<EventCategory>
    @Binding var displayedEventCount: Int
    let eventsPerPage: Int
    
    var body: some View {
        if filteredEvents.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.gray.opacity(0.5))
                
                Text(selectedCategories.isEmpty ? "No upcoming events" : "No events match selected categories")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(selectedCategories.isEmpty ? "Check back later for new campus events" : "Try selecting different categories or clear the filter")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 60)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(displayedEvents) { event in
                        EventCardView(event: event)
                    }
                    
                    // Load more button
                    if hasMoreEvents {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                displayedEventCount += eventsPerPage
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16))
                                Text("Load More Events")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.accentColor)
                            )
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
}

// MARK: - Parties View
struct PartiesView: View {
    @Environment(\.appEnvironment) var env
    @State private var parties: [CrowdEvent] = []
    @State private var isLoading = false
    @State private var selectedParty: CrowdEvent? = nil
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading parties...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else if parties.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray.opacity(0.5))
                    
                    Text("No Parties Available")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Check back later for exciting party events!")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(parties) { party in
                            Button(action: {
                                print("🎉 Party card tapped: \(party.title)")
                                selectedParty = party
                            }) {
                                PartyCardView(party: party)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .onAppear {
            Task {
                await loadParties()
            }
        }
        .fullScreenCover(item: $selectedParty) { party in
            PartyDetailView(party: party)
        }
        .onChange(of: selectedParty) { oldValue, newValue in
            if newValue != nil {
                print("🎉 Selected party changed: \(newValue?.title ?? "nil")")
            }
        }
    }
    
    private func loadParties() async {
        // Set loading state
        await MainActor.run {
            isLoading = true
        }
        
        // Ensure we have a Firebase repository
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Event repository is not FirebaseEventRepository")
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // Fetch parties from Firebase
        do {
            print("🎉 Starting party fetch...")
            let fetchedParties = try await firebaseRepo.fetchParties()
            print("✅ Successfully fetched \(fetchedParties.count) parties")
            
            // Sort parties by date (soonest first)
            let sortedParties = fetchedParties.sorted { party1, party2 in
                guard let date1 = party1.startsAt else { return false }
                guard let date2 = party2.startsAt else { return true }
                return date1 < date2
            }
            
            // Update UI on main thread
            await MainActor.run {
                parties = sortedParties
                isLoading = false
            }
        } catch {
            print("❌ Failed to load parties: \(error.localizedDescription)")
            await MainActor.run {
                parties = []
                isLoading = false
            }
        }
    }
}

// MARK: - Party Card View
struct PartyCardView: View {
    let party: CrowdEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title + Host Name (biggest)
            VStack(alignment: .leading, spacing: 4) {
                Text(party.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if !party.hostName.isEmpty && party.hostName != "Party Host" {
                    Text(party.hostName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Time with emoji
            if let startsAt = party.startsAt {
                HStack(spacing: 6) {
                    Text("📅")
                        .font(.system(size: 14))
                    Text(formatEventTime(startsAt))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Address with emoji
            if let address = party.rawLocationName, !address.isEmpty {
                HStack(spacing: 6) {
                    Text("📍")
                        .font(.system(size: 14))
                    Text(address)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Going count badge
            if party.attendeeCount > 0 {
                HStack(spacing: 4) {
                    Text("\(party.attendeeCount >= 50 ? "50+" : "\(party.attendeeCount)")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("going")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Buy Ticket Button
            if let ticketURL = party.ticketURL {
                Button(action: {
                    if let url = URL(string: ticketURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 14))
                        Text("Buy Ticket")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatEventTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if calendar.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
        }
    }
}

// MARK: - Party Detail View
struct PartyDetailView: View {
    let party: CrowdEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) var env
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var isAttending = false
    @State private var isJoining = false
    @State private var loadedParty: CrowdEvent?
    @State private var isLoadingParty = false
    @State private var goingCount: Int = 0
    @State private var goingCountListener: ListenerRegistration?
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if isLoadingParty {
                ProgressView("Loading party details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let displayParty = loadedParty ?? party
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Party Image - Full Width
                        if let imageURL = displayParty.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 400)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 400)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 400)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.gray)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 400)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.gray)
                            )
                    }
                    
                    // Content Section
                    VStack(alignment: .leading, spacing: 20) {
                        // Title + Hosted by
                        VStack(alignment: .leading, spacing: 12) {
                            // Title only (largest)
                            Text(displayParty.title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            // Hosted by with label
                            if !displayParty.hostName.isEmpty && displayParty.hostName != "Party Host" {
                                HStack(spacing: 4) {
                                    Text("Hosted by:")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(displayParty.hostName)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Description
                        if let description = displayParty.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .padding(.top, 8)
                        }
                        
                        // Date
                        if let startsAt = displayParty.startsAt {
                            HStack(spacing: 4) {
                                Text("Date:")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("📅")
                                    .font(.system(size: 18))
                                Text(formatFullDate(startsAt))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        // Location - Clickable to open Maps
                        if let location = displayParty.rawLocationName, !location.isEmpty {
                            HStack(spacing: 4) {
                                Text("Location:")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Button(action: {
                                    openLocationInMaps(address: location, coordinate: displayParty.coordinates)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(location)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.blue)
                                            .underline()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            // Buy Tickets Button (Primary)
                            if let ticketURL = displayParty.ticketURL {
                                Button(action: {
                                    if let url = URL(string: ticketURL) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "ticket.fill")
                                            .font(.system(size: 18))
                                        Text("Buy Tickets")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.black)
                                    )
                                }
                            }
                            
                            // I'm Going Button with count
                            Button(action: {
                                Task {
                                    await toggleGoing(party: displayParty)
                                }
                            }) {
                                HStack {
                                    if isJoining {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: isAttending ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                                            .font(.system(size: 18))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(isAttending ? "Going" : "I'm Going")
                                                .font(.system(size: 17, weight: .semibold))
                                            if goingCount > 0 {
                                                Text("\(goingCount >= 50 ? "50+" : "\(goingCount)") going")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .opacity(0.9)
                                            }
                                        }
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isAttending ? Color.green : Color.accentColor)
                                )
                            }
                            .disabled(isJoining)
                            
                            // Share Button - Shares ticket URL
                            if let ticketURL = displayParty.ticketURL {
                                Button(action: {
                                    shareTicketURL(ticketURL: ticketURL, partyTitle: displayParty.title)
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 18))
                                        Text("Share")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(.systemGray6))
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                }
            }
            
            // Close Button - Floating at top
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.black.opacity(0.3)).frame(width: 36, height: 36))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                await loadPartyDetails()
            }
            setupGoingCountListener()
        }
        .onDisappear {
            goingCountListener?.remove()
            goingCountListener = nil
        }
    }
    
    private func loadPartyDetails() async {
        // Set loading state
        await MainActor.run {
            isLoadingParty = true
        }
        
        // Ensure we have a Firebase repository
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Event repository is not FirebaseEventRepository")
            await MainActor.run {
                loadedParty = party
                isLoadingParty = false
            }
            return
        }
        
        // Get current user ID
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ No authenticated user found")
            await MainActor.run {
                loadedParty = party
                isLoadingParty = false
            }
            return
        }
        
        do {
            print("🎉 Loading party details for: \(party.id)")
            
            // Fetch party data in parallel for better performance
            async let goingCountTask = firebaseRepo.getPartyGoingCount(partyId: party.id)
            async let isGoingTask = firebaseRepo.isUserGoingToParty(partyId: party.id, userId: userId)
            
            // Wait for both results
            let (fetchedGoingCount, fetchedIsGoing) = try await (goingCountTask, isGoingTask)
            
            print("✅ Party details loaded - Going: \(fetchedGoingCount), User attending: \(fetchedIsGoing)")
            
            // Create updated party with fresh data
            var updatedParty = party
            updatedParty.attendeeCount = fetchedGoingCount
            
            // Update UI on main thread
            await MainActor.run {
                loadedParty = updatedParty
                isAttending = fetchedIsGoing
                goingCount = fetchedGoingCount
                isLoadingParty = false
            }
        } catch {
            print("❌ Failed to load party details: \(error.localizedDescription)")
            
            // Fallback to original party data
            await MainActor.run {
                loadedParty = party
                goingCount = party.attendeeCount
                isAttending = false
                isLoadingParty = false
            }
        }
    }
    
    private func setupGoingCountListener() {
        // Ensure we have a Firebase repository
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Cannot setup listener - Event repository is not FirebaseEventRepository")
            return
        }
        
        // Remove existing listener if any to prevent duplicates
        goingCountListener?.remove()
        goingCountListener = nil
        
        print("🎉 Setting up real-time listener for party: \(party.id)")
        
        // Set up real-time listener for going count changes
        goingCountListener = firebaseRepo.listenToPartyGoingCount(partyId: party.id) { count in
            print("🔄 Party going count updated: \(count)")
            
            // Update state on main thread
            Task { @MainActor in
                goingCount = count
                
                // Update loaded party with new count
                if var updatedParty = loadedParty {
                    updatedParty.attendeeCount = count
                    loadedParty = updatedParty
                }
            }
        }
    }
    
    private func openLocationInMaps(address: String, coordinate: CLLocationCoordinate2D) {
        // Try to use coordinates if available, otherwise use address string
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = address
        
        // Open in Apple Maps
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func saveEventToProfile(eventId: String, userId: String) async throws {
        // Fetch current profile to get existing eventStatus
        let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
        var currentEventStatus = profile.eventStatus ?? []
        
        // Add event ID if not already present
        if !currentEventStatus.contains(eventId) {
            currentEventStatus.append(eventId)
            
            // Update profile with new event status
            try await UserProfileService.shared.updateProfile(userId: userId, updates: [
                "eventStatus": currentEventStatus
            ])
            
            print("✅ Saved event \(eventId) to user profile event status")
        }
    }
    
    private func removeEventFromProfile(eventId: String, userId: String) async throws {
        // Fetch current profile to get existing eventStatus
        let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
        var currentEventStatus = profile.eventStatus ?? []
        
        // Remove event ID if present
        if currentEventStatus.contains(eventId) {
            currentEventStatus.removeAll { $0 == eventId }
            
            // Update profile with updated event status (empty array is fine, keeps the field)
            try await UserProfileService.shared.updateProfile(userId: userId, updates: [
                "eventStatus": currentEventStatus
            ])
            
            print("✅ Removed event \(eventId) from user profile event status")
        }
    }
    
    private func toggleGoing(party: CrowdEvent) async {
        // Get current user ID
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ Cannot toggle going - No authenticated user")
            return
        }
        
        // Ensure we have a Firebase repository
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Cannot toggle going - Event repository is not FirebaseEventRepository")
            return
        }
        
        // Set loading state
        await MainActor.run {
            isJoining = true
        }
        
        // Save current state for rollback if needed
        let previousState = isAttending
        
        do {
            if isAttending {
                print("🎉 Unmarking party as going: \(party.id)")
                
                // Unmark going
                try await firebaseRepo.unmarkPartyGoing(partyId: party.id, userId: userId)
                
                // Remove from user profile event status
                try await removeEventFromProfile(eventId: party.id, userId: userId)
                
                print("✅ Successfully unmarked party as going and removed from profile")
                
                // Update UI
                await MainActor.run {
                    isAttending = false
                    isJoining = false
                }
            } else {
                print("🎉 Marking party as going: \(party.id)")
                
                // Mark going
                try await firebaseRepo.markPartyGoing(partyId: party.id, userId: userId)
                
                // Save to user profile event status
                try await saveEventToProfile(eventId: party.id, userId: userId)
                
                print("✅ Successfully marked party as going and saved to profile")
                
                // Update UI
                await MainActor.run {
                    isAttending = true
                    isJoining = false
                }
            }
        } catch {
            print("❌ Failed to toggle going: \(error.localizedDescription)")
            
            // Rollback to previous state on error
            await MainActor.run {
                isAttending = previousState
                isJoining = false
            }
        }
    }
    
    private func formatEventTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if calendar.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMM d, yyyy"
        return formatter.string(from: date)
        // Returns: "Saturday Nov 15, 2025"
    }
    
    private func shareTicketURL(ticketURL: String, partyTitle: String) {
        // Track share analytics
        AnalyticsService.shared.track("party_ticket_shared", props: [
            "party_id": party.id,
            "title": partyTitle
        ])
        
        // Create share text with ticket URL
        var shareText = "🎉 \(partyTitle)\n\n"
        shareText += "Get tickets: \(ticketURL)"
        
        var shareItems: [Any] = [shareText]
        
        // Add ticket URL
        if let url = URL(string: ticketURL) {
            shareItems.append(url)
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Present the activity view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(activityViewController, animated: true)
        }
    }
}

#Preview {
    CalenderView()
}
