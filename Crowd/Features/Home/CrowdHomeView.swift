//
//  CrowdHomeView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit
import Combine
import FirebaseFirestore
import FirebaseAuth

struct CrowdHomeView: View {
    @Environment(\.appEnvironment) var env
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @ObservedObject private var locationService = AppEnvironment.current.location
    @ObservedObject private var chatNotificationService = ChatNotificationService.shared
    @ObservedObject private var campusEventsVM = CampusEventsViewModel.shared
    
    // MARK: - Onboarding & Campus Selection
    @AppStorage("selectedCampusId") private var selectedCampusId: String = "UNT"
    @AppStorage("hasCompletedPartiesOnboarding") private var hasCompletedPartiesOnboarding: Bool = false
    
    // MARK: - Region & camera
    @State private var selectedRegion: CampusRegion = .mainCampus
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentCamera = MapCamera(
        centerCoordinate: .init(latitude: 33.210081, longitude: -97.147700),
        distance: 1200
    )

    // MARK: - UI state
    @State private var showHostSheet = false
    @State private var showSparkCard = false
    @State private var hostedEvents: [CrowdEvent] = []
    @State private var officialEvents: [CrowdEvent] = []
    @State private var userEventsFromFirebase: [CrowdEvent] = []
    @State private var upcomingEvents: [CrowdEvent] = []
    @State private var isLoadingEvents = false
    
    // MARK: - Confetti celebration
    @State private var showConfetti = false

    // MARK: - Bottom overlay routing
    enum OverlayRoute { case none, profile, leaderboard }
    @State private var route: OverlayRoute = .none
    @State private var overlayPresented = false
    @State private var overlaySnapIndex = 0 // 0 = peek, 1 = open

    // MARK: - Floating button navigation
    @State private var showCalendar = false
    
    // MARK: - Event detail
    @State private var selectedEvent: CrowdEvent?
    
    // MARK: - Tutorial
    @State private var showTutorialOverlay = false
    
    // MARK: - Clustering
    @State private var expandedClusterId: String?
    @State private var currentCameraDistance: Double = 1200
    
    // MARK: - Dropdown List State
    @State private var selectedCluster: EventCluster?
    @State private var showClusterDropdown: Bool = false
    
    // MARK: - Event Search
    @State private var searchText: String = ""
    @State private var showSearchResults: Bool = false
    @State private var initialEventTitle: String? = nil
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Joined Event Indicator
    @State private var liveAttendeeCount: Int = 0
    @State private var eventListener: ListenerRegistration?
    @State private var showNavigationModal = false
    
    // MARK: - Anchors
    @StateObject private var anchorService = AnchorService.shared
    @State private var selectedAnchor: Anchor?
    @State private var showAnchorNavigationModal = false
    @State private var expandedAnchorGroupId: String? = nil // Track which anchor group is expanded
    @State private var expandedCombinedGroupId: String? = nil // Track which combined anchor+event group is expanded
    
    // MARK: - New Event Banner
    @State private var newEventBanner: CrowdEvent? = nil
    @State private var seenEventIds: Set<String> = []
    @State private var newEventListeners: [ListenerRegistration] = []
    @State private var bannerDismissTimer: Timer? = nil
    @State private var initializedListenerCount = 0
    
    // MARK: - Event End Timer
    @State private var eventEndCheckTimer: Timer? = nil
    
    // MARK: - Visibility State
    @State private var visibleUsers: [UserProfile] = []
    @State private var visibleUsersListener: ListenerRegistration?
    @State private var selectedUserProfile: UserProfile? // For showing user profile sheet
    @State private var showVisibilityInfo = false // Show info sheet on first visibility toggle
    @AppStorage("hasSeenVisibilityInfo") private var hasSeenVisibilityInfo = false
    @AppStorage("hasSeenVisibilityUserAnnotationOnboarding") private var hasSeenVisibilityUserAnnotationOnboarding = false
    @State private var showVisibilityUserAnnotationOnboarding = false
    @State private var isFadingOutAnnotations = false
    
    private var anchorsToDisplay: [Anchor] {
        anchorService.activeAnchors
    }
    
    // Group anchors by location (same coordinates)
    private func groupAnchorsByLocation(_ anchors: [Anchor]) -> [[Anchor]] {
        var groups: [[Anchor]] = []
        var processedIds = Set<String>()
        
        for anchor in anchors {
            guard let coord = anchor.coordinates, !processedIds.contains(anchor.id) else {
                continue
            }
            
            // Find all anchors at the same location (within 5 meters)
            var group: [Anchor] = [anchor]
            processedIds.insert(anchor.id)
            
            for otherAnchor in anchors {
                guard let otherCoord = otherAnchor.coordinates,
                      !processedIds.contains(otherAnchor.id) else { continue }
                
                let location1 = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let location2 = CLLocation(latitude: otherCoord.latitude, longitude: otherCoord.longitude)
                let distance = location1.distance(from: location2)
                
                if distance <= 5.0 { // Same location threshold
                    group.append(otherAnchor)
                    processedIds.insert(otherAnchor.id)
                }
            }
            
            groups.append(group)
        }
        
        return groups
    }
    
    // Generate a unique ID for an anchor group based on its center coordinates
    private func anchorGroupId(for group: [Anchor]) -> String {
        guard let firstAnchor = group.first,
              let coord = firstAnchor.coordinates else {
            return UUID().uuidString
        }
        // Use coordinates rounded to 6 decimal places as group ID
        return "\(String(format: "%.6f", coord.latitude))_\(String(format: "%.6f", coord.longitude))"
    }
    
    // Check if an anchor group overlaps with an event cluster (within 5 meters)
    private func anchorGroupOverlapsCluster(_ anchorGroup: [Anchor], _ cluster: EventCluster) -> Bool {
        guard let anchorCoord = anchorGroup.first?.coordinates else { return false }
        let location1 = CLLocation(latitude: anchorCoord.latitude, longitude: anchorCoord.longitude)
        let location2 = CLLocation(latitude: cluster.centerCoordinate.latitude, longitude: cluster.centerCoordinate.longitude)
        let distance = location1.distance(from: location2)
        return distance <= 5.0
    }
    
    // Generate a unique ID for a combined group (anchors + events)
    private func combinedGroupId(anchorGroup: [Anchor], cluster: EventCluster) -> String {
        guard let anchorCoord = anchorGroup.first?.coordinates else {
            return "combined_\(cluster.id)"
        }
        return "combined_\(String(format: "%.6f", anchorCoord.latitude))_\(String(format: "%.6f", anchorCoord.longitude))"
    }
    
    // Calculate expanded coordinate for anchor in a combined group
    private func expandedAnchorCoordinateInCombined(
        anchor: Anchor,
        anchorGroup: [Anchor],
        cluster: EventCluster,
        center: CLLocationCoordinate2D,
        groupId: String
    ) -> CLLocationCoordinate2D {
        guard expandedCombinedGroupId == groupId else {
            return center
        }
        
        guard let index = anchorGroup.firstIndex(where: { $0.id == anchor.id }) else {
            return center
        }
        
        // Position anchors on the left side, events on the right
        let totalItems = anchorGroup.count + cluster.eventCount
        let spacingMeters: Double = 250.0
        let totalWidth = Double(totalItems - 1) * spacingMeters
        let startOffset = -totalWidth / 2.0
        let anchorOffset = startOffset + (Double(index) * spacingMeters)
        
        let lonOffset = anchorOffset / (111000.0 * cos(center.latitude * .pi / 180.0))
        
        return CLLocationCoordinate2D(
            latitude: center.latitude,
            longitude: center.longitude + lonOffset
        )
    }
    
