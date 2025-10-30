//
//  CrowdHomeView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit
import Combine

struct CrowdHomeView: View {
    @Environment(\.appEnvironment) var env
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var locationService = AppEnvironment.current.location
    
    // MARK: - Region & camera
    @State private var selectedRegion: CampusRegion = .mainCampus
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentCamera = MapCamera(
        centerCoordinate: .init(latitude: 33.210081, longitude: -97.147700),
        distance: 1200
    )

    // MARK: - UI state
    @State private var showHostSheet = false
    @State private var hostedEvents: [CrowdEvent] = []
    @State private var officialEvents: [CrowdEvent] = []
    @State private var userEventsFromFirebase: [CrowdEvent] = []
    @State private var upcomingEvents: [CrowdEvent] = []
    @State private var isLoadingEvents = false

    // MARK: - Bottom overlay routing
    enum OverlayRoute { case none, profile, leaderboard }
    @State private var route: OverlayRoute = .none
    @State private var overlayPresented = false
    @State private var overlaySnapIndex = 0 // 0 = peek, 1 = open

    // MARK: - Floating button navigation
    @State private var showCalendar = false
    
    // MARK: - Event detail
    @State private var selectedEvent: CrowdEvent?
    
    // MARK: - Clustering
    @State private var expandedClusterId: String?
    @State private var currentCameraDistance: Double = 1200
    
    // MARK: - Dropdown List State
    @State private var selectedCluster: EventCluster?
    @State private var showClusterDropdown: Bool = false
    
    // MARK: - Source filter (mini navbar)
    private enum SourceFilter { case user, school }
    @State private var sourceFilter: SourceFilter? = nil
    
    // MARK: - Computed
    var allEvents: [CrowdEvent] {
        // Combine all events with deduplication
        // Priority: hostedEvents > userEventsFromFirebase (avoid showing duplicate user events)
        let allUserEvents = mergeUserEvents(local: hostedEvents, firebase: userEventsFromFirebase)
        return officialEvents + allUserEvents + upcomingEvents
    }
    
    /// Merge local and firebase user events, removing duplicates (prefer local version)
    private func mergeUserEvents(local: [CrowdEvent], firebase: [CrowdEvent]) -> [CrowdEvent] {
        let localIds = Set(local.map { $0.id })
        let firebaseUnique = firebase.filter { !localIds.contains($0.id) }
        return local + firebaseUnique
    }
    
    var upcomingEventsInNext2Days: [CrowdEvent] {
        let now = Date()
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now
        
        return upcomingEvents.filter { event in
            guard let startsAt = event.startsAt else { return false }
            return startsAt >= now && startsAt <= twoDaysFromNow
        }
    }
    
    // MARK: - Clustered current events
    var currentEventsClusters: [EventCluster] {
        let calendar = Calendar.current
        let filteredUpcoming = upcomingEvents.filter { ev in
            guard let s = ev.startsAt else { return false }
            return calendar.isDateInToday(s) || calendar.isDateInTomorrow(s)
        }
        
        let inputEvents: [CrowdEvent]
        switch sourceFilter {
        case .user:
            // Only user-created events (local + firebase, deduplicated)
            inputEvents = mergeUserEvents(local: hostedEvents, firebase: userEventsFromFirebase)
        case .school:
            // Only official school events + upcoming school events
            inputEvents = officialEvents + filteredUpcoming
        case .none:
            // All events (deduplicated user events)
            let allUserEvents = mergeUserEvents(local: hostedEvents, firebase: userEventsFromFirebase)
            inputEvents = officialEvents + allUserEvents + filteredUpcoming
        }
        return EventClusteringService.clusterEvents(inputEvents)
    }
    
    // MARK: - Expansion Radius Helper
    private func expansionRadius(for cluster: EventCluster) -> CGFloat {
        switch cluster.eventCount {
        case 1...3: return 35.0   // Tight circle for small clusters
        case 4...6: return 50.0   // Slightly larger for medium
        case 7...9: return 65.0   // Moderate expansion for large
        default: return 80.0      // Max radius for 10+ events
        }
    }
    
