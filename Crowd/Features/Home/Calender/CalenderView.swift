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
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Tab Switcher
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
        isLoading = true
        do {
            if let firebaseRepo = env.eventRepo as? FirebaseEventRepository {
                let fetchedParties = try await firebaseRepo.fetchParties()
                await MainActor.run {
                    parties = fetchedParties
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            print("❌ Failed to load parties: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Party Card View
struct PartyCardView: View {
    let party: CrowdEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Party Image
            if let imageURL = party.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundStyle(.gray)
                    )
            }
            
            // Party Info
            VStack(alignment: .leading, spacing: 12) {
                Text(party.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(16)
        }
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
                        // Title
                        Text(displayParty.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.top, 20)
                        
                        // Description
                        if let description = displayParty.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .padding(.top, 4)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Date & Time
                        if let startsAt = displayParty.startsAt {
                            HStack(spacing: 16) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.accentColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Date & Time")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(formatEventTime(startsAt))
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Location - Clickable to open Maps
                        if let location = displayParty.rawLocationName, !location.isEmpty {
                            Button(action: {
                                openLocationInMaps(address: location, coordinate: displayParty.coordinates)
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.accentColor)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Location")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text(location)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(.primary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.accentColor)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
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
                            
                            // Join Button
                            Button(action: {
                                Task {
                                    await joinParty(party: displayParty)
                                }
                            }) {
                                HStack {
                                    if isJoining {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: isAttending ? "checkmark.circle.fill" : "plus.circle.fill")
                                            .font(.system(size: 18))
                                        Text(isAttending ? "Joined" : "Join Party")
                                            .font(.system(size: 17, weight: .semibold))
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
                            
                            // Share Button
                            Button(action: {
                                shareParty()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 18))
                                    Text("Share Party")
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
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.black.opacity(0.3)).frame(width: 36, height: 36))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
                }
            }
        }
        .onAppear {
            Task {
                await loadPartyDetails()
            }
            isAttending = AttendedEventsService.shared.isAttendingEvent(party.id)
        }
    }
    
    private func loadPartyDetails() async {
        isLoadingParty = true
        do {
            // Fetch fresh party data from Firebase
            if let firebaseRepo = env.eventRepo as? FirebaseEventRepository {
                let parties = try await firebaseRepo.fetchParties()
                if let freshParty = parties.first(where: { $0.id == party.id }) {
                    await MainActor.run {
                        loadedParty = freshParty
                        isLoadingParty = false
                    }
                } else {
                    await MainActor.run {
                        loadedParty = party
                        isLoadingParty = false
                    }
                }
            } else {
                await MainActor.run {
                    loadedParty = party
                    isLoadingParty = false
                }
            }
        } catch {
            print("❌ Failed to load party details: \(error.localizedDescription)")
            await MainActor.run {
                loadedParty = party
                isLoadingParty = false
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
    
    private func joinParty(party: CrowdEvent) async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        
        isJoining = true
        do {
            try await env.eventRepo.join(eventId: party.id, userId: userId)
            
            // Create attendance record
            let db = FirebaseManager.shared.db
            let attendanceData: [String: Any] = [
                "userId": userId,
                "eventId": party.id,
                "joinedAt": FieldValue.serverTimestamp()
            ]
            try await db.collection("userAttendances").addDocument(data: attendanceData)
            
            AttendedEventsService.shared.addAttendedEvent(party)
            
            // Update loaded party if available
            if var updatedParty = loadedParty {
                updatedParty.attendeeCount += 1
                await MainActor.run {
                    loadedParty = updatedParty
                }
            }
            
            await MainActor.run {
                isAttending = true
                isJoining = false
            }
        } catch {
            print("❌ Failed to join party: \(error.localizedDescription)")
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
    
    private func shareParty() {
        let displayParty = loadedParty ?? party
        
        // Track share analytics
        AnalyticsService.shared.track("party_shared", props: [
            "party_id": displayParty.id,
            "title": displayParty.title
        ])
        
        var shareItems: [Any] = []
        
        // Create share text
        var shareText = "🎉 \(displayParty.title)\n\n"
        
        if let startsAt = displayParty.startsAt {
            shareText += "📅 \(formatEventTime(startsAt))\n"
        }
        
        if let location = displayParty.rawLocationName {
            shareText += "📍 \(location)\n\n"
        }
        
        if let description = displayParty.description {
            shareText += "\(description)\n\n"
        }
        
        // Add deep link or ticket URL
        let shareLinkService = ShareLinkService()
        if let deepLink = shareLinkService.partyDeepLink(id: displayParty.id) {
            // Create a universal link that opens the app to party tab if installed
            shareText += "Join the party in Crowd: \(deepLink.absoluteString)"
            shareItems.append(shareText)
            shareItems.append(deepLink)
            
            // Add ticket URL as fallback for users without the app
            if let ticketURL = displayParty.ticketURL {
                shareItems.append(URL(string: ticketURL)!)
            }
        } else if let ticketURL = displayParty.ticketURL {
            shareText += "Get tickets: \(ticketURL)"
            shareItems.append(shareText)
            shareItems.append(URL(string: ticketURL)!)
        } else {
            shareItems.append(shareText)
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
                            // Calendar events: always update locally so the button transitions instantly
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAttending = true
                                    AttendedEventsService.shared.addAttendedEvent(event)
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
        // Track invite sent
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