    // Calculate expanded coordinate for event in a combined group
    private func expandedEventCoordinateInCombined(
        event: CrowdEvent,
        anchorGroup: [Anchor],
        cluster: EventCluster,
        center: CLLocationCoordinate2D,
        groupId: String
    ) -> CLLocationCoordinate2D {
        guard expandedCombinedGroupId == groupId else {
            return center
        }
        
        guard let index = cluster.events.firstIndex(where: { $0.id == event.id }) else {
            return center
        }
        
        // Position anchors on the left side, events on the right
        let totalItems = anchorGroup.count + cluster.eventCount
        let spacingMeters: Double = 250.0
        let totalWidth = Double(totalItems - 1) * spacingMeters
        let startOffset = -totalWidth / 2.0
        let eventOffset = startOffset + (Double(anchorGroup.count + index) * spacingMeters)
        
        let lonOffset = eventOffset / (111000.0 * cos(center.latitude * .pi / 180.0))
        
        return CLLocationCoordinate2D(
            latitude: center.latitude,
            longitude: center.longitude + lonOffset
        )
    }
    
    // Calculate expanded coordinate for anchor in a group
    private func expandedAnchorCoordinate(
        anchor: Anchor,
        group: [Anchor],
        center: CLLocationCoordinate2D,
        groupId: String
    ) -> CLLocationCoordinate2D {
        // Only expand if this group is selected/expanded
        guard group.count > 1, expandedAnchorGroupId == groupId else {
            return center
        }
        
        guard let index = group.firstIndex(where: { $0.id == anchor.id }) else {
            return center
        }
        
        // Fixed spacing when expanded (250 meters between anchors)
        let spacingMeters: Double = 250.0
        
        let totalWidth = Double(group.count - 1) * spacingMeters
        let startOffset = -totalWidth / 2.0
        let anchorOffset = startOffset + (Double(index) * spacingMeters)
        
        // Convert meters to degrees (longitude offset)
        let lonOffset = anchorOffset / (111000.0 * cos(center.latitude * .pi / 180.0))
        
        return CLLocationCoordinate2D(
            latitude: center.latitude,
            longitude: center.longitude + lonOffset
        )
    }
    
    // MARK: - Moderation State
    @State private var blockedUserIds: Set<String> = []
    @State private var hiddenEventIds: Set<String> = []
    @State private var bannedUserIds: Set<String> = []
    
    // MARK: - Computed
    var allEvents: [CrowdEvent] {
        let now = Date()
        // Combine all events with deduplication
        // Priority: hostedEvents > userEventsFromFirebase (avoid showing duplicate user events)
        let allUserEvents = mergeUserEvents(local: hostedEvents, firebase: userEventsFromFirebase)
        let combined = officialEvents + allUserEvents + upcomingEvents
        
        // Filter out expired events (events that have ended)
        let activeEvents = combined.filter { event in
            guard let time = event.time else { return true }
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time >= fourHoursAgo
        }
        
        // Filter out blocked/hidden/banned/objectionable content
        return activeEvents.filter { event in
            !ContentModerationService.shared.shouldFilterEvent(
                event,
                blockedUserIds: blockedUserIds,
                hiddenEventIds: hiddenEventIds,
                bannedUserIds: bannedUserIds
            )
        }
    }
    