    // MARK: - Coordinate Calculation for Expanded Pins
    private func calculateExpandedCoordinate(
        center: CLLocationCoordinate2D,
        angle: Double,
        radiusPoints: CGFloat
    ) -> CLLocationCoordinate2D {
        // Convert screen points to meters based on current zoom
        // Approximate: at camera distance of 1000m, 1 point ≈ 1 meter
        let metersPerPoint = currentCameraDistance / 500.0
        let offsetMeters = Double(radiusPoints) * metersPerPoint
        
        // Convert meters to degrees
        // At equator: 1 degree latitude ≈ 111,000 meters
        // Longitude varies by latitude: 111,000 * cos(latitude)
        let latOffset = (offsetMeters * cos(angle)) / 111000.0
        let lonOffset = (offsetMeters * sin(angle)) / (111000.0 * cos(center.latitude * .pi / 180.0))
        
        return CLLocationCoordinate2D(
            latitude: center.latitude + latOffset,
            longitude: center.longitude + lonOffset
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // === MAP ===
                Map(position: $cameraPosition) {
                    // Clustered event annotations (Firebase + user-created)
                    ForEach(currentEventsClusters) { cluster in
                        if expandedClusterId == cluster.id && cluster.eventCount > 1 {
                            // EXPANDED: Show individual annotations at calculated positions
                            ForEach(Array(cluster.events.enumerated()), id: \.element.id) { index, event in
                                let angle = (2.0 * .pi * Double(index)) / Double(cluster.eventCount)
                                let radius = expansionRadius(for: cluster)
                                let expandedCoord = calculateExpandedCoordinate(
                                    center: cluster.centerCoordinate,
                                    angle: angle,
                                    radiusPoints: radius
                                )
                                // Add stagger delay per pin
                                let staggerDelay = Double(index) * 0.025 // 25ms per pin
                                
                                Annotation("", coordinate: expandedCoord) {
                                    EventAnnotationView(event: event, isInExpandedCluster: true)
                                        .scaleEffect(expandedClusterId == cluster.id ? 1.0 : 0.001)
                                        .opacity(expandedClusterId == cluster.id ? 1.0 : 0.0)
                                        .animation(
                                            .spring(response: 0.35, dampingFraction: 0.8)
                                            .delay(staggerDelay),
                                            value: expandedClusterId
                                        )
                                        .onTapGesture {
                                            print("📍 Expanded event tapped: \(event.title)")
                                            handleEventTap(event)
                                        }
                                }
                                .annotationTitles(.hidden)
                            }
                        } else {
                            // COLLAPSED: Show cluster annotation
                            Annotation("", coordinate: cluster.centerCoordinate) {
                                ClusterAnnotationView(
                                    cluster: cluster,
                                    isExpanded: false,
                                    cameraDistance: currentCameraDistance,
                                    onTap: {
                                        handleClusterTap(cluster)
                                    },
                                    onEventTap: { event in
                                        handleEventTap(event)
                                    }
                                )
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                    
                    // Upcoming events annotations removed per request
                    
                    // User event pin at user's location
                    
                    // User location marker (character icon)
                    if let userLocation = locationService.lastKnown {
                        Annotation("", coordinate: userLocation) {
                            ZStack {
                                // Small dot shadow - rendered first (behind)
                                Circle()
                                    .fill(.primary.opacity(0.4))
                                    .frame(width: 16, height: 16)
                                    .blur(radius: 2)
                                    .offset(x: -30, y: 20)
                                
                                Circle()
                                    .fill(.primary.opacity(0.6))
                                    .frame(width: 10, height: 10)
                                    .offset(x: -30, y: 20)
                                
                                // Character icon - rendered last (in front)
                                Image("UserLocationItem")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .offset(x: -30, y: -2)
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss dropdown or collapse expanded cluster when tapping map background
                    if showClusterDropdown {
                        dismissClusterDropdown()
                    } else if expandedClusterId != nil {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedClusterId = nil
                        }
                        print("📍 Collapsed cluster via background tap")
                    }
                }
                .mapControls { MapCompass() }
                    .ignoresSafeArea()
                    .onAppear { snapTo(selectedRegion) }
                    .onChange(of: selectedRegion) { _, new in snapTo(new) }
                    .onMapCameraChange { ctx in
                        currentCamera = ctx.camera
                        let previousDistance = currentCameraDistance
                        currentCameraDistance = ctx.camera.distance
                        
                        // Auto-collapse expanded clusters when zooming out to distance 3000 or more
                        if expandedClusterId != nil {
                            if currentCameraDistance >= 3000 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    expandedClusterId = nil
                                }
                                print("📍 Auto-collapsed cluster at distance 3000")
                            }
                        }
                        
                        let spec = selectedRegion.spec
                        let clamped = min(max(ctx.camera.distance, spec.minZoom), spec.maxZoom)
                        if abs(clamped - ctx.camera.distance) > 1 {
                            cameraPosition = .camera(
                                MapCamera(
                                    centerCoordinate: ctx.camera.centerCoordinate,
                                    distance: clamped,
                                    heading: ctx.camera.heading,
                                    pitch: ctx.camera.pitch
                                )
                            )
                    }
                }
                
                // === DROPDOWN LIST OVERLAY ===
                if let cluster = selectedCluster, showClusterDropdown {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissClusterDropdown()
                        }
                        .zIndex(998)
                    
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 120)
                        
                        ClusterEventFloatingCard(
                            cluster: cluster,
                            onSelect: { event in
                                Haptics.light()
                                handleEventTap(event)
                                dismissClusterDropdown()
                            },
                            onDismiss: {
                                dismissClusterDropdown()
                            }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .zIndex(999)
                    .allowsHitTesting(true)
                }

                // === OVERLAYS & CONTROLS ===
                GeometryReader { geo in
                    // Panel metrics shared by panel and floating buttons
                    let panelWidth  = min(geo.size.width * 0.84, 520)
                    let panelHeight: CGFloat = 140

                    VStack(spacing: 0) {
                        // === Centered main navbar (region) with smaller Type filter below ===
                        VStack(spacing: 8) {
                            // Main region picker (centered)
                            Menu {
                                ForEach(CampusRegion.allCases) { region in
                                    Button {
                                        selectedRegion = region
                                    } label: {
                                        Text(region.rawValue)
                                            .font(.system(size: 16))
                                    }
                                }
                            } label: {
                                GlassPill(height: 48, horizontalPadding: 20) {
                                    HStack(spacing: 10) {
                                        Text(selectedRegion.displayName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.primary.opacity(0.8))
                                    }
                                    .padding(.horizontal, 12)
                                }
                            }
                            .fixedSize()
                            .frame(maxWidth: geo.size.width * 0.9)

                            // Small type filter (half height of main pill) centered below
                            Menu {
                                Button("User Created Events") { sourceFilter = .user }
                                Button("School Hosted Events") { sourceFilter = .school }
                            } label: {
                                GlassPill(height: 24, horizontalPadding: 14) {
                                    HStack(spacing: 6) {
                                        Text(sourceFilter == .user ? "User Created" : (sourceFilter == .school ? "School Hosted" : "Sort"))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.primary.opacity(0.8))
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                            .fixedSize()
                        }
                        .padding(.top, 0)
                        .offset(y: -18) // raise just the navbar; tweak -10…-28 to taste
                        .zIndex(5)

                        Spacer(minLength: 0)

                        // Bottom frosted panel + FAB cluster
                        ZStack {
                            // Frosted base
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .stroke(.white.opacity(0.12), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
                                .frame(width: panelWidth, height: panelHeight)
                                .allowsHitTesting(false)

                            VStack(spacing: 10) {
                                let fabSize: CGFloat = 72
                                let centerYOffset: CGFloat = -14
                                let spread = panelWidth * 0.35
                                let sideYOffset: CGFloat = panelHeight * 0.16

                                ZStack {
                                    // Center FAB — Host
                                    FABPlusButton(size: fabSize, color: Color(hex: 0x02853E)) {
                                        showHostSheet = true
                                        Haptics.light()
                                    }
                                    .offset(y: centerYOffset)

                                    // Left — Profile (open at 3/4 screen)
                                    FrostedIconButton(
                                        systemName: "person",
                                        baseSize: 54,
                                        targetSize: 72,
                                        frostOpacity: 0.22,
                                        iconBaseColor: .black,
                                        highlightColor: Color(red: 0.63, green: 0.82, blue: 1.0)
                                    ) {
                                        route = .profile
                                        overlaySnapIndex = 1
                                        overlayPresented = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open profile")
                                    .offset(x: -spread, y: sideYOffset)

                                    // Right — Calendar
                                    FrostedIconButton(
                                        systemName: "calendar",
                                        baseSize: 54,
                                        targetSize: 72,
                                        frostOpacity: 0.22,
                                        iconBaseColor: .black,
                                        highlightColor: .blue
                                    ) {
                                        showCalendar = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open calendar")
                                    .offset(x: spread, y: sideYOffset)
                                }

                                Text("Start a Crowd")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.primary.opacity(0.78))
                                    .padding(.top, -8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                    }

                    // === FLOATING GLASS BUTTONS ===
                    VStack(alignment: .trailing, spacing: 16) {
                        // Achievement icon commented out for now
                        // GlassIconButton(systemName: "trophy") { 
                        //     route = .leaderboard
                        //     overlaySnapIndex = 1
                        //     overlayPresented = true
                        // }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 24)
                    // sit above the panel regardless of screen height
                    .padding(.bottom, panelHeight + 28)
                }

                // === BOTTOM SHEET OVER MAP ===
                BottomOverlay(
                    isPresented: $overlayPresented,
                    snapIndex: $overlaySnapIndex,
                    snapFractions: [0.25, 0.75],
                    onDismiss: { route = .none }
                ) {
                    switch route {
                    case .profile:
                        ProfileView(viewModel: ProfileViewModel.mock)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    case .leaderboard:
                        LeaderboardView(viewModel: LeaderboardViewModel())
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                    case .none:
                        EmptyView()
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .onChange(of: route) { _, r in
                    if r == .profile || r == .leaderboard {
                        overlaySnapIndex = 1
                    }
                }
                .fullScreenCover(isPresented: $showCalendar) { CalenderView() }
            }
        }
        .sheet(isPresented: $showHostSheet) {
            HostEventSheet(defaultRegion: selectedRegion) { event in
                Task {
                    do {
                        // Save to Firebase first
                        try await env.eventRepo.create(event: event)
                        print("✅ Event created in Firebase: \(event.id)")
                        
                        // Then add to local array for immediate UI update
                        await MainActor.run {
                            hostedEvents.append(event)
                        }
                    } catch {
                        print("❌ Failed to create event in Firebase: \(error)")
                        // Still add locally so user sees it, but warn about sync
                        await MainActor.run {
                            hostedEvents.append(event)
                        }
                    }
                }
            }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
                .environmentObject(appState)
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
        }
        .task {
            await loadFirebaseEvents()
            await loadUpcomingEvents()
        }
        .onChange(of: selectedRegion) { _, newRegion in
            Task {
                await loadFirebaseEvents(region: newRegion)
            }
        }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
            // Check every 5 minutes to remove events that ended 4+ hours ago
            removeExpiredEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventDeleted)) { notification in
            // Remove deleted event from ALL event arrays
            if let eventId = notification.object as? String {
                hostedEvents.removeAll { $0.id == eventId }
                officialEvents.removeAll { $0.id == eventId }
                userEventsFromFirebase.removeAll { $0.id == eventId }
                upcomingEvents.removeAll { $0.id == eventId }
                
                print("🗑️ Removed deleted event from all arrays: \(eventId)")
                print("   - Current hosted events: \(hostedEvents.count)")
                print("   - Current official events: \(officialEvents.count)")
                print("   - Current user events from Firebase: \(userEventsFromFirebase.count)")
                print("   - Clusters will auto-update with new counts")
                
                // Collapse any expanded cluster that might have contained this event
                if expandedClusterId != nil {
                    withAnimation(.easeOut(duration: 0.3)) {
                        expandedClusterId = nil
                    }
                    print("   - Collapsed expanded cluster")
                }
            }
        }
    }
    
    // MARK: - Firebase Event Loading
    
    private func loadFirebaseEvents(region: CampusRegion? = nil) async {
        let targetRegion = region ?? selectedRegion
        isLoadingEvents = true
        
        do {
            // Use Firebase repository's separate fetch method
            if let firebaseRepo = env.eventRepo as? FirebaseEventRepository {
                let (official, userCreated) = try await firebaseRepo.fetchEventsSeparately(in: targetRegion)
                await MainActor.run {
                    officialEvents = official
                    userEventsFromFirebase = userCreated
                    isLoadingEvents = false
                    print("✅ Loaded \(official.count) official events and \(userCreated.count) user-created events from Firebase")
                }
            } else {
                // Fallback for mock repository or other implementations
                let events = try await env.eventRepo.fetchEvents(in: targetRegion)
                await MainActor.run {
                    officialEvents = events
                    userEventsFromFirebase = []
                    isLoadingEvents = false
                    print("✅ Loaded \(events.count) events from repository (using fallback)")
                }
            }
        } catch {
            await MainActor.run {
                officialEvents = []
                userEventsFromFirebase = []
                isLoadingEvents = false
                print("❌ Failed to load Firebase events: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Upcoming Events Loading
    
    private func loadUpcomingEvents() async {
        // Load upcoming events from CampusEventsViewModel (existing 14-day feed)
        let campusEventsVM = CampusEventsViewModel()
        campusEventsVM.start()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            upcomingEvents = campusEventsVM.crowdEvents
            print("✅ Loaded \(upcomingEvents.count) upcoming events")
        }
        campusEventsVM.stop()
    }
    
    // MARK: - Event Cleanup
    
    private func removeExpiredEvents() {
        let now = Date()
        let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
        
        // Remove events that ended more than 4 hours ago
        upcomingEvents.removeAll { event in
            guard let endsAt = event.endsAt else { return false }
            return endsAt < fourHoursAgo
        }
        
        officialEvents.removeAll { event in
            guard let endsAt = event.endsAt else { return false }
            return endsAt < fourHoursAgo
        }
        
        userEventsFromFirebase.removeAll { event in
            guard let endsAt = event.endsAt else { return false }
            return endsAt < fourHoursAgo
        }
        
        hostedEvents.removeAll { event in
            guard let endsAt = event.endsAt else { return false }
            return endsAt < fourHoursAgo
        }
    }

    // MARK: - Camera snap helper
    private func snapTo(_ region: CampusRegion) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = MapCameraController.position(from: region.spec)
        }
    }
    
    // MARK: - Cluster Handlers
    private func handleClusterTap(_ cluster: EventCluster) {
        print("🎯 handleClusterTap called - isSingleEvent: \(cluster.isSingleEvent), count: \(cluster.eventCount)")
        if cluster.isSingleEvent {
            // Single event - show detail directly
            if let event = cluster.events.first {
                print("✅ Showing detail for single event: \(event.title)")
                selectedEvent = event
            }
        } else {
            // Multi-event cluster - show dropdown list (NO ZOOM)
            print("📋 Showing dropdown for \(cluster.eventCount) events")
            Haptics.light()
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedCluster = cluster
                showClusterDropdown = true
                // Clear any expanded state
                expandedClusterId = nil
            }
        }
    }
    
    private func dismissClusterDropdown() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showClusterDropdown = false
            selectedCluster = nil
        }
    }
    
    private func handleEventTap(_ event: CrowdEvent) {
        print("✅ handleEventTap called for: \(event.title)")
        selectedEvent = event
    }
}

// MARK: - Tiny haptics helper
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Reusable Bottom Overlay
private struct BottomOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @Binding var snapIndex: Int                 // 0 = peek, 1 = open
    var snapFractions: [CGFloat] = [0.35, 0.70] // of available height
    var onDismiss: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @State private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let totalH = geo.size.height
            let peekH  = totalH * (snapFractions[safe: 0] ?? 0.35)
            let openH  = totalH * (snapFractions[safe: 1] ?? 0.70)
            let targets = [peekH, openH]

            if isPresented {
                Color.black
                    .opacity(backdropOpacity(targets: targets))
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .accessibilityLabel("Close")
            }

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.primary.opacity(0.35))
                    .frame(width: 36, height: 6)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                content()
                    .padding(.bottom, 16)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
            .frame(height: currentHeight(targets: targets))
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: isPresented ? 0 : totalH)
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.15), value: isPresented)
            .gesture(dragGesture(targets: targets))
            .onChange(of: isPresented) { _, new in
                if !new { translation = 0 }
            }
        }
        .allowsHitTesting(isPresented)
        .accessibilityAddTraits(.isModal)
    }

