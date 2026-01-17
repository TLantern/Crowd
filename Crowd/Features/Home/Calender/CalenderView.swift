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
    @ObservedObject private var campusEventsVM = CampusEventsViewModel.shared
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
    @State private var showEventCreationFlow = false
    @State private var currentPartyImageURLs: [String] = []
    @State private var currentPartyIndices: [Int] = []
    @State private var currentSchoolEventImageURL: String?
    
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
            let aStart = a.time ?? .distantFuture
            let bStart = b.time ?? .distantFuture
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

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                
                HStack(spacing: 12) {
                    VStack(alignment: .center, spacing: 6) {
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = .parties
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Text("Parties")
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedTab == .parties ? .white : .white.opacity(0.3))
                                    
                                    ZStack {
                                        if selectedTab == .parties {
                                            Capsule()
                                                .fill(.white)
                                                .frame(width: 22, height: 3)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = .schoolEvents
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text("School Events")
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedTab == .schoolEvents ? .white : .white.opacity(0.3))
                                    
                                    ZStack {
                                        if selectedTab == .schoolEvents {
                                            Capsule()
                                                .fill(.white)
                                                .frame(width: 22, height: 3)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if selectedTab == .schoolEvents {
                            Text("\(filteredEvents.count) events")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.top, 5)
        .padding(.horizontal, 20)
    }
    
    private var tabContent: some View {
        Group {
            if selectedTab == .parties {
                PartiesView(
                    currentPartyImageURLs: $currentPartyImageURLs,
                    currentPartyIndices: $currentPartyIndices
                )
            } else {
                VStack(spacing: 0) {
                    if selectedTab == .schoolEvents {
                        CategoryFilterDropdown(selectedCategories: $selectedCategories)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                    }
                SchoolEventsView(
                    filteredEvents: filteredEvents,
                    selectedCategories: selectedCategories,
                    currentSchoolEventImageURL: $currentSchoolEventImageURL
                )
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Blurred background image - full page (for both parties and school events tabs)
                GeometryReader { geometry in
                    ZStack {
                        if selectedTab == .parties {
                            if let imageURL = currentPartyImageURLs.last {
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    if case .success(let image) = phase {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .clipped()
                                            .opacity(1)
                                    } else {
                                        Color.clear
                                    }
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .ignoresSafeArea(edges: .all)
                            }
                        } else if let imageURL = currentSchoolEventImageURL {
                            AsyncImage(url: URL(string: imageURL)) { phase in
                                if case .success(let image) = phase {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                        .opacity(1)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .ignoresSafeArea(edges: .all)
                        }
                        
                        // Glass background overlay
                        if (selectedTab == .parties && !currentPartyImageURLs.isEmpty) || (selectedTab == .schoolEvents && currentSchoolEventImageURL != nil) {
                            Color.clear
                                .background(.ultraThinMaterial)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .ignoresSafeArea(edges: .all)
                        }
                    }
                }
                .ignoresSafeArea(edges: .all)
                .allowsHitTesting(false)
                
                VStack(spacing: 0) {
                    headerView
                    tabContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selectedTab == .parties ? Color.clear : Color.white)
                .zIndex(1)
                
                // Custom navigation bar
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showEventCreationFlow = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    .frame(height: 44)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(2)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.startLocation.x < 20 && value.translation.width > 100 {
                            dismiss()
                        }
                    }
            )
            .task {
                await loadModerationData()
            }
            .onAppear {
                Task {
                    await campusEventsVM.fetchOnce(limit: 25)
                    campusEventsVM.start()
                    await geocodeTodaysEventsIfNeeded()
                }
                AttendedEventsService.shared.refreshAttendedEvents()
            }
            .onDisappear {
                campusEventsVM.stop()
            }
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
                displayedEventCount = eventsPerPage
            }
            .fullScreenCover(isPresented: $showEventCreationFlow) {
                EventCreationFlowView()
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Backend geocoding for today's events only
    private func geocodeTodaysEventsIfNeeded() async {
        let functions = Functions.functions()
        let calendar = Calendar.current
        let todays = campusEventsVM.crowdEvents.filter { ev in
            guard let s = ev.time else { return false }
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
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(.white)
                            .frame(width: 22, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .buttonStyle(.plain)
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
                        if let time = event.time {
                            Text(formatEventTime(time))
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
        
        if let time = event.time {
            shareItems.append("Time: \(formatEventTime(time))")
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
    let selectedCategories: Set<EventCategory>
    @Binding var currentSchoolEventImageURL: String?
    
    @State private var selectedEvent: CrowdEvent? = nil
    @State private var currentEventIndex: Int = 0
    @State private var visibleIndices: Set<Int> = []
    @StateObject private var imageLoader = OptimizedImageLoader.shared
    
    // Only show first 8 images initially, then load more as needed
    private let initialLoadCount = 8
    
    var body: some View {
        Group {
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
                GeometryReader { geometry in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                                Button(action: {
                                    print("🎉 School event card tapped: \(event.title)")
                                    selectedEvent = event
                                }) {
                                    SchoolEventCardView(
                                        event: event,
                                        index: index,
                                        isVisible: visibleIndices.contains(index),
                                        priority: index < initialLoadCount
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: geometry.size.width - 30, height: geometry.size.height)
                                .containerRelativeFrame(.vertical)
                                .contentShape(Rectangle())
                                .id(index)
                                .onAppear {
                                    handleViewportAppear(index: index, geometry: geometry)
                                }
                                .onDisappear {
                                    handleViewportDisappear(index: index)
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 15)
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear {
            print("🎉 School events view appeared - \(filteredEvents.count) events")
            // Preload first 8 images immediately
            Task {
                await preloadInitialImages()
            }
            if !filteredEvents.isEmpty {
                currentSchoolEventImageURL = filteredEvents[0].imageURL
                print("📸 Set initial school event image URL: \(filteredEvents[0].imageURL ?? "nil")")
            }
        }
        .onChange(of: currentEventIndex) { oldValue, newValue in
            if newValue >= 0 && newValue < filteredEvents.count {
                currentSchoolEventImageURL = filteredEvents[newValue].imageURL
                print("📸 School event index changed to \(newValue), image URL: \(filteredEvents[newValue].imageURL ?? "nil")")
            }
        }
        .onChange(of: filteredEvents) { oldValue, newValue in
            print("🔄 Filtered school events changed: \(oldValue.count) -> \(newValue.count)")
            // Update image URL when filtered events change
            if !newValue.isEmpty && (currentEventIndex >= newValue.count || currentSchoolEventImageURL == nil) {
                currentSchoolEventImageURL = newValue[0].imageURL
                print("📸 Updated school event image URL after filter: \(newValue[0].imageURL ?? "nil")")
            }
        }
        .onChange(of: selectedEvent) { oldValue, newValue in
            if newValue != nil {
                print("🎉 Selected school event changed: \(newValue?.title ?? "nil")")
            }
        }
        .fullScreenCover(item: $selectedEvent) { event in
            SchoolEventDetailView(event: event)
        }
    }
    
    private func handleViewportAppear(index: Int, geometry: GeometryProxy) {
        currentEventIndex = index
        if index < filteredEvents.count {
            let event = filteredEvents[index]
            currentSchoolEventImageURL = event.imageURL
            print("📸 School event card appeared at index \(index): \(event.title), image URL: \(event.imageURL ?? "nil")")
        }
        
        // Add to visible indices
        visibleIndices.insert(index)
        
        // Update viewport tracking
        updateViewportIndices()
    }
    
    private func handleViewportDisappear(index: Int) {
        visibleIndices.remove(index)
        // Don't update immediately on disappear to avoid thrashing
        // The next appear will update the viewport
    }
    
    private func updateViewportIndices() {
        // Calculate viewport range (current index ± 2 screens)
        let viewportSize = 2
        guard let currentIndex = visibleIndices.min() else { return }
        
        let expandedIndices = visibleIndices.flatMap { index in
            (max(0, index - viewportSize)...min(filteredEvents.count - 1, index + viewportSize)).map { $0 }
        }
        let viewportSet = Set(expandedIndices)
        
        // Update image loader viewport
        imageLoader.updateViewport(
            visibleIndices: viewportSet,
            allEvents: filteredEvents,
            viewportSize: viewportSize
        )
    }
    
    private func preloadInitialImages() async {
        // Preload first 8 images with priority
        let preloadRange = min(initialLoadCount, filteredEvents.count)
        print("🎉 Starting school event image preload for \(preloadRange) images")
        for index in 0..<preloadRange {
            guard let imageURL = filteredEvents[index].imageURL else { continue }
            let eventTitle = filteredEvents[index].title
            print("📸 Preloading school event image \(index + 1)/\(preloadRange): \(eventTitle)")
            _ = await imageLoader.loadPlaceholder(for: imageURL, width: 350, height: 450)
            _ = await imageLoader.loadImage(for: imageURL, width: 350, height: 450, priority: true)
            print("✅ Preloaded school event image \(index + 1)/\(preloadRange): \(eventTitle)")
        }
        print("✅ Completed school event image preload for \(preloadRange) images")
    }
}

// MARK: - School Event Card View
struct SchoolEventCardView: View {
    let event: CrowdEvent
    let index: Int
    let isVisible: Bool
    let priority: Bool
    
    @State private var isAttending = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Event Image - Top to Middle (Optimized)
            OptimizedEventImage(
                imageURL: event.imageURL,
                width: 350,
                height: 300,
                contentMode: .fill,
                priority: priority
            )
            .frame(maxWidth: .infinity)
            .clipped()
            
            // Details Section - Bottom
            VStack(alignment: .leading, spacing: 12) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                
                // Description
                if let description = event.description {
                    let lines = description.components(separatedBy: "\n")
                    if let first = lines.first, !first.isEmpty {
                        Text(first)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Time with emoji - show unformatted rawDateTime from Firebase for school events
                if let rawDateTime = event.rawDateTime, !rawDateTime.isEmpty {
                    HStack(spacing: 6) {
                        Text("📅")
                            .font(.system(size: 14))
                        Text(rawDateTime)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Address with emoji
                if let address = event.rawLocationName, !address.isEmpty {
                    HStack(spacing: 6) {
                        Text("📍")
                            .font(.system(size: 14))
                        Text(address)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    // I'm Attending Button
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
                        HStack {
                            Image(systemName: isAttending ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                                .font(.system(size: 14))
                            Text(isAttending ? "Attending" : "I'm Attending")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isAttending ? Color.green : Color.accentColor)
                        )
                    }
                    
                    // More Info Button
                    if let sourceURL = event.sourceURL {
                        Button(action: {
                            if let url = URL(string: sourceURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                                Text("More Info")
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
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .frame(maxWidth: 350, minHeight: 450)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .onAppear {
            isAttending = AttendedEventsService.shared.isAttendingEvent(event.id)
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
}

// MARK: - School Event Detail View
struct SchoolEventDetailView: View {
    let event: CrowdEvent
    @Environment(\.dismiss) private var dismiss
    @State private var isAttending = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Event Image - Full Width (Optimized)
                    OptimizedEventImage(
                        imageURL: event.imageURL,
                        width: UIScreen.main.bounds.width,
                        height: 400,
                        contentMode: .fill,
                        priority: true
                    )
                
                    // Content Section
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        Text(event.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.top, 20)
                        
                        // Description
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .padding(.top, 8)
                        }
                        
                        // Date - show unformatted rawDateTime from Firebase for school events
                        if let rawDateTime = event.rawDateTime, !rawDateTime.isEmpty {
                            HStack(spacing: 4) {
                                Text("Date:")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("📅")
                                    .font(.system(size: 18))
                                Text(rawDateTime)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        // Location
                        if let location = event.rawLocationName, !location.isEmpty {
                            HStack(spacing: 4) {
                                Text("Location:")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Button(action: {
                                    openLocationInMaps(address: location, coordinate: event.coordinates)
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
                            // More Info Button
                            if let sourceURL = event.sourceURL {
                                Button(action: {
                                    if let url = URL(string: sourceURL) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "link")
                                            .font(.system(size: 18))
                                        Text("More Info")
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
                            
                            // I'm Attending Button
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
                                HStack {
                                    Image(systemName: isAttending ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                                        .font(.system(size: 18))
                                    Text(isAttending ? "Attending" : "I'm Attending")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isAttending ? Color.green : Color.accentColor)
                                )
                            }
                            
                            // Share Button
                            Button(action: {
                                shareEvent()
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
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
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
                            .background(Circle().fill(Color.black.opacity(0.3)).frame(width: 36, height: 36))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .onAppear {
            isAttending = AttendedEventsService.shared.isAttendingEvent(event.id)
        }
    }
    
    private func openLocationInMaps(address: String, coordinate: CLLocationCoordinate2D) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = address
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMM d, yyyy"
        return formatter.string(from: date)
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
        
        if let time = event.time {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            shareItems.append("Time: \(formatter.string(from: time))")
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
}

// MARK: - Parties View
struct PartiesView: View {
    @Environment(\.appEnvironment) var env
    @State private var parties: [CrowdEvent] = []
    @State private var isLoading = false
    @State private var selectedParty: CrowdEvent? = nil
    @State private var currentPartyIndex: Int = 0
    @Binding var currentPartyImageURLs: [String]
    @Binding var currentPartyIndices: [Int]
    
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
                GeometryReader { geometry in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(parties.enumerated()), id: \.element.id) { index, party in
                                Button(action: {
                                    print("🎉 Party card tapped: \(party.title)")
                                    selectedParty = party
                                }) {
                                    PartyCardView(party: party)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: geometry.size.width - 30)
                                .frame(height: geometry.size.height)
                                .containerRelativeFrame(.vertical)
                                .contentShape(Rectangle())
                                .id(index)
                                .onAppear {
                                    currentPartyIndex = index
                                    updateCurrentEventAndImage(index: index, party: party)
                                }
                                .onDisappear {
                                    removeEventFromArrays(index: index)
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 15)
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
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
        .onChange(of: currentPartyIndex) { oldValue, newValue in
            if newValue >= 0 && newValue < parties.count {
                let party = parties[newValue]
                updateCurrentEventAndImage(index: newValue, party: party)
            }
        }
    }
    
    /// Updates the current event and image arrays to keep them synchronized
    /// Ensures both arrays always have the same length and matching indices
    /// Only tracks events that have a valid imageURL
    private func updateCurrentEventAndImage(index: Int, party: CrowdEvent) {
        // Only add to arrays if the party has a valid imageURL (not nil or empty)
        guard let imageURL = party.imageURL, !imageURL.isEmpty else {
            if party.imageURL == nil {
                print("⚠️ Party '\(party.title)' has nil imageURL - skipping")
            } else {
                print("⚠️ Party '\(party.title)' has empty imageURL - skipping")
            }
            return
        }
        
        // Find if this index already exists in the arrays
        if let existingPosition = currentPartyIndices.firstIndex(of: index) {
            // Update existing entry at the same position in both arrays
            currentPartyIndices[existingPosition] = index
            if existingPosition < currentPartyImageURLs.count {
                currentPartyImageURLs[existingPosition] = imageURL
            } else {
                // If somehow out of sync, fix it
                currentPartyImageURLs.append(imageURL)
            }
        } else {
            // Add new entry to both arrays at the same time to keep them synchronized
            currentPartyIndices.append(index)
            currentPartyImageURLs.append(imageURL)
        }
        
        // Ensure arrays are always the same length (safety check)
        let minCount = min(currentPartyIndices.count, currentPartyImageURLs.count)
        currentPartyIndices = Array(currentPartyIndices.prefix(minCount))
        currentPartyImageURLs = Array(currentPartyImageURLs.prefix(minCount))
    }
    
    /// Removes event from arrays when it disappears from view
    /// Ensures both arrays are updated together to maintain synchronization
    private func removeEventFromArrays(index: Int) {
        // Only remove if it's not the currently visible index
        guard index != currentPartyIndex else { return }
        
        if let arrayIndex = currentPartyIndices.firstIndex(of: index) {
            // Remove from both arrays at the same position to keep them synchronized
            currentPartyIndices.remove(at: arrayIndex)
            if arrayIndex < currentPartyImageURLs.count {
                currentPartyImageURLs.remove(at: arrayIndex)
            }
        }
        
        // Ensure arrays stay synchronized (safety check)
        let minCount = min(currentPartyIndices.count, currentPartyImageURLs.count)
        currentPartyIndices = Array(currentPartyIndices.prefix(minCount))
        currentPartyImageURLs = Array(currentPartyImageURLs.prefix(minCount))
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
                guard let date1 = party1.time else { return false }
                guard let date2 = party2.time else { return true }
                return date1 < date2
            }
            
            // Update UI on main thread
            await MainActor.run {
                parties = sortedParties
                currentPartyIndex = 0
                // Initialize arrays with first party that has a valid imageURL (not nil or empty)
                if !sortedParties.isEmpty, let firstImageURL = sortedParties[0].imageURL, !firstImageURL.isEmpty {
                    currentPartyImageURLs = [firstImageURL]
                    currentPartyIndices = [0]
                    print("📸 Initialized arrays with first party imageURL: \(firstImageURL.prefix(50))...")
                } else {
                    currentPartyImageURLs = []
                    currentPartyIndices = []
                    if !sortedParties.isEmpty {
                        let firstImageURL = sortedParties[0].imageURL
                        print("⚠️ First party '\(sortedParties[0].title)' has invalid imageURL (nil: \(firstImageURL == nil), empty: \(firstImageURL?.isEmpty ?? false)) - arrays start empty")
                    }
                }
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
    @Environment(\.appEnvironment) var env
    @State private var isAttending = false
    @State private var isJoining = false
    @State private var isUserAuthenticated = false
    
    private var canInteract: Bool {
        isUserAuthenticated && !isJoining && !isAttending
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Event Image - Top to Middle
            CachedEventImage(
                imageURL: party.imageURL,
                height: 300,
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .clipped()
            
            // Details Section - Bottom
            VStack(alignment: .leading, spacing: 12) {
                // Title + Host Name
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
                
                // Time with emoji - using dateTime from Firebase (party events)
                // Note: Firebase field is "dateTime", mapped to party.dateTime property
                if let dateTime = party.dateTime, !dateTime.isEmpty {
                    HStack(spacing: 6) {
                        Text("📅")
                            .font(.system(size: 14))
                        Text(dateTime)
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
                
                // I'm Going Button
                Button(action: {
                    Task {
                        await saveEventToProfile()
                    }
                }) {
                    HStack {
                        if isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("I'm going")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "checkmark")
                                .font(.system(size: 14))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
                }
                .disabled(!canInteract)
                .opacity(canInteract ? 1.0 : 0.6)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .frame(maxWidth: 350, minHeight: 450)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
    
    
    private func saveEventToProfile() async {
        // Try to authenticate if not already authenticated
        if !isUserAuthenticated {
            do {
                let userId = try await FirebaseManager.shared.signInAnonymously()
                print("✅ Signed in anonymously for attendance: \(userId)")
                await MainActor.run {
                    isUserAuthenticated = true
                }
            } catch {
                print("❌ Failed to sign in anonymously: \(error.localizedDescription)")
                await MainActor.run {
                    isUserAuthenticated = false
                }
                return
            }
        }
        
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ Cannot save event - No authenticated user after sign-in attempt")
            await MainActor.run {
                isUserAuthenticated = false
            }
            return
        }
        
        // Check if already attending
        if isAttending {
            return
        }
        
        await MainActor.run {
            isJoining = true
        }
        
        do {
            // Fetch current profile to get existing eventStatus
            let profile = try await UserProfileService.shared.fetchProfile(userId: userId)
            var currentEventStatus = profile.eventStatus ?? []
            
            // Add event ID if not already present
            if !currentEventStatus.contains(party.id) {
                currentEventStatus.append(party.id)
                
                // Update profile with new event status
                try await UserProfileService.shared.updateProfile(userId: userId, updates: [
                    "eventStatus": currentEventStatus
                ])
                
                print("✅ Saved event \(party.id) to user profile event status")
                
                await MainActor.run {
                    isAttending = true
                    isJoining = false
                }
            } else {
                await MainActor.run {
                    isAttending = true
                    isJoining = false
                }
            }
        } catch {
            print("❌ Failed to save event to profile: \(error.localizedDescription)")
            await MainActor.run {
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
                        CachedEventImage(
                            imageURL: displayParty.imageURL,
                            height: 400,
                            contentMode: .fill
                        )
                    
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
                        
                        // Date - show unformatted dateTime string from Firebase for parties
                        if let dateTime = displayParty.dateTime, !dateTime.isEmpty {
                            HStack(spacing: 4) {
                                Text("Date:")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("📅")
                                    .font(.system(size: 18))
                                Text(dateTime)
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
                        VStack(spacing: 0) {
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
                            .padding(.top, 6)
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

// MARK: - Three Step Progress Bar
struct ThreeStepProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= currentStep ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 30, height: 4)
            }
        }
    }
}

// MARK: - Event Type Enum
enum EventCreationType {
    case ticketed
    case rsvp
}

// MARK: - Event Creation Flow
struct EventCreationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var eventType: EventCreationType?
    @State private var currentStep = 0
    private let totalSteps = 3
    
    var body: some View {
        ZStack {
            if currentStep == 0 {
                // Step 0: Event Type Selection
                EventTypeSelectionView(
                    currentStep: $currentStep,
                    eventType: $eventType,
                    dismiss: dismiss
                )
                .transition(.opacity)
            } else if currentStep == 1 {
                // Step 1: Event Details Form
                EventDetailsFormView(
                    currentStep: $currentStep,
                    eventType: eventType ?? .ticketed,
                    dismiss: dismiss
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}

// MARK: - Event Type Selection View (Step 0)
struct EventTypeSelectionView: View {
    @Binding var currentStep: Int
    @Binding var eventType: EventCreationType?
    let dismiss: DismissAction
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with back button and centered progress indicator
                ZStack {
                    // Back button - left aligned
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    
                    // Progress indicator - centered
                    ThreeStepProgressBar(currentStep: 0, totalSteps: 3)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Title
                Text("Let's launch your next event")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                
                // Event Type Cards
                HStack(spacing: 16) {
                    // Sell tickets card
                    EventTypeCard(
                        icon: "dollarsign",
                        title: "Sell tickets",
                        action: {
                            eventType = .ticketed
                            currentStep = 1
                        }
                    )
                    
                    // RSVP Only card
                    EventTypeCard(
                        icon: "hand.wave.fill",
                        title: "RSVP Only",
                        action: {
                            eventType = .rsvp
                            currentStep = 1
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Join a Kickoff Session link
                Button {
                    // Open Kickoff Session URL
                    if let url = URL(string: "https://calendly.com/your-kickoff-link") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Join a Kickoff Session")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Event Details Form View (Step 1)
struct EventDetailsFormView: View {
    @Binding var currentStep: Int
    let eventType: EventCreationType
    let dismiss: DismissAction
    
    @State private var eventTitle = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var venueName = ""
    @State private var address = ""
    @State private var eventSummary = ""
    @State private var showOnExplore = true
    @State private var passwordProtected = false
    @State private var enableActivity = true
    @State private var activityType = ActivityType.socialFeed
    @State private var selectedTab: DesignTab = .flyer
    @State private var eventImage: UIImage?
    @State private var showImagePicker = false
    
    enum ActivityType {
        case socialFeed
        case updatesOnly
    }
    
    enum DesignTab {
        case flyer, video, font, theme
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with back button and centered progress indicator
                ZStack {
                    // Back button - left aligned
                    HStack {
                        Button {
                            currentStep = 0
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    
                    // Progress indicator - centered
                    ThreeStepProgressBar(currentStep: 1, totalSteps: 3)
                }
                .padding(.top, 60)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Event Image Upload Box
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack {
                                if let image = eventImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 120)
                                        .clipped()
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.gray)
                                        Text("Upload Event Image")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.white.opacity(0.05))
                                }
                            }
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.top, 12)
                        
                        // Design tabs at top
                        HStack(spacing: 0) {
                            DesignTabButton(title: "Flyer", icon: "photo", isSelected: selectedTab == .flyer) {
                                selectedTab = .flyer
                            }
                            DesignTabButton(title: "Video", icon: "video.fill", isSelected: selectedTab == .video) {
                                selectedTab = .video
                            }
                            DesignTabButton(title: "Font", icon: "textformat", isSelected: selectedTab == .font) {
                                selectedTab = .font
                            }
                            DesignTabButton(title: "Theme", icon: "paintpalette.fill", isSelected: selectedTab == .theme) {
                                selectedTab = .theme
                            }
                        }
                        .frame(height: 50)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.top, 8)
                        
                        // Event Details Card
                        VStack(spacing: 0) {
                            // Event Title
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("", text: $eventTitle, prompt: Text("My Event*").foregroundColor(.gray))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 16)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Start and End Date
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start*")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.gray)
                                    DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                
                                Divider()
                                    .frame(height: 60)
                                    .background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("End*")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Button {
                                            // Toggle visibility
                                        } label: {
                                            Image(systemName: "eye")
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Repeats
                            HStack {
                                Text("Repeats")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.gray)
                                Spacer()
                                Text("Never")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.vertical, 16)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Venue Name
                            TextField("", text: $venueName, prompt: Text("Venue Name*").foregroundColor(.gray))
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .padding(.vertical, 16)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Address
                            HStack {
                                TextField("", text: $address, prompt: Text("Address*").foregroundColor(.gray))
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                Button {
                                    // Toggle address visibility
                                } label: {
                                    Image(systemName: "eye")
                                        .foregroundStyle(.gray)
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.top, 16)
                        
                        // Additional Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Additional Details")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(.top, 24)
                            
                            // Event Summary
                            TextEditor(text: $eventSummary)
                                .frame(height: 120)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    Group {
                                        if eventSummary.isEmpty {
                                            Text("Event Summary (optional)")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.gray)
                                                .padding(.leading, 20)
                                                .padding(.top, 8)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                )
                            
                            // Toggles
                            VStack(spacing: 0) {
                                SettingToggleRow(
                                    title: "Show on Explore",
                                    hasInfo: true,
                                    isOn: $showOnExplore
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                SettingToggleRow(
                                    title: "Password Protected Event",
                                    hasInfo: true,
                                    isOn: $passwordProtected
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                SettingToggleRow(
                                    title: "Enable Event Activity",
                                    hasInfo: true,
                                    isOn: $enableActivity
                                )
                                
                                if enableActivity {
                                    VStack(spacing: 12) {
                                        RadioOption(
                                            title: "Social feed",
                                            subtitle: "Organizers and attendees can post, reply, and react in the activity feed.",
                                            isSelected: activityType == .socialFeed
                                        ) {
                                            activityType = .socialFeed
                                        }
                                        
                                        RadioOption(
                                            title: "Updates only",
                                            subtitle: "Only organizers can post updates. Attendees can't comment or react.",
                                            isSelected: activityType == .updatesOnly
                                        ) {
                                            activityType = .updatesOnly
                                        }
                                    }
                                    .padding(.vertical, 16)
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                        
                        // Tickets Section (if ticketed event)
                        if eventType == .ticketed {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Tickets")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.gray)
                                    Spacer()
                                    Button {
                                        // Add ticket
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.top, 24)
                                
                                HStack {
                                    Text("Default Ticket")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("$10.00")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                    Button {
                                        // Edit ticket
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Show Advanced Settings
                        Button {
                            // Show advanced settings
                        } label: {
                            Text("Show Advanced Settings")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .padding(.top, 24)
                        
                        // Back Button
                        Button {
                            currentStep = 0
                        } label: {
                            Text("Back")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .padding(.leading, 22)
                }
            }
        }
    }
}

// MARK: - Design Tab Button
struct DesignTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : .gray)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Setting Toggle Row
struct SettingToggleRow: View {
    let title: String
    let hasInfo: Bool
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.white)
            if hasInfo {
                Button {
                    // Show info
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.white)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Radio Option
struct RadioOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Event Type Card
struct EventTypeCard: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                // Icon with circular background
                ZStack {
                    Circle()
                        .fill(Color(red: 0.7, green: 0.85, blue: 0.3))
                        .frame(width: 100, height: 100)
                    
                    if icon == "hand.wave.fill" {
                        Image(systemName: icon)
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    } else {
                        ZStack {
                            // Dollar sign with circular progress indicator
                            Circle()
                                .trim(from: 0, to: 0.6)
                                .stroke(Color.black, lineWidth: 8)
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                            
                            Text("$")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                }
                
                // Title
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

#Preview {
    CalenderView()
}
