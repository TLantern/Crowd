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

// MARK: - URL Utilities
func normalizeURLString(_ urlString: String) -> URL? {
    var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Check if URL already has a scheme
    if !normalized.lowercased().hasPrefix("http://") && !normalized.lowercased().hasPrefix("https://") {
        // Add https:// if no scheme present
        normalized = "https://\(normalized)"
    }
    
    // Try to create URL
    guard let url = URL(string: normalized) else { return nil }
    
    // Validate scheme
    guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
        return nil
    }
    
    // Validate host
    guard url.host != nil else { return nil }
    
    return url
}

struct CalenderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var campusEventsVM = CampusEventsViewModel.shared
    @EnvironmentObject private var appState: AppState
    @StateObject private var deepLinks = DeepLinkManager.shared
    @State private var displayedEventCount = 10
    @State private var selectedTab: TabSelection = .parties
    @State private var selectedPartyEvent: CrowdEvent?
    @State private var selectedSchoolEvent: CrowdEvent?
    private let eventsPerPage = 10
    
    enum TabSelection {
        case parties
        case schoolEvents
    }
    
    private let tabSwipeThreshold: CGFloat = 60
    @State private var showEventCreationFlow = false
    @State private var currentPartyImageURL: String?
    @State private var currentSchoolEventImageURL: String?
    @State private var selectedInterest: String? = nil
    @State private var preloadedParties: [CrowdEvent]? = nil
    @Environment(\.appEnvironment) var env
    
    var schoolEvents: [CrowdEvent] { campusEventsVM.crowdEvents }
    
    var filteredSchoolEvents: [CrowdEvent] {
        guard let interest = selectedInterest else { return schoolEvents }
        guard let interestTags = interestTagMap[interest] else { return schoolEvents }
        return schoolEvents.filter { event in
            event.tags.contains { tag in
                let lowerTag = tag.lowercased()
                return interestTags.contains { interestTag in
                    lowerTag.contains(interestTag.lowercased()) || interestTag.lowercased().contains(lowerTag)
                }
            }
        }
    }
    
    private let interests: [(name: String, key: String, emoji: String)] = [
        ("Academic", "academic", "📚"),
        ("Sports", "sports", "⚽"),
        ("Arts", "arts", "🎨"),
        ("Social", "social", "👥"),
        ("Career", "career", "💼")
    ]
    
    private let interestTagMap: [String: [String]] = [
        "academic": ["academic", "study", "education", "learning", "lecture", "workshop", "seminar"],
        "sports": ["sport", "sports", "athletic", "fitness", "gym", "exercise", "game", "tournament"],
        "arts": ["art", "arts", "creative", "music", "theater", "dance", "performance", "exhibition"],
        "social": ["social", "networking", "meetup", "community", "gathering", "party", "event"],
        "career": ["career", "professional", "job", "internship", "resume", "interview", "networking"]
    ]
    
    // Upcoming events sorted by soonest start time
    var upcomingEvents: [CrowdEvent] {
        schoolEvents.sorted { (a, b) in
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
        displayedEventCount < schoolEvents.count
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
                                        .foregroundColor(selectedTab == .parties ? Color(hex: 0xF5F7FA) : Color(hex: 0xF5F7FA).opacity(0.3))
                                        .shadow(color: Color.black.opacity(0.07), radius: 15, x: 0, y: 3)  // Layer 1: Separation
                                        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 1.5)  // Layer 2: Contact
                                    
                                    ZStack {
                                        if selectedTab == .parties {
                                            Capsule()
                                                .fill(Color(hex: 0xF5F7FA))
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
                                        .foregroundColor(selectedTab == .schoolEvents ? Color(hex: 0xF5F7FA) : Color(hex: 0xF5F7FA).opacity(0.3))
                                        .shadow(color: Color.black.opacity(0.07), radius: 15, x: 0, y: 3)  // Layer 1: Separation
                                        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 1.5)  // Layer 2: Contact
                                    
                                    ZStack {
                                        if selectedTab == .schoolEvents {
                                            Capsule()
                                                .fill(Color(hex: 0xF5F7FA))
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
                            VStack(spacing: 8) {
                                Text("\(filteredSchoolEvents.count) events")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                Picker(selection: $selectedInterest) {
                                    Text("All Events")
                                        .tag(nil as String?)
                                        .foregroundColor(.black)
                                    ForEach(interests, id: \.key) { interest in
                                        Text("\(interest.emoji)  \(interest.name)")
                                            .tag(interest.key as String?)
                                            .foregroundColor(.black)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if let selected = selectedInterest,
                                           let interest = interests.first(where: { $0.key == selected }) {
                                            Text(interest.emoji)
                                            Text(interest.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.black)
                                        } else {
                                            Text("All Interests")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.black)
                                        }
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                    )
                                }
                                .pickerStyle(.menu)
                                .accentColor(.black)
                                .tint(.black)
                                .preferredColorScheme(.light)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }
    
    private var tabContent: some View {
        Group {
            if selectedTab == .parties {
                PartiesView(
                    currentPartyImageURL: $currentPartyImageURL,
                    preloadedParties: preloadedParties,
                    onContinueToSchoolEvents: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .schoolEvents
                        }
                    }
                )
            } else {
                VStack(spacing: 0) {
                SchoolEventsView(
                    events: filteredSchoolEvents,
                    selectedCategories: [],
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
                            // Use the image URL directly from the currently visible party
                            if let imageURL = currentPartyImageURL {
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
                        if (selectedTab == .parties && currentPartyImageURL != nil) || (selectedTab == .schoolEvents && currentSchoolEventImageURL != nil) {
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
                .background(Color.clear)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            guard abs(value.translation.width) > tabSwipeThreshold else { return }
                            
                            if value.translation.width < 0 {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .schoolEvents }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .parties }
                            }
                        }
                )
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
                        
                        // TODO: Temporarily commented out
                        /*
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
                        */
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
            .onAppear {
                print("📅 DEBUG: CalenderView.onAppear - starting listener")
                print("   Current schoolEvents count: \(schoolEvents.count)")
                Task {
                    campusEventsVM.start()
                    print("   ✅ Listener started")
                    await geocodeTodaysEventsIfNeeded()
                    // Preload parties in background
                    await preloadParties()
                }
                AttendedEventsService.shared.refreshAttendedEvents()
            }
            .onDisappear {
                print("📅 DEBUG: CalenderView.onDisappear - stopping listener")
                campusEventsVM.stop()
            }
            .onChange(of: schoolEvents.count) { oldCount, newCount in
                print("📅 DEBUG: schoolEvents count changed: \(oldCount) → \(newCount)")
                if newCount > 0 {
                    print("   First event: '\(schoolEvents[0].title)' at \(schoolEvents[0].time ?? Date.distantPast)")
                }
            }
            .onChange(of: deepLinks.pendingEventId) { _, newId in
                if let id = newId {
                    Task {
                        await resolveDeepLinkedEvent(id)
                    }
                    deepLinks.pendingEventId = nil
                }
            }
            .navigationDestination(item: $selectedPartyEvent) { event in
                PartyCardView(party: event)
            }
            .navigationDestination(item: $selectedSchoolEvent) { event in
                ScrollView {
                    SchoolEventCardView(event: event, index: 0, isVisible: true, priority: true)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
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
    
    // MARK: - Deep Link Resolution
    
    func resolveDeepLinkedEvent(_ eventId: String) async {
        // Try school events first (official)
        if let schoolEvent = await fetchSchoolEvent(id: eventId) {
            await MainActor.run {
                selectedSchoolEvent = schoolEvent
                selectedTab = .schoolEvents
            }
            return
        }
        
        // If not found, try party events
        if let partyEvent = await fetchPartyEvent(id: eventId) {
            await MainActor.run {
                selectedPartyEvent = partyEvent
                selectedTab = .parties
            }
            return
        }
        
        print("Deep link event not found:", eventId)
    }
    
    private func fetchSchoolEvent(id: String) async -> CrowdEvent? {
        // Check in loaded school events first
        if let event = campusEventsVM.crowdEvents.first(where: { $0.id == id }) {
            return event
        }
        
        // Try fetching from Firebase
        let db = FirebaseManager.shared.db
        let firebaseRepo = FirebaseEventRepository()
        
        // Try events collection
        do {
            let doc = try await db.collection("events").document(id).getDocument()
            if let data = doc.data() {
                var eventData = data
                eventData["id"] = id
                if let event = try? firebaseRepo.parseEvent(from: eventData) {
                    return event
                }
            }
        } catch {
            print("⚠️ Failed to fetch school event from events collection: \(error)")
        }
        
        // Try userEvents collection
        do {
            let doc = try await db.collection("userEvents").document(id).getDocument()
            if let data = doc.data() {
                var eventData = data
                eventData["id"] = id
                if let event = try? firebaseRepo.parseEvent(from: eventData) {
                    return event
                }
            }
        } catch {
            print("⚠️ Failed to fetch school event from userEvents collection: \(error)")
        }
        
        return nil
    }
    
    private func fetchPartyEvent(id: String) async -> CrowdEvent? {
        let env = AppEnvironment.current
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            return nil
        }
        
        // Try fetching from parties collection
        do {
            let parties = try await firebaseRepo.fetchParties()
            if let event = parties.first(where: { $0.id == id }) {
                return event
            }
        } catch {
            print("⚠️ Failed to fetch party event: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Parties Preloading
    
    private func preloadParties() async {
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Event repository is not FirebaseEventRepository")
            return
        }
        
        do {
            print("🎉 Preloading parties...")
            let fetchedParties = try await firebaseRepo.fetchParties()
            
            // Sort parties by date (soonest first)
            let sortedParties = fetchedParties.sorted { party1, party2 in
                guard let date1 = party1.time else { return false }
                guard let date2 = party2.time else { return true }
                return date1 < date2
            }
            
            await MainActor.run {
                preloadedParties = sortedParties
                print("✅ Preloaded \(sortedParties.count) parties")
            }
        } catch {
            print("❌ Failed to preload parties: \(error.localizedDescription)")
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
                            if let url = normalizeURLString(sourceURL) {
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
                        if let src = event.sourceURL, let url = normalizeURLString(src) {
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
                        if let url = normalizeURLString(sourceURL) {
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
                        Image(systemName: isAttending ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(isAttending ? "Attending" : "I'm Attending")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isAttending ? Color.green : Color.accentColor)
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
    let events: [CrowdEvent]
    let selectedCategories: Set<EventCategory>
    @Binding var currentSchoolEventImageURL: String?
    
    @State private var scrolledID: Int? = 0
    @StateObject private var imageLoader = OptimizedImageLoader.shared
    
    // Only show first 8 images initially, then load more as needed
    private let initialLoadCount = 10
    
    var filteredEvents: [CrowdEvent] {
        let now = Date()
        let timeFiltered = events.filter { event in
            guard let t = event.time else { return false }
            return t >= now
        }
        guard !selectedCategories.isEmpty else { return timeFiltered }
        return timeFiltered.filter { event in
            // Check if event category matches
            if let categoryString = event.category,
               let eventCategory = EventCategory(rawValue: categoryString),
               selectedCategories.contains(eventCategory) {
                return true
            }
            // Check if event tags match any selected category
            return selectedCategories.contains { category in
                category.matchesTags(event.tags)
            }
        }
    }
    
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
                            ForEach(Array(filteredEvents.enumerated()), id: \.offset) { index, event in
                                SchoolEventCardView(
                                    event: event,
                                    index: index,
                                    isVisible: scrolledID == index,
                                    priority: index < initialLoadCount
                                )
                                .frame(width: geometry.size.width - 30, height: geometry.size.height)
                                .containerRelativeFrame(.vertical)
                                .contentShape(Rectangle())
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 15)
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $scrolledID)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear {
            print("🎉 School events view appeared - \(filteredEvents.count) events")
            // Preload first images sequentially
            Task {
                await preloadInitialImages()
            }
            if !filteredEvents.isEmpty {
                currentSchoolEventImageURL = filteredEvents[0].imageURL
            }
        }
        .onChange(of: scrolledID) { oldValue, newValue in
            guard let index = newValue, index >= 0 && index < filteredEvents.count else { return }
            currentSchoolEventImageURL = filteredEvents[index].imageURL
        }
        .onChange(of: filteredEvents) { oldValue, newValue in
            print("🔄 Filtered school events changed: \(oldValue.count) -> \(newValue.count)")
            // Reset scroll position and update image URL when filtered events change
            if !newValue.isEmpty {
                scrolledID = 0
                currentSchoolEventImageURL = newValue[0].imageURL
            }
        }
    }
    
    private func preloadInitialImages() async {
        // Preload first images sequentially (in order) with priority
        let preloadRange = min(initialLoadCount, filteredEvents.count)
        print("🎉 Starting school event image preload for \(preloadRange) images")
        for index in 0..<preloadRange {
            guard let imageURL = filteredEvents[index].imageURL else { continue }
            // Load sequentially so they appear in order
            _ = await imageLoader.loadImage(for: imageURL, width: 350, height: 450, priority: true)
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
    
    @Environment(\.appEnvironment) var env
    @State private var isAttending = false
    @State private var isJoining = false
    @State private var goingCount = 0
    @State private var showMoreInfoSheet = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Event Image - Top to Middle (Optimized)
            OptimizedEventImage(
                imageURL: event.imageURL,
                width: 500,
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
                
                // Button Layout - Split if sourceURL exists, otherwise full width
                if let sourceURL = event.sourceURL {
                    // TWO BUTTONS: Split layout
                    HStack(spacing: 8) {
                        // I'm Attending / Share Button (half width)
                        Button(action: {
                            if !isAttending {
                                Task {
                                    await toggleAttending()
                                }
                            } else {
                                shareEvent()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if isJoining {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: isAttending ? "square.and.arrow.up" : "hand.thumbsup.fill")
                                        .font(.system(size: 14))
                                    Text(isAttending ? "Share" : "I'm Attending")
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isJoining ? Color.green : Color.blue)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isJoining)
                        
                        // More Info Button (half width)
                        Button(action: {
                            showMoreInfoSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                Text("More Info")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                } else {
                    // ONE BUTTON: Full width layout
                    Button(action: {
                        if !isAttending {
                            Task {
                                await toggleAttending()
                            }
                        } else {
                            shareEvent()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: isAttending ? "square.and.arrow.up" : "hand.thumbsup.fill")
                                    .font(.system(size: 14))
                                Text(isAttending ? "Share" : "I'm Attending")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isJoining ? Color.green : Color.blue)
                        )
                    }
                    .disabled(isJoining)
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: isIPad ? 500 : 350, minHeight: 450)
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
        .sheet(isPresented: $showMoreInfoSheet) {
            if let sourceURL = event.sourceURL {
                MoreInfoSheetView(sourceURL: sourceURL)
                    .presentationDetents([.large])
            }
        }
        .onAppear {
            Task {
                await loadAttendingStatus()
            }
        }
    }
    
    private func loadAttendingStatus() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            return
        }
        
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            return
        }
        
        do {
            let isGoing = try await firebaseRepo.isUserGoingToSchoolEvent(eventId: event.id, userId: userId)
            let count = try await firebaseRepo.getSchoolEventGoingCount(eventId: event.id)
            
            await MainActor.run {
                isAttending = isGoing
                goingCount = count
            }
        } catch {
            print("⚠️ Failed to check going status: \(error.localizedDescription)")
        }
    }
    
    private func toggleAttending() async {
        // TODO: REMOVE AFTER AUTH IMPLEMENTED - Allow anonymous sign-in for debugging
        var userId: String?
        
        if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
            userId = existingUserId
        } else {
            // Anonymous sign-in for debugging
            do {
                userId = try await FirebaseManager.shared.signInAnonymously()
                print("✅ [DEBUG] Signed in anonymously: \(userId ?? "nil")")
            } catch {
                print("❌ [DEBUG] Failed to sign in anonymously: \(error.localizedDescription)")
                return
            }
        }
        
        guard let userId = userId else {
            print("⚠️ Cannot mark attending - No authenticated user")
            return
        }
        
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Event repository is not FirebaseEventRepository")
            return
        }
        
        await MainActor.run {
            isJoining = true
        }
        
        do {
            // Mark going
            try await firebaseRepo.markSchoolEventGoing(eventId: event.id, userId: userId)
            
            // Fetch updated going count
            let newCount = try await firebaseRepo.getSchoolEventGoingCount(eventId: event.id)
            
            // Keep loading state visible for 0.3 seconds
            try await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                goingCount = newCount
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAttending = true
                    isJoining = false
                }
            }
            
            print("✅ Marked going for school event: \(event.id)")
        } catch {
            print("❌ Failed to toggle school event attendance: \(error.localizedDescription)")
            await MainActor.run {
                isJoining = false
            }
        }
    }
    
    private func shareEvent() {
        // Create share text with event details and deep link to Crowd app
        var shareText = "📅 \(event.title)\n\n"
        
        if let description = event.description {
            shareText += "\(description)\n\n"
        }
        
        if let rawDateTime = event.rawDateTime, !rawDateTime.isEmpty {
            shareText += "When: \(rawDateTime)\n"
        }
        
        if let location = event.rawLocationName, !location.isEmpty {
            shareText += "Where: \(location)\n"
        }
        
        shareText += "\nView on Crowd: \(makeShareLink(event.id))"

        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
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
            
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(activityViewController, animated: true)
        }
    }
}

private func makeShareLink(_ id: String, source: String? = "share") -> String {
    var link = "https://the-crowd-app.com/event/\(id)"
    if let source, !source.isEmpty {
        link += "?src=\(source)"
    }
    return link
}

// MARK: - Parties View
struct PartiesView: View {
    @Environment(\.appEnvironment) var env
    @State private var parties: [CrowdEvent] = []
    @State private var isLoading = false
    @State private var currentPartyIndex: Int = 0
    @State private var scrollPosition: Int? = 0
    @Binding var currentPartyImageURL: String?
    let preloadedParties: [CrowdEvent]?
    let onContinueToSchoolEvents: () -> Void
    
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
                            ForEach(0...parties.count, id: \.self) { index in
                                if index < parties.count {
                                    let party = parties[index]
                                    PartyCardView(party: party)
                                        .frame(width: geometry.size.width - 30)
                                        .frame(height: geometry.size.height)
                                        .containerRelativeFrame(.vertical)
                                        .contentShape(Rectangle())
                                        .id(index)
                                } else {
                                    VStack(spacing: 14) {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        Text("School Events")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(.primary)
                                        Text("Keep scrolling")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: geometry.size.width - 30, height: geometry.size.height)
                                    .containerRelativeFrame(.vertical)
                                    .contentShape(Rectangle())
                                    .id(index)
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 15)
                    }
                    .scrollPosition(id: $scrollPosition)
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear {
            // Use preloaded parties if available, otherwise fetch
            if let preloaded = preloadedParties, !preloaded.isEmpty {
                parties = preloaded
                currentPartyIndex = 0
                currentPartyImageURL = preloaded[0].imageURL
                isLoading = false
                print("✅ Using preloaded parties: \(preloaded.count) parties")
            } else {
                Task {
                    await loadParties()
                }
            }
        }
        .onChange(of: scrollPosition) { oldValue, newValue in
            // Update background image based on the scroll position (which party is visible)
            if let index = newValue, index >= 0 && index < parties.count {
                currentPartyIndex = index
                let party = parties[index]
                currentPartyImageURL = party.imageURL
            } else if newValue == parties.count {
                currentPartyImageURL = nil
                onContinueToSchoolEvents()
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
                guard let date1 = party1.time else { return false }
                guard let date2 = party2.time else { return true }
                return date1 < date2
            }
            
            // Update UI on main thread
            await MainActor.run {
                parties = sortedParties
                currentPartyIndex = 0
                // Initialize with first party image URL
                if !sortedParties.isEmpty {
                    currentPartyImageURL = sortedParties[0].imageURL
                } else {
                    currentPartyImageURL = nil
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
    @State private var goingCount = 0
    @State private var showMoreInfoSheet = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
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
                
                // Buy Ticket Button
                if let ticketURL = party.ticketURL {
                    Button(action: {
                        if let url = normalizeURLString(ticketURL) {
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
                    .padding(.top, 4)
                }
                
                // Button Layout - Split if sourceURL exists, otherwise full width
                if let sourceURL = party.sourceURL {
                    // TWO BUTTONS: Split layout
                    HStack(spacing: 8) {
                        // I'm Attending / Share Button (half width)
                        Button(action: {
                            if !isAttending {
                                Task {
                                    await saveEventToProfile()
                                }
                            } else {
                                shareParty()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if isJoining {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: isAttending ? "square.and.arrow.up" : "hand.thumbsup.fill")
                                        .font(.system(size: 14))
                                    Text(isAttending ? "Share" : "I'm Attending")
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isJoining ? Color.green : Color.blue)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isJoining)
                        
                        // More Info Button (half width)
                        Button(action: {
                            showMoreInfoSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                Text("More Info")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                } else {
                    // ONE BUTTON: Full width layout
                    Button(action: {
                        if !isAttending {
                            Task {
                                await saveEventToProfile()
                            }
                        } else {
                            shareParty()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: isAttending ? "square.and.arrow.up" : "hand.thumbsup.fill")
                                    .font(.system(size: 14))
                                Text(isAttending ? "Share" : "I'm Attending")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isJoining ? Color.green : Color.blue)
                        )
                    }
                    .disabled(isJoining)
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: isIPad ? 500 : 350, minHeight: 450)
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
        .sheet(isPresented: $showMoreInfoSheet) {
            if let sourceURL = party.sourceURL {
                MoreInfoSheetView(sourceURL: sourceURL)
                    .presentationDetents([.large])
            }
        }
        .onAppear {
            // Initialize going count from party.attendeeCount (fetched from Firebase)
            goingCount = party.attendeeCount
            
            // Check if user is already going to this party
            Task {
                guard let userId = FirebaseManager.shared.getCurrentUserId() else {
                    return
                }
                
                guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
                    return
                }
                
                do {
                    let isGoing = try await firebaseRepo.isUserGoingToParty(partyId: party.id, userId: userId)
                    await MainActor.run {
                        isAttending = isGoing
                    }
                } catch {
                    print("⚠️ Failed to check party going status: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    private func saveEventToProfile() async {
        // TODO: REMOVE AFTER AUTH IMPLEMENTED - Allow anonymous sign-in for debugging
        var userId: String?
        
        if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
            userId = existingUserId
        } else {
            // Anonymous sign-in for debugging
            do {
                userId = try await FirebaseManager.shared.signInAnonymously()
                print("✅ [DEBUG] Signed in anonymously: \(userId ?? "nil")")
            } catch {
                print("❌ [DEBUG] Failed to sign in anonymously: \(error.localizedDescription)")
                return
            }
        }
        
        guard let userId = userId else {
            print("⚠️ Cannot save event - No authenticated user")
            return
        }
        
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else {
            print("⚠️ Event repository is not FirebaseEventRepository")
            return
        }
        
        await MainActor.run {
            isJoining = true
        }
        
        do {
            // Mark going in Firebase
            try await firebaseRepo.markPartyGoing(partyId: party.id, userId: userId)
            
            // Fetch updated going count
            let newCount = try await firebaseRepo.getPartyGoingCount(partyId: party.id)
            
            // Keep loading state visible for 0.3 seconds
            try await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                goingCount = newCount
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAttending = true
                    isJoining = false
                }
            }
            
            print("✅ Marked going for party: \(party.id)")
        } catch {
            print("❌ Failed to toggle party attendance: \(error.localizedDescription)")
            await MainActor.run {
                isJoining = false
            }
        }
    }
    
    private func shareParty() {
        // Create share text with party details and deep link to Crowd app
        var shareText = "🎉 \(party.title)\n\n"
        
        if !party.hostName.isEmpty && party.hostName != "Party Host" {
            shareText += "Hosted by: \(party.hostName)\n"
        }
        
        if let description = party.description {
            shareText += "\(description)\n\n"
        }
        
        if let dateTime = party.dateTime, !dateTime.isEmpty {
            shareText += "When: \(dateTime)\n"
        }
        
        if let location = party.rawLocationName, !location.isEmpty {
            shareText += "Where: \(location)\n"
        }
        
        if goingCount > 0 {
            shareText += "\n👥 \(goingCount) going\n"
        }
        
        shareText += "\nView on Crowd: \(makeShareLink(party.id))"
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
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
            
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(activityViewController, animated: true)
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
                    if let url = normalizeURLString("https://calendly.com/your-kickoff-link") {
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

// MARK: - More Info Sheet View
struct MoreInfoSheetView: View {
    let sourceURL: String
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if showError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    Text("Unable to Load")
                        .font(.system(size: 20, weight: .semibold))
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let url = normalizeURLString(sourceURL) {
                SafariView(url: url, onError: { error in
                    errorMessage = error
                    showError = true
                })
                .ignoresSafeArea(.all)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    Text("That link is cooked...")
                        .font(.system(size: 20, weight: .semibold))
                    Text("The URL provided is not valid")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Safari View Controller Wrapper
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let onError: ((String) -> Void)?
    
    init(url: URL, onError: ((String) -> Void)? = nil) {
        self.url = url
        self.onError = onError
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = UIColor.systemBlue
        safariVC.preferredBarTintColor = UIColor.systemBackground
        safariVC.dismissButtonStyle = .close
        safariVC.delegate = context.coordinator
        
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onError: ((String) -> Void)?
        
        init(onError: ((String) -> Void)?) {
            self.onError = onError
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            if !didLoadSuccessfully {
                onError?("The page failed to load. Please check your connection and try again.")
            }
        }
    }
}

#Preview {
    CalenderView()
}