    private func currentHeight(targets: [CGFloat]) -> CGFloat {
        guard isPresented else { return 0 }
        let base = targets[clamped: snapIndex]
        return max(0, base - translation)
    }

    private func dragGesture(targets: [CGFloat]) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let dy = value.translation.height
                translation = max(0, dy)
            }
            .onEnded { _ in
                defer { translation = 0 }
                let base = targets[clamped: snapIndex]
                if translation > base * 0.4 {
                    if snapIndex == 0 {
                        dismiss()
                    } else {
                        snapIndex = max(0, snapIndex - 1)
                    }
                } else {
                    snapIndex = min(snapIndex + 1, targets.count - 1)
                }
                Haptics.light()
            }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.95)) {
            isPresented = false
        }
        onDismiss()
    }

    private func backdropOpacity(targets: [CGFloat]) -> Double {
        guard isPresented else { return 0 }
        let open = (targets.last ?? 1)
        let visible = min(1, currentHeight(targets: targets) / open)
        return Double(0.45 * visible)
    }
}

// MARK: - Safe indexing helpers
private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        indices.contains(index) ? self[index] : nil
    }
    subscript(clamped index: Int) -> CGFloat {
        if isEmpty { return 0 }
        return self[Swift.max(0, Swift.min(index, count - 1))]
    }
}