    var currentEventsClusters: [EventCluster] {
        EventClusteringService.clusterEvents(allEvents)
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
            guard let time = event.time else { return false }
            return time >= now && time <= twoDaysFromNow
        }
    }
    
    private var locationCoordinateString: String {
        guard let location = locationService.lastKnown else { return "" }
        return "\(location.latitude),\(location.longitude)"
    }
    
    // MARK: - Filtered Events for Search
    var filteredEvents: [CrowdEvent] {
        guard !searchText.isEmpty else { return [] }
        let todayEvents = filterEventsForToday(allEvents)
        return todayEvents.filter { event in
            event.title.lowercased().contains(searchText.lowercased())
        }
    }
    
    // MARK: - Helper: Filter events to today only and not ended
    private func filterEventsForToday(_ events: [CrowdEvent]) -> [CrowdEvent] {
        let calendar = Calendar.current
        let now = Date()
        
        let filtered = events.filter { event in
            // Check if event time is today
            if let time = event.time {
                // Check if time was more than 4 hours ago
                let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
                if time < fourHoursAgo {
                    return false
                }
                // Check if time is today
                return calendar.isDateInToday(time)
            }
            
            // If no time info, include events created today (for user-created events)
            return calendar.isDateInToday(event.createdAt)
        }
        return filtered
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

    // MARK: - Map Content Helpers
    private func expandedClusterAnnotations(cluster: EventCluster) -> some MapContent {
        ForEach(Array(cluster.events.enumerated()), id: \.element.id) { index, event in
            let angle = (2.0 * .pi * Double(index)) / Double(cluster.eventCount)
            let radius = expansionRadius(for: cluster)
            let expandedCoord = calculateExpandedCoordinate(
                center: cluster.centerCoordinate,
                angle: angle,
                radiusPoints: radius
            )
            let staggerDelay = Double(index) * 0.025
            
            Annotation("", coordinate: expandedCoord) {
                EventAnnotationView(
                    event: event,
                    isInExpandedCluster: true,
                    currentUserId: FirebaseManager.shared.getCurrentUserId()
                )
                .scaleEffect(expandedClusterId == cluster.id ? 1.0 : 0.001)
                .opacity(expandedClusterId == cluster.id ? 1.0 : 0.0)
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.8)
                    .delay(staggerDelay),
                    value: expandedClusterId
                )
                .zIndex(selectedEvent?.id == event.id ? 200 : 10)
                .onTapGesture {
                    handleEventTap(event)
                }
            }
            .annotationTitles(.hidden)
        }
    }
    
    private func collapsedClusterAnnotation(cluster: EventCluster) -> some MapContent {
        let hasSelectedEvent = cluster.events.contains { $0.id == selectedEvent?.id }
        return Annotation("", coordinate: cluster.centerCoordinate) {
            ClusterAnnotationView(
                cluster: cluster,
                isExpanded: false,
                cameraDistance: currentCameraDistance,
                onTap: {
                    handleClusterTap(cluster)
                },
                onEventTap: { event in
                    handleEventTap(event)
                },
                currentUserId: FirebaseManager.shared.getCurrentUserId()
            )
            .zIndex(hasSelectedEvent ? 200 : 10)
        }
        .annotationTitles(.hidden)
    }
    
    private func userLocationAnnotation(coordinate: CLLocationCoordinate2D) -> some MapContent {
        Annotation("", coordinate: coordinate) {
            Button(action: {
                // Show user's own profile when tapped in visibility mode
                if appState.isVisible, let userProfile = appState.sessionUser {
                    selectedUserProfile = userProfile
                }
            }) {
                ZStack(alignment: .center) {
                    // Highlight circle for user's own annotation when onboarding is shown
                    if appState.isVisible && showVisibilityUserAnnotationOnboarding {
                        Circle()
                            .stroke(Color(hex: 0xff8a00), lineWidth: 3)
                            .frame(width: 80, height: 80)
                            .offset(x: -30, y: -2)
                            .zIndex(1)
                    }
                    
                    // Blue pulse ring (only in visibility mode)
                    if appState.isVisible {
                        LottiePulse(size: 60)
                            .offset(x: -30, y: 20)
                    } else {
                        // Dark shadow (when not visible)
                        Circle()
                            .fill(.primary.opacity(0.4))
                            .frame(width: 16, height: 16)
                            .blur(radius: 2)
                            .offset(x: -30, y: 20)
                        
                        Circle()
                            .fill(.primary.opacity(0.6))
                            .frame(width: 10, height: 10)
                            .offset(x: -30, y: 20)
                    }
                    
                    Image("UserLocationItem")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .offset(x: -30, y: -2)
                }
                .animation(.easeInOut(duration: 0.3), value: showVisibilityUserAnnotationOnboarding)
                .frame(width: 70, height: 70)
                .contentShape(Rectangle())
                .onAppear {
                    print("🎯 DEBUG: User annotation rendered at (\(coordinate.latitude), \(coordinate.longitude)), visible mode: \(appState.isVisible)")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!appState.isVisible)
        }
        .annotationTitles(.hidden)
    }
    
    private func otherUserAnnotation(coordinate: CLLocationCoordinate2D) -> some MapContent {
        Annotation("", coordinate: coordinate) {
            ZStack(alignment: .center) {
                Circle()
                    .fill(.primary.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .blur(radius: 2)
                    .offset(x: -30, y: 20)
                
                Circle()
                    .fill(.primary.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .offset(x: -30, y: 20)
                
                Image("OtherUsersLocation")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .offset(x: -30, y: -2)
            }
        }
        .annotationTitles(.hidden)
    }
    
    private var untEvent: CrowdEvent {
        let farFutureDate = Calendar.current.date(byAdding: .year, value: 100, to: Date()) ?? Date()
        return CrowdEvent(
            id: "UNT",
            title: "University of North Texas",
            hostId: "UNT",
            hostName: "UNT",
            latitude: 33.21264835416883,
            longitude: -97.14748405043815,
            radiusMeters: 1000,
            time: nil,
            startTime: Date(),
            endTime: farFutureDate,
            createdAt: Date(),
            signalStrength: 100,
            attendeeCount: 0,
            tags: ["campus", "unt"],
            category: "campus",
            description: "UNT Campus",
            sourceURL: nil,
            rawLocationName: "1155 Union Circle, Denton, TX",
            imageURL: nil,
            ticketURL: nil,
            dateTime: nil,
            rawDateTime: nil
        )
    }
    
    private func handleUntTap() {
        appState.currentJoinedEvent = untEvent
        showNavigationModal = true
    }
    
    private func untLocationAnnotation() -> some MapContent {
        let untCoordinate = CLLocationCoordinate2D(
            latitude: 33.21264835416883,
            longitude: -97.14748405043815
        )
        return Annotation("", coordinate: untCoordinate) {
            Button(action: {
                handleUntTap()
            }) {
                UNTLogoPinView(size: 60)
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(200)
        }
        .annotationTitles(.hidden)
    }
    
    // Helper struct to represent combined groups for rendering
    // Commented out temporarily - starts here
    
    
    func expandedAnchorAnnotations(group: [Anchor], center: CLLocationCoordinate2D, groupId: String) -> some MapContent {
        ForEach(Array(group), id: \.id) { anchor in
            let displayCoord = expandedAnchorCoordinate(
                anchor: anchor,
                group: group,
                center: center,
                groupId: groupId
            )
            
            Annotation("", coordinate: displayCoord) {
                AnchorAnnotationView(
                    anchor: anchor,
                    onTap: {
                        handleAnchorTap(anchor)
                    }
                )
            }
            .annotationTitles(.hidden)
        }
    }
    
    func collapsedAnchorAnnotation(anchor: Anchor, count: Int?, center: CLLocationCoordinate2D, group: [Anchor], groupId: String) -> some MapContent {
        Annotation("", coordinate: center) {
            AnchorAnnotationView(
                anchor: anchor,
                count: count,
                onTap: {
                    handleAnchorGroupTap(group: group, groupId: groupId)
                }
            )
        }
        .annotationTitles(.hidden)
    }
    
    @MapContentBuilder
    func anchorGroupAnnotations(group: [Anchor]) -> some MapContent {
        if let firstAnchor = group.first,
           let centerCoord = firstAnchor.coordinates {
            let groupId = anchorGroupId(for: group)
            let isExpanded = expandedAnchorGroupId == groupId
            
            if isExpanded && group.count > 1 {
                expandedAnchorAnnotations(group: group, center: centerCoord, groupId: groupId)
            } else {
                collapsedAnchorAnnotation(
                    anchor: firstAnchor,
                    count: group.count > 1 ? group.count : nil,
                    center: centerCoord,
                    group: group,
                    groupId: groupId
                )
            }
        }
    }
    
    
    struct CombinedGroup: Identifiable {
        let id: String
        let anchorGroup: [Anchor]
        let cluster: EventCluster
        let center: CLLocationCoordinate2D
    }
    
    // Helper struct to represent standalone anchor groups
    struct StandaloneAnchorGroup: Identifiable {
        let id: String
        let group: [Anchor]
    }
    
    // Compute combined groups and standalone groups
    var combinedGroups: [CombinedGroup] {
        let anchorGroups = groupAnchorsByLocation(anchorsToDisplay)
        let clusters = currentEventsClusters
        var processedClusters = Set<String>()
        var result: [CombinedGroup] = []
        
        for anchorGroup in anchorGroups {
            guard let anchorCoord = anchorGroup.first?.coordinates else { continue }
            
            for cluster in clusters {
                if !processedClusters.contains(cluster.id) && anchorGroupOverlapsCluster(anchorGroup, cluster) {
                    let groupId = combinedGroupId(anchorGroup: anchorGroup, cluster: cluster)
                    result.append(CombinedGroup(
                        id: groupId,
                        anchorGroup: anchorGroup,
                        cluster: cluster,
                        center: anchorCoord
                    ))
                    processedClusters.insert(cluster.id)
                    break
                }
            }
        }
        
        return result
    }
    
    // Compute standalone anchor groups (not overlapping with clusters)
    var standaloneAnchorGroups: [StandaloneAnchorGroup] {
        let anchorGroups = groupAnchorsByLocation(anchorsToDisplay)
        let clusters = currentEventsClusters
        var processedAnchorIndices = Set<Int>()
        
        // Mark anchor groups that are part of combined groups
        for (index, anchorGroup) in anchorGroups.enumerated() {
            guard let anchorCoord = anchorGroup.first?.coordinates else { continue }
            
            for cluster in clusters {
                if anchorGroupOverlapsCluster(anchorGroup, cluster) {
                    processedAnchorIndices.insert(index)
                    break
                }
            }
        }
        
        // Return standalone groups
        let standalone: [StandaloneAnchorGroup] = anchorGroups.enumerated().compactMap { (index, group) -> StandaloneAnchorGroup? in
            if processedAnchorIndices.contains(index) {
                return nil
            }
            let groupId = anchorGroupId(for: group)
            return StandaloneAnchorGroup(id: groupId, group: group)
        }
        
        return standalone
    }
    
    @MapContentBuilder
    private func anchorAnnotations() -> some MapContent {
        // Render combined groups (anchors + events at same location)
        ForEach(combinedGroups) { combinedGroup in
            let isExpanded = expandedCombinedGroupId == combinedGroup.id
            
            if isExpanded {
                combinedGroupExpandedAnnotations(
                    anchorGroup: combinedGroup.anchorGroup,
                    cluster: combinedGroup.cluster,
                    center: combinedGroup.center,
                    groupId: combinedGroup.id
                )
            } else {
                combinedGroupCollapsedAnnotation(
                    anchorGroup: combinedGroup.anchorGroup,
                    cluster: combinedGroup.cluster,
                    center: combinedGroup.center,
                    groupId: combinedGroup.id
                )
            }
        }
        
        // Render standalone anchor groups (not overlapping with clusters)
        ForEach(standaloneAnchorGroups) { standaloneGroup in
            anchorGroupAnnotations(group: standaloneGroup.group)
        }
    }
    
    @MapContentBuilder
    func combinedGroupExpandedAnnotations(
        anchorGroup: [Anchor],
        cluster: EventCluster,
        center: CLLocationCoordinate2D,
        groupId: String
    ) -> some MapContent {
        // Render expanded anchors
        ForEach(Array(anchorGroup), id: \.id) { anchor in
            let displayCoord = self.expandedAnchorCoordinateInCombined(
                anchor: anchor,
                anchorGroup: anchorGroup,
                cluster: cluster,
                center: center,
                groupId: groupId
            )
            
            Annotation("", coordinate: displayCoord) {
                AnchorAnnotationView(
                    anchor: anchor,
                    onTap: {
                        self.handleAnchorTap(anchor)
                    }
                )
                .zIndex(selectedAnchor?.id == anchor.id ? 200 : 10)
            }
            .annotationTitles(.hidden)
        }
        
        // Render expanded events
        ForEach(Array(cluster.events), id: \.id) { event in
            let displayCoord = self.expandedEventCoordinateInCombined(
                event: event,
                anchorGroup: anchorGroup,
                cluster: cluster,
                center: center,
                groupId: groupId
            )
            
            Annotation("", coordinate: displayCoord) {
                EventAnnotationView(
                    event: event,
                    isInExpandedCluster: true,
                    currentUserId: FirebaseManager.shared.getCurrentUserId()
                )
                .zIndex(selectedEvent?.id == event.id ? 200 : 10)
                .onTapGesture {
                    self.handleEventTap(event)
                }
            }
            .annotationTitles(.hidden)
        }
    }
    
    @MapContentBuilder
    func combinedGroupCollapsedAnnotation(
        anchorGroup: [Anchor],
        cluster: EventCluster,
        center: CLLocationCoordinate2D,
        groupId: String
    ) -> some MapContent {
        // Show anchor annotation with count indicator for both anchors and events
        if let firstAnchor = anchorGroup.first {
            let totalCount = anchorGroup.count + cluster.eventCount
            Annotation("", coordinate: center) {
                AnchorAnnotationView(
                    anchor: firstAnchor,
                    count: totalCount > 1 ? totalCount : nil,
                    onTap: {
                        self.handleCombinedGroupTap(anchorGroup: anchorGroup, cluster: cluster, groupId: groupId)
                    }
                )
            }
            .annotationTitles(.hidden)
        }
    }
    
    // Compute clusters that don't overlap with anchors
    private var standaloneClusters: [EventCluster] {
        // Use pre-geocoded today's events from CampusEventsViewModel for fast map display
        // Also include today's user-created events
        let allUserEvents = mergeUserEvents(local: hostedEvents, firebase: userEventsFromFirebase)
        let todayUserEvents = filterEventsForToday(allUserEvents)
        let todayEvents = campusEventsVM.todaysEvents + todayUserEvents
        // Filter out events at default coordinates until geocoding completes
        let geocodedEvents = todayEvents.filter { event in
            !(event.latitude == 33.2100 && event.longitude == -97.1500)
        }
        let clusters = EventClusteringService.clusterEvents(geocodedEvents)
        print("📍 DEBUG: standaloneClusters computed - \(clusters.count) clusters (\(geocodedEvents.count) geocoded of \(todayEvents.count) total)")
        for (index, cluster) in clusters.enumerated().prefix(5) {
            print("   Cluster \(index): \(cluster.eventCount) events at (\(cluster.centerCoordinate.latitude), \(cluster.centerCoordinate.longitude))")
        }
        
        // Filter out clusters that overlap with anchors (they'll be handled by combined groups)
        let anchorGroups = groupAnchorsByLocation(anchorsToDisplay)
        var processedClusters = Set<String>()
        
        // Mark clusters that overlap with anchors
        for anchorGroup in anchorGroups {
            guard anchorGroup.first?.coordinates != nil else { continue }
            for cluster in clusters {
                if anchorGroupOverlapsCluster(anchorGroup, cluster) {
                    processedClusters.insert(cluster.id)
                }
            }
        }
        
        // Return clusters that don't overlap with anchors
        return clusters.filter { !processedClusters.contains($0.id) }
    }
    
    // MARK: - Map View
    private var mapView: some View {
        return Map(position: $cameraPosition) {
            // Event clusters (rendered first, but skip ones that overlap with anchors)
            ForEach(standaloneClusters) { cluster in
                if expandedClusterId == cluster.id && cluster.eventCount > 1 {
                    expandedClusterAnnotations(cluster: cluster)
                } else {
                    collapsedClusterAnnotation(cluster: cluster)
                }
            }
            
            // Anchor annotations (includes combined groups)
            anchorAnnotations()
            
            // UNT location annotation
            untLocationAnnotation()
            
            // Other visible users annotations (only when visibility is enabled or fading out)
            if appState.isVisible || isFadingOutAnnotations {
                ForEach(visibleUsers) { user in
                    if let latitude = user.latitude, let longitude = user.longitude {
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        Annotation("", coordinate: coordinate) {
                            Button(action: {
                                selectedUserProfile = user
                            }) {
                                ZStack(alignment: .center) {
                                    Circle()
                                        .fill(.primary.opacity(0.4))
                                        .frame(width: 16, height: 16)
                                        .blur(radius: 2)
                                        .offset(x: -30, y: 20)
                                    
                                    Circle()
                                        .fill(.primary.opacity(0.6))
                                        .frame(width: 10, height: 10)
                                        .offset(x: -30, y: 20)
                                    
                                    Image("OtherUsersLocation")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .offset(x: -30, y: -2)
                                }
                                .opacity(appState.isVisible && !isFadingOutAnnotations ? 1.0 : 0.0)
                                .scaleEffect(appState.isVisible && !isFadingOutAnnotations ? 1.0 : 0.3)
                                .animation(.easeOut(duration: 0.3), value: appState.isVisible)
                                .animation(.easeOut(duration: 0.3), value: isFadingOutAnnotations)
                                .frame(width: 70, height: 70)
                                .contentShape(Rectangle())
                                .zIndex(selectedEvent == nil && selectedAnchor == nil ? 100 : 50)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isFadingOutAnnotations)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            
            // User location annotation (rendered last to ensure it's always on top)
            if let userLocation = locationService.lastKnown {
                userLocationAnnotation(coordinate: userLocation)
            }
        }
        .environment(\.colorScheme, .dark)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // Only handle map taps if no dropdown/search is active
                    if showClusterDropdown {
                        dismissClusterDropdown()
                    } else if showSearchResults {
                        isSearchFocused = false
                        showSearchResults = false
                    } else if expandedCombinedGroupId != nil {
                        // Collapse expanded combined groups when tapping on map
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            expandedCombinedGroupId = nil
                        }
                    } else if expandedAnchorGroupId != nil {
                        // Collapse expanded anchor groups when tapping on map
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            expandedAnchorGroupId = nil
                        }
                    } else if expandedClusterId != nil {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedClusterId = nil
                        }
                    }
                }
        )
        .mapControls { MapCompass() }
        .ignoresSafeArea()
        .onAppear {
            snapTo(selectedRegion)
            AnalyticsService.shared.trackScreenView("home")
            AnalyticsService.shared.track("map_viewed", props: [:])
            
            // Start visible users listener if visibility is enabled
            if appState.isVisible {
                startVisibleUsersListener()
            }
            
            // Capture location synchronously to avoid concurrency warnings
            let location = locationService.lastKnown
            if let location = location {
                let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                let zone = coordinate.geohash(precision: 4)
                AnalyticsService.shared.logToFirestore(eventName: "map_viewed", zone: zone)
            } else {
                AnalyticsService.shared.logToFirestore(eventName: "map_viewed")
            }
        }
        .onChange(of: selectedRegion) { _, new in
            snapTo(new)
            AnalyticsService.shared.trackRegionChanged(region: new.rawValue)
        }
        .onMapCameraChange { ctx in
            handleCameraChange(ctx)
        }
    }
    
    private func handleCameraChange(_ ctx: MapCameraUpdateContext) {
        currentCamera = ctx.camera
        currentCameraDistance = ctx.camera.distance
        
        if expandedClusterId != nil && currentCameraDistance >= 3000 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                expandedClusterId = nil
            }
        }
        // Commented out anchor-related camera change handlers end here
        
        // Update visible users query when camera changes (debounced)
        if appState.isVisible {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                if appState.isVisible {
                    startVisibleUsersListener()
                }
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

    var body: some View {
        NavigationStack {
            contentWithModifiers
        }
    }
    
    private var contentWithModifiers: some View {
        contentWithNotificationHandlers
    }
    
    private var contentWithBasicModifiers: some View {
        mainContent
            .fullScreenCover(isPresented: $showHostSheet) {
                hostEventSheet
            }
            .overlay(sparkCardOverlay)
            .overlay(confettiOverlay)
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
                    .environmentObject(appState)
                    .presentationDetents([.fraction(0.75)])
                    .presentationDragIndicator(.visible)
            }
            .overlay(tutorialOverlay)
            .sheet(item: $selectedUserProfile) { user in
                UserProfileSheetView(user: user)
                    .presentationDetents([.height(600), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showVisibilityInfo) {
                VisibilityInfoSheet {
                    hasSeenVisibilityInfo = true
                    Task {
                        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
                            return
                        }
                        do {
                            try await VisibilityService.shared.toggleVisibility(userId: userId)
                            let updatedProfile = try await UserProfileService.shared.fetchProfile(userId: userId)
                            await MainActor.run {
                                appState.sessionUser = updatedProfile
                                appState.isVisible = updatedProfile.isVisible
                            }
                        } catch {
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCalendar) { CalenderView() }
            .fullScreenCover(isPresented: $showNavigationModal) {
                if let joinedEvent = appState.currentJoinedEvent {
                    EventNavigationModal(event: joinedEvent)
                }
            }
            .fullScreenCover(isPresented: $showAnchorNavigationModal) {
                if let anchor = selectedAnchor {
                    AnchorNavigationModal(anchor: anchor)
                }
            }
    }
    
    private var contentWithChangeHandlers: some View {
        contentWithBasicModifiers
            .onChange(of: appState.showTutorial) { _, shouldShow in
                if shouldShow {
                    showTutorialOverlay = true
                }
            }
            .onChange(of: appState.isVisible) { _, isVisible in
                if isVisible {
                    isFadingOutAnnotations = false
                    startVisibleUsersListener()
                    if !hasSeenVisibilityUserAnnotationOnboarding && locationService.lastKnown != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showVisibilityUserAnnotationOnboarding = true
                        }
                    }
                } else {
                    isFadingOutAnnotations = true
                    showVisibilityUserAnnotationOnboarding = false
                    stopVisibleUsersListener()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        visibleUsers = []
                        isFadingOutAnnotations = false
                    }
                }
            }
            .onChange(of: locationCoordinateString) { _, _ in
                if appState.isVisible && !hasSeenVisibilityUserAnnotationOnboarding && locationService.lastKnown != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showVisibilityUserAnnotationOnboarding = true
                    }
                }
            }
            .onChange(of: selectedUserProfile) { _, profile in
                if profile != nil && showVisibilityUserAnnotationOnboarding {
                    hasSeenVisibilityUserAnnotationOnboarding = true
                    showVisibilityUserAnnotationOnboarding = false
                }
            }
            .onChange(of: selectedRegion) { _, newRegion in
                Task {
                    await loadFirebaseEvents(region: newRegion)
                }
            }
            .onChange(of: appState.currentJoinedEvent) { _, newEvent in
                if let event = newEvent {
                    liveAttendeeCount = event.attendeeCount
                    startEventListener(for: event)
                    // Restart timer to check for event end
                    startEventEndCheckTimer()
                } else {
                    eventListener?.remove()
                    eventListener = nil
                    liveAttendeeCount = 0
                    stopEventEndCheckTimer()
                }
            }
    }
    
    private var contentWithNotificationHandlers: some View {
        contentWithLifecycleHandlers
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                removeExpiredEvents()
                Task {
                    // Commented out temporarily
                    // await anchorService.updateActiveAnchors()
                    // // Track anchor activations for analytics
                    // for anchor in anchorService.activeAnchors {
                    //     if let coordinate = anchor.coordinates {
                    //         let zone = coordinate.geohash(precision: 4)
                    //         AnalyticsService.shared.trackAnchorActivated(
                    //             anchorId: anchor.id,
                    //             anchorName: anchor.name,
                    //             location: anchor.location,
                    //             zone: zone
                    //         )
                    //     }
                    // }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .eventDeleted)) { notification in
                handleEventDeleted(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToEventFromNotification)) { notification in
                handleNavigateToEvent(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showHostSheetFromNotification)) { _ in
                showHostSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .testNewEventBanner)) { notification in
                if let event = notification.object as? CrowdEvent {
                    newEventBanner = event
                    startBannerDismissTimer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .userBlocked)) { notification in
                if let blockedUserId = notification.object as? String {
                    Task {
                        await loadModerationData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .eventHidden)) { notification in
                if let hiddenEventId = notification.object as? String {
                    Task {
                        await loadModerationData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .campusChanged)) { notification in
                if let newCampusId = notification.object as? String {
                    handleCampusChange(newCampusId)
                }
            }
    }
    
    private var contentWithLifecycleHandlers: some View {
        contentWithChangeHandlers
            .task {
                await loadFirebaseEvents()
                await loadUpcomingEvents()
                await preloadCalendarEvents()
                await loadModerationData()
                await anchorService.loadAnchors()
                if let firebaseRepo = env.eventRepo as? FirebaseEventRepository {
                    try? await firebaseRepo.deleteExpiredEvents()
                }
                setupNewEventListeners()
            }
            .onAppear {
                if let joinedEvent = appState.currentJoinedEvent {
                    liveAttendeeCount = joinedEvent.attendeeCount
                    startEventListener(for: joinedEvent)
                }
                startEventEndCheckTimer()
                
                // Sync selected region with stored campus ID
                syncRegionWithCampus()
            }
            .onDisappear {
                stopNewEventListeners()
                bannerDismissTimer?.invalidate()
                bannerDismissTimer = nil
                stopVisibleUsersListener()
                stopEventEndCheckTimer()
            }
    }
    
    // MARK: - Event Listener for Joined Event
    
    private func startEventListener(for event: CrowdEvent) {
        let db = FirebaseManager.shared.db
        eventListener?.remove()
        
        // Try events collection first
        let eventRef = db.collection("events").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    // Try userEvents collection as fallback
                    tryUserEventsListener(for: event)
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                } else if !(snapshot?.exists ?? false) {
                    // Document doesn't exist in events, try userEvents
                    tryUserEventsListener(for: event)
                }
            }
        }
    }
    
    private func tryUserEventsListener(for event: CrowdEvent) {
        let db = FirebaseManager.shared.db
        eventListener?.remove()
        
        let eventRef = db.collection("userEvents").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                }
            }
        }
    }
    
    // MARK: - Visible Users Listener
    
    private func startVisibleUsersListener() {
        // Stop existing listener
        stopVisibleUsersListener()
        
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            return
        }
        
        guard appState.isVisible else {
            return
        }
        
        // Use currentCamera from handleCameraChange
        let camera = currentCamera
        
        // Get blocked user IDs
        let blockedUserIds = self.blockedUserIds
        
        // Set up listener
        visibleUsersListener = VisibilityService.shared.listenToVisibleUsers(
            in: camera,
            currentUserId: userId,
            blockedUserIds: blockedUserIds
        ) { [self] (users: [UserProfile]) in
            Task { @MainActor in
                self.visibleUsers = users
            }
        }
    }
    
    private func stopVisibleUsersListener() {
        visibleUsersListener?.remove()
        visibleUsersListener = nil
    }
    
    // MARK: - Event End Check Timer
    
    private func startEventEndCheckTimer() {
        stopEventEndCheckTimer() // Stop any existing timer
        
        // Check every 30 seconds if the current joined event has ended
        // Since CrowdHomeView is a struct, we can't use [weak self]
        // Capture appState reference to use in the timer closure
        let state = appState
        
        eventEndCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                // Check if the current joined event has ended
                guard let joinedEvent = state.currentJoinedEvent else { return }
                
                let now = Date()
                var eventHasEnded = false
                
                if let time = joinedEvent.time {
                    // Check if event time was more than 4 hours ago
                    let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
                    eventHasEnded = time < fourHoursAgo
                }
                
                if eventHasEnded {
                    // Clear the joined event
                    state.currentJoinedEvent = nil
                }
            }
        }
    }
    
    private func stopEventEndCheckTimer() {
        eventEndCheckTimer?.invalidate()
        eventEndCheckTimer = nil
    }
    
    private func checkAndClearEndedJoinedEvent() {
        guard let joinedEvent = appState.currentJoinedEvent else { return }
        
        let now = Date()
        var eventHasEnded = false
        
        if let time = joinedEvent.time {
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            eventHasEnded = time < fourHoursAgo
        }
        
        if eventHasEnded {
            appState.currentJoinedEvent = nil
            eventListener?.remove()
            eventListener = nil
            liveAttendeeCount = 0
            
            // Close navigation modal if it's open
            if showNavigationModal {
                showNavigationModal = false
            }
        }
    }
    
    // MARK: - New Event Banner Listeners
    
    private func setupNewEventListeners() {
        let db = FirebaseManager.shared.db
        
        // Stop existing listeners
        stopNewEventListeners()
        
        // Reset initialization counter - skip first snapshot from each listener
        initializedListenerCount = 0
        
        // Listen for new events in "events" collection
        let eventsListener = db.collection("events")
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    
                    // Skip first snapshot (contains all existing documents)
                    if self.initializedListenerCount < 2 {
                        // Mark existing events as seen
                        for document in snapshot.documents {
                            self.seenEventIds.insert(document.documentID)
                        }
                        self.initializedListenerCount += 1
                        return
                    }
                    
                    // Process only newly added documents after initialization
                    for change in snapshot.documentChanges {
                        if change.type == .added {
                            self.handleNewEvent(document: change.document, collection: "events")
                        }
                    }
                }
            }
        
        // Listen for new events in "userEvents" collection
        let userEventsListener = db.collection("userEvents")
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    
                    // Skip first snapshot (contains all existing documents)
                    if self.initializedListenerCount < 2 {
                        // Mark existing events as seen
                        for document in snapshot.documents {
                            self.seenEventIds.insert(document.documentID)
                        }
                        self.initializedListenerCount += 1
                        return
                    }
                    
                    // Process only newly added documents after initialization
                    for change in snapshot.documentChanges {
                        if change.type == .added {
                            self.handleNewEvent(document: change.document, collection: "userEvents")
                        }
                    }
                }
            }
        
        newEventListeners = [eventsListener, userEventsListener]
    }
    
    private func stopNewEventListeners() {
        for listener in newEventListeners {
            listener.remove()
        }
        newEventListeners.removeAll()
    }
    
    private func handleNewEvent(document: QueryDocumentSnapshot, collection: String) {
        let eventId = document.documentID
        
        // Skip if we've already seen this event
        if seenEventIds.contains(eventId) {
            return
        }
        
        // Parse event from document data
        guard let firebaseRepo = env.eventRepo as? FirebaseEventRepository else { return }
        
        do {
            let event = try firebaseRepo.parseEvent(from: document.data())
            
            // Add to seen events
            seenEventIds.insert(eventId)
            
            // Show banner
            newEventBanner = event
            startBannerDismissTimer()
        } catch {
        }
    }
    
    private func startBannerDismissTimer() {
        bannerDismissTimer?.invalidate()
        bannerDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                self.dismissBanner()
            }
        }
    }
    
    private func dismissBanner() {
        withAnimation(.easeOut(duration: 0.3)) {
            newEventBanner = nil
        }
        bannerDismissTimer?.invalidate()
        bannerDismissTimer = nil
    }
    
    private func handleBannerJoin(event: CrowdEvent) {
        Task {
            // Check if this is the first event join (before leaving any previous event)
            let wasFirstEvent = AttendedEventsService.shared.getAttendedEvents().isEmpty
            
            // Leave previous event if user is already in one
            let attendedEvents = AttendedEventsService.shared.getAttendedEvents()
            if let previousEvent = attendedEvents.first(where: { $0.id != event.id }) {
                let viewModel = EventDetailViewModel(eventRepo: env.eventRepo)
                await viewModel.leaveEvent(event: previousEvent)
                
                // Clear currentJoinedEvent if it matches
                await MainActor.run {
                    if appState.currentJoinedEvent?.id == previousEvent.id {
                        appState.currentJoinedEvent = nil
                    }
                }
            }
            
            // Join the new event
            let viewModel = EventDetailViewModel(eventRepo: env.eventRepo)
            let success = await viewModel.joinEvent(event: event)
            
            if success {
                await MainActor.run {
                    appState.currentJoinedEvent = event
                    
                    // Request app rating if this is the first event
                    if wasFirstEvent {
                        AppRatingService.shared.requestRatingIfNeeded(isFirstEvent: true)
                    }
                    
                    // Dismiss banner and show navigation modal
                    dismissBanner()
                    showNavigationModal = true
                }
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            mapView
            dropdownOverlay
            overlaysAndControls
        }
    }
    
    @ViewBuilder
    private var dropdownOverlay: some View {
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
    }
    
    private var overlaysAndControls: some View {
        ZStack {
            GeometryReader { geo in
                // Panel metrics shared by panel and floating buttons
                let panelWidth  = min(geo.size.width * 0.84, 520)
                let panelHeight: CGFloat = 140

                VStack(spacing: 0) {
                    // === Centered main navbar (region picker) with eye button ===
                    ZStack {
                        // Region picker (centered)
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
                                        .foregroundStyle(.black)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.black.opacity(0.8))
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                        .fixedSize()
                        
                        // Eye icon button (visibility toggle) - absolute positioned to right
                        HStack {
                            Spacer()
                            
                            FrostedEyesButton(
                                baseSize: 54,
                                targetSize: 54,
                                frostOpacity: 1.0,
                                highlightColor: Color(hex: 0x8A5A3C),
                                containerColor: Color(hex: 0xFFFFFF),
                                isGhostMode: appState.isVisible // Show ghost when visible, eyes when not
                            ) {
                                Haptics.light()
                                
                                // Show info sheet on first use
                                if !hasSeenVisibilityInfo && !appState.isVisible {
                                    showVisibilityInfo = true
                                } else {
                                    Task {
                                        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
                                            return
                                        }
                                        
                                        do {
                                            try await VisibilityService.shared.toggleVisibility(userId: userId)
                                            
                                            // Reload profile to get updated visibility state and expiration
                                            let updatedProfile = try await UserProfileService.shared.fetchProfile(userId: userId)
                                            
                                            await MainActor.run {
                                                appState.sessionUser = updatedProfile
                                                appState.isVisible = updatedProfile.isVisible
                                            }
                                        } catch {
                                            // Handle error silently or show user feedback
                                        }
                                    }
                                }
                            }
                            .padding(.trailing, 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 0)
                    .offset(y: -18)
                    .zIndex(5)
                    
                    // New Event Banner
                    if let bannerEvent = newEventBanner {
                        VStack {
                            NewEventBanner(
                                event: bannerEvent,
                                onJoin: {
                                    handleBannerJoin(event: bannerEvent)
                                },
                                onDismiss: {
                                    dismissBanner()
                                }
                            )
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        .padding(.top, 8)
                        .zIndex(4)
                    }
                    
                    // Visibility User Annotation Onboarding Card - positioned above user's own annotation
                    if showVisibilityUserAnnotationOnboarding && appState.isVisible && locationService.lastKnown != nil {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                
                                VisibilityUserAnnotationOnboardingCard()
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, geometry.size.height * 0.5) // Position above user's own annotation area
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                        .zIndex(1000)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showVisibilityUserAnnotationOnboarding)
                    }

                    Spacer(minLength: 0)

                    // Bottom frosted panel + FAB cluster
                    ZStack {
                        // Frosted base with dual shadow layers
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(hex: 0xF5F7FA))
                            .shadow(color: Color.black.opacity(0.07), radius: 15, x: 0, y: 3)  // Layer 1: Separation
                            .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 1.5)  // Layer 2: Contact
                            .frame(width: panelWidth, height: panelHeight)
                            .allowsHitTesting(false)

                        VStack(spacing: 10) {
                            let fabSize: CGFloat = 72
                            let centerYOffset: CGFloat = -14
                            let spread = panelWidth * 0.35
                            let sideYOffset: CGFloat = panelHeight * 0.16

                            ZStack {
                                // Center FAB — Host (Fire animation)
                                FrostedFireButton(
                                    baseSize: fabSize,
                                    targetSize: 82,
                                    frostOpacity: 1.0,
                                    highlightColor: Color(hex: 0xff8a00),
                                    containerColor: Color(hex: 0xFFFFFF)
                                ) {
                                    showSparkCard = true
                                    Haptics.light()
                                }
                                .offset(y: centerYOffset)

                                 // Left — Profile (open at 3/4 screen)
                                 ZStack {
                                     FrostedIconButton(
                                         systemName: "person",
                                         baseSize: 54,
                                         targetSize: 72,
                                         frostOpacity: 1.0,
                                         iconBaseColor: Color(hex: 0x5880ad),
                                         highlightColor: Color(hex: 0x5880ad),
                                         containerColor: Color(hex: 0xFFFFFF)
                                     ) {
                                         route = .profile
                                         overlaySnapIndex = 1
                                         overlayPresented = true
                                         Haptics.light()
                                     }
                                     .accessibilityLabel("Open profile")
                                 }
                                 .offset(x: -spread, y: sideYOffset)

                                // Right — Calendar
                                ZStack {
                                    FrostedIconButton(
                                        systemName: "calendar",
                                        baseSize: 54,
                                        targetSize: 72,
                                        frostOpacity: 1.0,
                                        iconBaseColor: Color(hex: 0x8B0F1A),
                                        highlightColor: Color(hex: 0x8B0F1A),
                                        containerColor: Color(hex: 0xFFFFFF)
                                    ) {
                                        showCalendar = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open calendar")
                                }
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 24)
                .padding(.bottom, panelHeight + 28)
                
                // === JOINED EVENT INDICATOR (left side) ===
                if let joinedEvent = appState.currentJoinedEvent {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            // White circle with drop shadow
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                .overlay(
                                    // Event emoji
                                    Text(TagEmoji.emoji(for: joinedEvent.tags, fallbackCategory: joinedEvent.category))
                                        .font(.system(size: 30))
                                )
                                .overlay(
                                    // Red dot indicator for unread messages (top-left corner)
                                    Group {
                                        if chatNotificationService.hasUnreadMessages(eventId: joinedEvent.id) {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 14, height: 14)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                                .offset(x: -20, y: -20)
                                        }
                                    }
                                )
                            .onTapGesture {
                                showNavigationModal = true
                            }
                            .padding(.leading, 16)
                            
                            Spacer()
                        }
                        .padding(.top, 0)
                        .offset(y: -18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .zIndex(6)
                }
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
        }
    }
    
    private func createEventFromSparkCard(title: String, coord: CLLocationCoordinate2D, locationName: String?) {
        Task {
            let isFirstEvent = hostedEvents.isEmpty
            let startTime = Date()
            let endTime = startTime.addingTimeInterval(3 * 60 * 60) // 3 hours after start
            
            let event = CrowdEvent.newDraft(
                at: coord,
                title: title.isEmpty ? "Crowd" : title,
                hostId: appState.sessionUser?.id ?? "anon",
                hostName: appState.sessionUser?.displayName ?? "Guest",
                category: EventCategory.chillHangout.rawValue,
                description: nil,
                startTime: startTime,
                endTime: endTime,
                tags: [EventCategory.chillHangout.defaultTag],
                rawLocationName: locationName
            )
            
            do {
                try await env.eventRepo.create(event: event)
                
                let zone = coord.geohash(precision: 4)
                AnalyticsService.shared.trackEventCreated(
                    eventId: event.id,
                    title: event.title,
                    category: event.category,
                    zone: zone
                )
                
                // Host is automatically part of their own event - no need to join
                // Skip join operation for hosts since Firebase rules prevent it
                if let userId = FirebaseManager.shared.getCurrentUserId() {
                    // Host is already part of the event they created
                    // Just add to attended events locally for UI state
                    AttendedEventsService.shared.addAttendedEvent(event)
                    
                    // Track analytics (but don't try to join via Firebase since host can't join own event)
                    AnalyticsService.shared.trackEventJoined(eventId: event.id, title: event.title, zone: zone)
                }
                
                await MainActor.run {
                    hostedEvents.append(event)
                    showConfetti = true
                    Haptics.light()
                    appState.currentJoinedEvent = event
                    showNavigationModal = true
                    
                    if isFirstEvent {
                        AppRatingService.shared.requestRatingIfNeeded(isFirstEvent: true)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showConfetti = false
                    }
                }
            } catch {
                await MainActor.run {
                    hostedEvents.append(event)
                }
            }
        }
    }
    
    @ViewBuilder
    private var hostEventSheet: some View {
        HostEventSheet(defaultRegion: selectedRegion, initialTitle: initialEventTitle) { event in
            // Events are now created from SparkCrowdCard only
            // This callback is kept for backward compatibility but doesn't create events
            // Close the sheet and show SparkCrowdCard instead
            showHostSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showSparkCard = true
            }
        }
        .onDisappear {
            // Clear initialEventTitle after sheet is dismissed
            initialEventTitle = nil
        }
    }
    
    @ViewBuilder
    private var sparkCardOverlay: some View {
        if showSparkCard {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showSparkCard = false
                        }
                    }
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
                
                SparkCrowdCard(
                    defaultRegion: selectedRegion,
                    onIgnite: { title, coord, locationName in
                        createEventFromSparkCard(title: title, coord: coord, locationName: locationName)
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showSparkCard = false
                        }
                    }
                )
                .environmentObject(appState)
                .frame(maxWidth: 420)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(hex: 0xF5F7FA))
                        .shadow(color: Color.black.opacity(0.07), radius: 15, x: 0, y: 3)
                        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 1.5)
                )
                .padding(.horizontal, 24)
                .scaleEffect(showSparkCard ? 1 : 0.85)
                .opacity(showSparkCard ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: showSparkCard)
            }
            .zIndex(999)
        }
    }
    
    @ViewBuilder
    private var confettiOverlay: some View {
        if showConfetti {
            ConfettiOverlay()
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private var tutorialOverlay: some View {
        if showTutorialOverlay {
            TutorialOverlayView(
                steps: TutorialStep.allSteps,
                targetPositions: [:],
                onComplete: {
                    TutorialManager.shared.markTutorialComplete()
                    showTutorialOverlay = false
                    appState.showTutorial = false
                },
                onStepComplete: nil
            )
            .transition(.opacity)
            .zIndex(1000)
        }
    }
    
    // MARK: - Notification Handlers
    
    private func handleEventDeleted(_ notification: Notification) {
        if let eventId = notification.object as? String {
            hostedEvents.removeAll { $0.id == eventId }
            officialEvents.removeAll { $0.id == eventId }
            userEventsFromFirebase.removeAll { $0.id == eventId }
            upcomingEvents.removeAll { $0.id == eventId }
            
            if expandedClusterId != nil {
                withAnimation(.easeOut(duration: 0.3)) {
                    expandedClusterId = nil
                }
            }
        }
    }
    
    private func handleNavigateToEvent(_ notification: Notification) {
        if let eventId = notification.userInfo?["eventId"] as? String {
            if let event = allEvents.first(where: { $0.id == eventId }) {
                selectedEvent = event
            } else {
                Task {
                    await loadFirebaseEvents()
                    await loadUpcomingEvents()
                    if let event = allEvents.first(where: { $0.id == eventId }) {
                        selectedEvent = event
                    }
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
                    
                    // Track seen event IDs
                    let allLoadedEvents = official + userCreated
                    seenEventIds = Set(allLoadedEvents.map { $0.id })
                }
            } else {
                // Fallback for mock repository or other implementations
                let events = try await env.eventRepo.fetchEvents(in: targetRegion)
                await MainActor.run {
                    officialEvents = events
                    userEventsFromFirebase = []
                    isLoadingEvents = false
                }
            }
        } catch {
            await MainActor.run {
                officialEvents = []
                userEventsFromFirebase = []
                isLoadingEvents = false
            }
        }
    }
    
    // MARK: - Upcoming Events Loading
    
    private func loadUpcomingEvents() async {
        print("🔄 DEBUG: loadUpcomingEvents() called")
        
        // Load upcoming events from CampusEventsViewModel (existing 14-day feed)
        let sharedVM = await CampusEventsViewModel.shared
        await sharedVM.fetchOnce(limit: 200)
        await MainActor.run {
            upcomingEvents = sharedVM.crowdEvents
            print("✅ DEBUG: upcomingEvents loaded: \(upcomingEvents.count) events")
            
            // Check if any events are today
            let calendar = Calendar.current
            let todayCount = upcomingEvents.filter { ev in
                guard let time = ev.time else { return false }
                return calendar.isDateInToday(time)
            }.count
            
            print("   Today's events: \(todayCount)")
            
            if !upcomingEvents.isEmpty {
                print("   First 3 events:")
                for event in upcomingEvents.prefix(3) {
                    print("   - '\(event.title)' at \(event.time ?? Date.distantPast)")
                    print("     Coords: (\(event.latitude), \(event.longitude))")
                }
            }
        }
    }
    
    // MARK: - Calendar Events Preloading
    
    /// Preloads calendar events (parties/school events):
    /// Events are loaded immediately from Firebase on singleton initialization
    /// This ensures low latency when navigating to CalendarView
    private func preloadCalendarEvents() async {
        // Events already loading in singleton init, but ensure completion
        let sharedVM = await CampusEventsViewModel.shared
        await sharedVM.fetchOnce(limit: 200) // Preload with high limit to get all future events
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
        }
    }
    
    // MARK: - Event Cleanup
    
    private func removeExpiredEvents() {
        let now = Date()
        
        // Collect expired event IDs before removing
        let expiredEventIds = Set(
            (upcomingEvents + officialEvents + userEventsFromFirebase + hostedEvents)
                .filter { event in
                    guard let time = event.time else { return false }
                    // Check if event time was more than 4 hours ago
                    let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
                    return time < fourHoursAgo
                }
                .map { $0.id }
        )
        
        // Remove events that have ended (immediately when end time is reached)
        upcomingEvents.removeAll { event in
            guard let time = event.time else { return false }
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time < fourHoursAgo
        }
        
        officialEvents.removeAll { event in
            guard let time = event.time else { return false }
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time < fourHoursAgo
        }
        
        userEventsFromFirebase.removeAll { event in
            guard let time = event.time else { return false }
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time < fourHoursAgo
        }
        
        hostedEvents.removeAll { event in
            guard let time = event.time else { return false }
            // Check if event time was more than 4 hours ago
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time < fourHoursAgo
        }
        
        // Remove expired events from attended events service (this will hide the join button)
        if !expiredEventIds.isEmpty {
            for eventId in expiredEventIds {
                AttendedEventsService.shared.removeAttendedEvent(eventId)
            }
            
        // Clear currentJoinedEvent if it's one of the expired events (this will hide the white circle button)
        if let currentEvent = appState.currentJoinedEvent,
           expiredEventIds.contains(currentEvent.id) {
            appState.currentJoinedEvent = nil
        }
        
        // Also check if currentJoinedEvent has ended based on end time
        checkAndClearEndedJoinedEvent()
            
            // Also remove signals and attendances from Firestore and delete expired events from database
            Task {
                await removeUsersFromExpiredEvents(eventIds: Array(expiredEventIds))
                
                // Delete expired events from database
                if let firebaseRepo = env.eventRepo as? FirebaseEventRepository {
                    do {
                        try await firebaseRepo.deleteExpiredEvents()
                    } catch {
                    }
                }
            }
        }
    }
    
    private func removeUsersFromExpiredEvents(eventIds: [String]) async {
        guard !eventIds.isEmpty else { return }
        
        let db = FirebaseManager.shared.db
        
        for eventId in eventIds {
            do {
                // Delete signals for this event
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                if !signalsSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    signalsSnapshot.documents.forEach { doc in
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                }
                
                // Delete attendances for this event
                let attendancesSnapshot = try await db.collection("userAttendances")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                if !attendancesSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    attendancesSnapshot.documents.forEach { doc in
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                }
            } catch {
            }
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
        if cluster.isSingleEvent {
            // Single event - show detail directly
            if let event = cluster.events.first {
                selectedEvent = event
            }
        } else {
            // Multi-event cluster - show dropdown list (NO ZOOM)
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
        selectedEvent = event
    }
    
    // MARK: - Anchor Handlers
    
    func handleAnchorGroupTap(group: [Anchor], groupId: String) {
        // If single anchor, open modal directly
        if group.count == 1, let anchor = group.first {
            handleAnchorTap(anchor)
            return
        }
        
        // If group is already expanded, open the first anchor's modal
        if expandedAnchorGroupId == groupId {
            if let firstAnchor = group.first {
                handleAnchorTap(firstAnchor)
            }
        } else {
            // Expand the group
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                expandedAnchorGroupId = groupId
            }
        }
    }
    
    func handleCombinedGroupTap(anchorGroup: [Anchor], cluster: EventCluster, groupId: String) {
        // If single anchor and single event, show anchor modal
        if anchorGroup.count == 1 && cluster.eventCount == 1, let anchor = anchorGroup.first {
            handleAnchorTap(anchor)
            return
        }
        
        // If group is already expanded, open the first anchor's modal or first event
        if expandedCombinedGroupId == groupId {
            if let firstAnchor = anchorGroup.first {
                handleAnchorTap(firstAnchor)
            } else if let firstEvent = cluster.events.first {
                handleEventTap(firstEvent)
            }
        } else {
            // Expand the combined group
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                expandedCombinedGroupId = groupId
                // Collapse other expanded groups
                expandedAnchorGroupId = nil
                expandedClusterId = nil
            }
        }
    }
    
    func handleAnchorTap(_ anchor: Anchor) {
        // Start chat listening immediately (before modal opens) if user ID is available
        if let userId = FirebaseManager.shared.getCurrentUserId() {
            EventChatService.shared.startListening(eventId: anchor.id, currentUserId: userId)
            ChatNotificationService.shared.startListeningToAnchor(anchorId: anchor.id, anchorName: anchor.name)
            ChatNotificationService.shared.markAsRead(eventId: anchor.id)
        }
        
        // Open modal immediately (don't wait for analytics)
        selectedAnchor = anchor
        showAnchorNavigationModal = true
        
        // Collapse any expanded group first (if needed)
        if expandedAnchorGroupId != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                expandedAnchorGroupId = nil
            }
        }
        if expandedCombinedGroupId != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                expandedCombinedGroupId = nil
            }
        }
    }
    
    
    // MARK: - Campus Selection Integration
    
    /// Sync the map region with the stored campus selection
    private func syncRegionWithCampus() {
        // Map campus ID to CampusRegion
        // Currently only UNT is supported with multiple regions
        // Other campuses will use the default region for now
        switch selectedCampusId {
        case "UNT":
            // Keep current region if already UNT
            break
        default:
            // Default to main campus for other (unsupported) campuses
            selectedRegion = .mainCampus
        }
    }
    
    /// Handle campus change from onboarding or settings
    private func handleCampusChange(_ newCampusId: String) {
        print("📍 CrowdHomeView: Campus changed to \(newCampusId)")
        
        // Update stored campus
        selectedCampusId = newCampusId
        
        // Refresh map region
        syncRegionWithCampus()
        
        // Reload events for new campus
        Task {
            await loadFirebaseEvents()
            await loadUpcomingEvents()
        }
    }
    
    // MARK: - Event Search Navigation
    private func navigateToEvent(_ event: CrowdEvent) {
        // Animate camera to event coordinates
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: event.coordinates,
                    distance: 1000,
                    heading: currentCamera.heading,
                    pitch: currentCamera.pitch
                )
            )
        }
        
        // Open event detail sheet
        selectedEvent = event
        
        // Store title for HostEventSheet
        initialEventTitle = event.title
        
        // Clear search and dismiss keyboard
        searchText = ""
        isSearchFocused = false
        showSearchResults = false
    }
}

// MARK: - Tiny haptics helper (optimized for performance)
enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let successGenerator = UINotificationFeedbackGenerator()
    
    static func light() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }
    static func success() {
        successGenerator.prepare()
        successGenerator.notificationOccurred(.success)
    }
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

// MARK: - Visibility User Annotation Onboarding Card
struct VisibilityUserAnnotationOnboardingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text("Tap a user pin")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            // Description
            Text("Tap on any user pin on the map to see their profile.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 340)
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
