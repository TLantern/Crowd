//
//  CalenderView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI
import CoreLocation
import FirebaseFunctions

struct CalenderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var campusEventsVM = CampusEventsViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategories: Set<EventCategory> = []
    @State private var displayedEventCount = 10
    private let eventsPerPage = 10
    
    // Filtered events based on selected categories
    var filteredEvents: [CrowdEvent] {
        if selectedCategories.isEmpty {
            return campusEventsVM.crowdEvents
        }
        
        return campusEventsVM.crowdEvents.filter { event in
            // Check if event tags match any of the selected categories
            return selectedCategories.contains { category in
                category.matchesTags(event.tags)
            }
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
                            Text("Upcoming Events")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("\(displayedEvents.count) of \(filteredEvents.count) events")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        CategoryFilterDropdown(selectedCategories: $selectedCategories)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Events List
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
            .onAppear {
                // Initial one-time fetch, then live updates to ensure Upcoming list stays populated
                Task {
                    await campusEventsVM.fetchOnce(limit: 25)
                    campusEventsVM.start()
                    await geocodeTodaysEventsIfNeeded()
                }
                // Refresh attended events to clean up expired ones
                AttendedEventsService.shared.refreshAttendedEvents()
            }
            .onDisappear { campusEventsVM.stop() }
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
}

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
                        // Meta line (location • org) always
                        let lines = description.components(separatedBy: "\n")
                        if let first = lines.first {
                            Text(first)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        // Always show time (from event starts/ends) directly below meta
                        if let startsAt = event.startsAt {
                            let endText = event.endsAt.map { " – " + formatEventTime($0) } ?? ""
                            Text(formatEventTime(startsAt) + endText)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        // Only when expanded, reveal additional description lines beyond location/org and time
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
            
            // Event URL section (shown when expanded)
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
            
            
            // RSVP/Tickets, Share and Attending buttons
            HStack {
                // RSVP/Tickets button
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
                
                // Share button
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
                
                // Attending button
                Button(action: {
                    Task {
                        if !isAttending {
                            // If this is an external/live campus event (has sourceURL), record locally without backend join
                            if event.sourceURL != nil {
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isAttending = true
                                        AttendedEventsService.shared.addAttendedEvent(event)
                                    }
                                }
                            } else {
                                // Backend-managed event
                                do {
                                    try await AppEnvironment.current.eventRepo.join(eventId: event.id, userId: FirebaseManager.shared.getCurrentUserId() ?? "")
                                    await MainActor.run {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isAttending = true
                                            AttendedEventsService.shared.addAttendedEvent(event)
                                        }
                                    }
                                } catch {
                                    print("❌ Failed to join event: \(error)")
                                }
                            }
                        } else {
                            // Remove from attended events
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
            // Check if user is already attending this event
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
        var shareItems: [Any] = []
        
        // Add event title
        shareItems.append(event.title)
        
        // Add description if available
        if let description = event.description {
            shareItems.append(description)
        }
        
        // Add time if available
        if let startsAt = event.startsAt {
            shareItems.append("Time: \(formatEventTime(startsAt))")
        }
        
        // Add source URL if available
        if let sourceURL = event.sourceURL {
            shareItems.append(sourceURL)
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
    
    private static let tagEmojis: [String: String] = [
        // Music & Entertainment
        "music": "🎵", "concert": "🎤", "party": "🎉", "festival": "🎪", "dance": "💃",
        "dancing": "💃", "live": "🎵", "performance": "🎭",
        
        // Food & Dining
        "food": "🍕", "dining": "🍽️", "restaurant": "🍽️", "cafe": "☕", "coffee": "☕",
        "lunch": "🍽️", "dinner": "🍽️", "breakfast": "🥞", "snack": "🍿",
        
        // Sports & Fitness
        "sports": "⚽", "basketball": "🏀", "football": "🏈", "soccer": "⚽", "tennis": "🎾",
        "volleyball": "🏐", "baseball": "⚾", "fitness": "💪", "gym": "💪", "workout": "💪",
        "yoga": "🧘", "running": "🏃", "cycling": "🚴",
        
        // Academic & Education
        "study": "📚", "academic": "🎓", "lecture": "🎓", "workshop": "🔧", "seminar": "🎓",
        "conference": "🎓", "education": "🎓", "learning": "📚", "research": "🔬", "science": "🔬",
        "tech": "💻", "technology": "💻", "coding": "💻", "programming": "💻",
        
        // Arts & Culture
        "art": "🎨", "creative": "🎨", "culture": "🌍", "cultural": "🌍", "international": "🌍",
        "language": "🗣️", "film": "🎬", "movie": "🎬", "theater": "🎭", "drama": "🎭",
        "comedy": "😂", "standup": "🎤", "photography": "📸", "gallery": "🖼️",
        
        // Social & Networking
        "networking": "🤝", "meetup": "👥", "community": "🏘️", "volunteer": "🤝", "charity": "❤️",
        "fundraising": "💰", "career": "💼", "job": "💼", "business": "💼", "entrepreneur": "🚀",
        "startup": "🚀",
        
        // Health & Wellness
        "health": "🏥", "wellness": "💚", "mental": "🧠", "spiritual": "🙏", "religious": "⛪",
        "faith": "⛪", "meditation": "🧘", "mindfulness": "🧘",
        
        // Outdoor & Nature
        "outdoor": "🏔️", "hiking": "🥾", "camping": "⛺", "nature": "🌿", "environment": "🌱",
        "sustainability": "🌱", "travel": "✈️", "adventure": "🗺️",
        
        // Gaming & Entertainment
        "gaming": "🎮", "esports": "🎮", "board": "🎲", "trivia": "🧠", "puzzle": "🧩", "card": "🃏",
        
        // Lifestyle & Hobbies
        "fashion": "👗", "beauty": "💄", "cooking": "👨‍🍳", "baking": "🧁", "wine": "🍷",
        "beer": "🍺", "tea": "🍵", "book": "📖", "reading": "📖", "writing": "✍️",
        "poetry": "📝", "blog": "✍️",
        
        // Politics & Activism
        "politics": "🏛️", "debate": "🗣️", "activism": "✊", "protest": "✊", "voting": "🗳️",
        "election": "🗳️",
        
        // Special Events
        "graduation": "🎓", "celebration": "🎉", "anniversary": "🎂", "birthday": "🎂",
        "holiday": "🎄", "christmas": "🎄", "halloween": "🎃", "valentine": "💕", "newyear": "🎊",
        
        // Source Types
        "official": "🏛️", "student": "🎓", "instagram": "📸", "social": "👥"
    ]
    
    private static func getEventEmoji(for tags: [String]) -> String {
        // Check for exact matches first
        for tag in tags {
            let lowercaseTag = tag.lowercased()
            if let emoji = tagEmojis[lowercaseTag] {
                return emoji
            }
        }
        
        // Check for partial matches (only for first tag to minimize energy impact)
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

#Preview {
    CalenderView()
}