// MARK: - Heatmap Layers
struct HeatmapLayers: MapContent {
    let event: CrowdEvent
    var opacity: Double = 1.0
    
    var body: some MapContent {
        // Radius grows by 10% per attendee
        let radiusMultiplier = pow(1.10, Double(event.attendeeCount))
        // Intensity grows by 5% per attendee
        let intensityMultiplier = pow(1.05, Double(event.attendeeCount))
        
        let baseRadius: Double = 100
        let baseIntensity: Double = 0.3
        let intensity = min(baseIntensity * intensityMultiplier, 1.0)
        let radius = baseRadius * radiusMultiplier
        
        // Layer 1: Outer glow (largest, most transparent)
        MapCircle(center: event.coordinates, radius: CLLocationDistance(radius * 1.8))
            .foregroundStyle(
                .radialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.8, blue: 0.0).opacity(intensity * 0.15 * opacity),
                        Color(red: 1.0, green: 0.9, blue: 0.2).opacity(intensity * 0.08 * opacity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius * 1.8
                )
            )
        
        // Layer 2: Middle gradient
        MapCircle(center: event.coordinates, radius: CLLocationDistance(radius * 1.2))
            .foregroundStyle(
                .radialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.5, blue: 0.0).opacity(intensity * 0.35 * opacity),
                        Color(red: 1.0, green: 0.7, blue: 0.0).opacity(intensity * 0.25 * opacity),
                        Color(red: 1.0, green: 0.85, blue: 0.0).opacity(intensity * 0.12 * opacity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius * 1.2
                )
            )
        
        // Layer 3: Hot center (smallest, most intense)
        MapCircle(center: event.coordinates, radius: CLLocationDistance(radius * 0.6))
            .foregroundStyle(
                .radialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.0, blue: 0.0).opacity(intensity * 0.65 * opacity),
                        Color(red: 1.0, green: 0.3, blue: 0.0).opacity(intensity * 0.45 * opacity),
                        Color(red: 1.0, green: 0.6, blue: 0.0).opacity(intensity * 0.25 * opacity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius * 0.6
                )
            )
    }
}

// MARK: - Upcoming Event Annotation View
struct UpcomingEventAnnotationView: View {
    let event: CrowdEvent
    
    var body: some View {
        ZStack {
            // Outer glow for upcoming events
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 60, height: 60)
                .blur(radius: 4)
            
            // Main circle
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Calendar icon
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Chat Message Model
#Preview {
    CrowdHomeView()
        .environmentObject(AppState())
}
