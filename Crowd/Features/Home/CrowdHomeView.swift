//
//  CrowdHomeView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit

struct CrowdHomeView: View {
    @Environment(\.appEnvironment) var env
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
    @State private var showHeatmap = true
    @State private var selectedEvent: CrowdEvent?
    @State private var showEventDetail = false
    @State private var zoomLevel: Double = 1200 // Distance in meters
    
    // Mock events for heatmap demonstration
    var baseMockEvents: [CrowdEvent] {
        [
            CrowdEvent(id: "1", title: "Basketball", hostId: "h1", hostName: "Host 1", latitude: 33.2105, longitude: -97.1520, radiusMeters: 60, startsAt: Date(), endsAt: Date().addingTimeInterval(3600), createdAt: Date(), signalStrength: 4, attendeeCount: 25, tags: [], category: "sports"),
            CrowdEvent(id: "2", title: "Study Group", hostId: "h2", hostName: "Host 2", latitude: 33.2110, longitude: -97.1518, radiusMeters: 60, startsAt: Date(), endsAt: Date().addingTimeInterval(3600), createdAt: Date(), signalStrength: 3, attendeeCount: 15, tags: [], category: "study"),
            CrowdEvent(id: "3", title: "Party", hostId: "h3", hostName: "Host 3", latitude: 33.2108, longitude: -97.1522, radiusMeters: 60, startsAt: Date(), endsAt: Date().addingTimeInterval(3600), createdAt: Date(), signalStrength: 5, attendeeCount: 45, tags: [], category: "party"),
            CrowdEvent(id: "4", title: "Food Truck", hostId: "h4", hostName: "Host 4", latitude: 33.2095, longitude: -97.1510, radiusMeters: 60, startsAt: Date(), endsAt: Date().addingTimeInterval(3600), createdAt: Date(), signalStrength: 3, attendeeCount: 20, tags: [], category: "food"),
            CrowdEvent(id: "5", title: "Concert", hostId: "h5", hostName: "Host 5", latitude: 33.2115, longitude: -97.1525, radiusMeters: 60, startsAt: Date(), endsAt: Date().addingTimeInterval(3600), createdAt: Date(), signalStrength: 5, attendeeCount: 60, tags: [], category: "music")
        ]
    }
    
    // All events including user location event
    var allEvents: [CrowdEvent] {
        var events = baseMockEvents
        
        // Add event at user's current location
        if let userLocation = locationService.lastKnown {
            let userEvent = CrowdEvent(
                id: "user-event",
                title: "I'm Here!",
                hostId: "user",
                hostName: "You",
                latitude: userLocation.latitude,
                longitude: userLocation.longitude,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 5,
                attendeeCount: 1,
                tags: [],
                category: "hangout"
            )
            events.append(userEvent)
        }
        
        return events
    }
    
    // Computed properties for zoom-based visibility
    var heatmapOpacity: Double {
        // Fade out heatmap when zoomed in (distance < 600m)
        // Full opacity at 1200m+, zero at 400m
        return min(max((zoomLevel - 400) / 800, 0.0), 1.0)
    }
    
    var showEventMarkers: Bool {
        // Show event markers when zoomed in below 800m
        return zoomLevel < 800
    }

    // MARK: - Bottom overlay routing
    enum OverlayRoute { case none, profile, leaderboard }
    @State private var route: OverlayRoute = .none
    @State private var overlayPresented = false
    @State private var overlaySnapIndex = 0 // 0 = peek, 1 = open

    // MARK: - Floating button navigation
    @State private var showMessages = false
    @State private var showCalendar = false

    // Computed map region for heatmap overlay
    var mapRegion: MKCoordinateRegion {
        // Use the camera distance directly - it represents the eye altitude
        // Convert to a region that matches what's visible on screen
        let distance = currentCamera.distance
        return MKCoordinateRegion(
            center: currentCamera.centerCoordinate,
            latitudinalMeters: distance * 2.0,  // Account for perspective
            longitudinalMeters: distance * 2.0
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // === MAP ===
                Map(position: $cameraPosition) {
                    // Event annotations (only shown when zoomed in)
                    if showEventMarkers {
                        ForEach(baseMockEvents) { event in
                            Annotation(event.title, coordinate: event.coordinates) {
                                Button {
                                    selectedEvent = event
                                    showEventDetail = true
                                } label: {
                                    EventAnnotationView(event: event)
                                }
                            }
                            .annotationTitles(.hidden)
                        }
                        
                        // User event pin at user's location
                        if let userLocation = locationService.lastKnown {
                            Annotation("I'm Here!", coordinate: userLocation) {
                                Button {
                                    let userEvent = CrowdEvent(
                                        id: "user-event",
                                        title: "I'm Here!",
                                        hostId: "user",
                                        hostName: "You",
                                        latitude: userLocation.latitude,
                                        longitude: userLocation.longitude,
                                        radiusMeters: 60,
                                        startsAt: Date(),
                                        endsAt: Date().addingTimeInterval(3600),
                                        createdAt: Date(),
                                        signalStrength: 5,
                                        attendeeCount: 1,
                                        tags: [],
                                        category: "hangout"
                                    )
                                    selectedEvent = userEvent
                                    showEventDetail = true
                                } label: {
                                    EventAnnotationView(event: CrowdEvent(
                                        id: "user-event",
                                        title: "I'm Here!",
                                        hostId: "user",
                                        hostName: "You",
                                        latitude: userLocation.latitude,
                                        longitude: userLocation.longitude,
                                        radiusMeters: 60,
                                        startsAt: Date(),
                                        endsAt: Date().addingTimeInterval(3600),
                                        createdAt: Date(),
                                        signalStrength: 5,
                                        attendeeCount: 1,
                                        tags: [],
                                        category: "hangout"
                                    ))
                                }
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                    
                    // User location marker (character icon)
                    if let userLocation = locationService.lastKnown {
                        Annotation("", coordinate: userLocation) {
                            ZStack {
                                // Small black dot shadow - rendered first (behind)
                                Circle()
                                    .fill(.black.opacity(0.4))
                                    .frame(width: 16, height: 16)
                                    .blur(radius: 2)
                                    .offset(y: 20)
                                
                                Circle()
                                    .fill(.black.opacity(0.6))
                                    .frame(width: 10, height: 10)
                                    .offset(y: 20)
                                
                                // Character icon - rendered last (in front)
                                Image("UserLocationItem")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .offset(y: -2)
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
                    .mapControls { MapCompass() }
                    .ignoresSafeArea()
                    .onAppear {
                        snapTo(selectedRegion)
                        locationService.requestSoftAuth()
                    }
                    .onChange(of: selectedRegion) { _, new in snapTo(new) }
                    .onMapCameraChange { ctx in
                        currentCamera = ctx.camera
                        zoomLevel = ctx.camera.distance // Track zoom level
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
                
                // === GPU-ACCELERATED HEATMAP OVERLAY ===
                if showHeatmap && heatmapOpacity > 0.01 {
                    CrowdHeatmapOverlay(
                        events: allEvents,
                        mapRegion: mapRegion
                    )
                    .opacity(heatmapOpacity)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                }
                
                // === OVERLAYS & CONTROLS ===
                GeometryReader { geo in
                    // Panel metrics shared by panel and floating buttons
                    let panelWidth  = min(geo.size.width * 0.84, 520)
                    let panelHeight: CGFloat = 140

                    VStack(spacing: 0) {
                        // === Top region selector pill (moved higher without affecting bottom glass) ===
                        HStack {
                            Spacer()

                            Menu {
                                ForEach(CampusRegion.allCases) { region in
                                    Button(region.rawValue) { selectedRegion = region }
                                }
                            } label: {
                                GlassPill(height: 48, horizontalPadding: 20) {
                                    HStack(spacing: 10) {
                                        Text("🔥")
                                        Text(selectedRegion.rawValue)
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
                            .frame(maxWidth: geo.size.width * 0.9)

                            Spacer()
                        }
                        .padding(.top, 0)
                        .offset(y: -18) // raise just the navbar; tweak -10…-28 to taste
                        .zIndex(5)
                        
                        // === Zoom Controls ===
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Button {
                                    zoomIn()
                                } label: {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                        )
                                }
                                
                                Button {
                                    zoomOut()
                                } label: {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                        )
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 8)
                        }
                        .zIndex(4)

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
                                        .fill(Color.white.opacity(0.08))
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

                                    // Right — Leaderboard
                                    FrostedIconButton(
                                        systemName: "trophy",
                                        baseSize: 54,
                                        targetSize: 72,
                                        frostOpacity: 0.22,
                                        iconBaseColor: .black,
                                        highlightColor: .yellow
                                    ) {
                                        route = .leaderboard
                                        overlaySnapIndex = 0
                                        overlayPresented = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open leaderboard")
                                    .offset(x: spread, y: sideYOffset)
                                }

                                Text("Start a Crowd")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.78))
                                    .padding(.top, -8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                    }

                    // === FLOATING GLASS BUTTONS ===
                    VStack(alignment: .trailing, spacing: 16) {
                        GlassIconButton(systemName: "message.fill") { showMessages = true }
                        GlassIconButton(systemName: "calendar") { showCalendar = true }
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
                    if r == .profile { overlaySnapIndex = 1 }
                }
                .fullScreenCover(isPresented: $showMessages) { MessagesView() }
                .fullScreenCover(isPresented: $showCalendar) { CalenderView() }
            }
        }
        .sheet(isPresented: $showHostSheet) {
            HostEventSheet(defaultRegion: selectedRegion) { hostedEvents.append($0) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
                    .presentationDetents([.fraction(0.75)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Camera snap helper
    private func snapTo(_ region: CampusRegion) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = MapCameraController.position(from: region.spec)
        }
    }
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let newDistance = max(currentCamera.distance / 2, 100)
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: currentCamera.centerCoordinate,
                    distance: newDistance,
                    heading: currentCamera.heading,
                    pitch: currentCamera.pitch
                )
            )
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let newDistance = min(currentCamera.distance * 2, 5000)
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: currentCamera.centerCoordinate,
                    distance: newDistance,
                    heading: currentCamera.heading,
                    pitch: currentCamera.pitch
                )
            )
        }
    }
}

// MARK: - Tiny haptics helper
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
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
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
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
        let intensity = max(0.3, min(Double(event.attendeeCount) / 40.0, 1.0))
        let baseRadius: Double = 100 // Reduced from 150
        
        // Layer 1: Outer glow (largest, most transparent)
        MapCircle(center: event.coordinates, radius: CLLocationDistance(baseRadius * 1.8 * intensity))
            .foregroundStyle(
                .radialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.8, blue: 0.0).opacity(intensity * 0.15 * opacity),
                        Color(red: 1.0, green: 0.9, blue: 0.2).opacity(intensity * 0.08 * opacity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: baseRadius * 1.8
                )
            )
        
        // Layer 2: Middle gradient
        MapCircle(center: event.coordinates, radius: CLLocationDistance(baseRadius * 1.2 * intensity))
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
                    endRadius: baseRadius * 1.2
                )
            )
        
        // Layer 3: Hot center (smallest, most intense)
        MapCircle(center: event.coordinates, radius: CLLocationDistance(baseRadius * 0.6 * intensity))
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
                    endRadius: baseRadius * 0.6
                )
            )
    }
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: CrowdEvent
    @Environment(\.dismiss) var dismiss
    
    var emoji: String {
        guard let category = event.category else { return "🔥" }
        switch category.lowercased() {
        case "food": return "🍔"
        case "sports": return "🏀"
        case "study": return "📚"
        case "party": return "🎉"
        case "music": return "🎵"
        case "hangout": return "🔥"
        default: return "🔥"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with emoji and title
                HStack(spacing: 16) {
                    Text(emoji)
                        .font(.system(size: 60))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Hosted by \(event.hostName)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Divider()
                
                // Event details
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(icon: "person.3.fill", title: "Attendees", value: "\(event.attendeeCount)")
                    DetailRow(icon: "antenna.radiowaves.left.and.right", title: "Signal Strength", value: String(repeating: "📶", count: event.signalStrength))
                    
                    if let start = event.startsAt, let end = event.endsAt {
                        DetailRow(icon: "clock.fill", title: "Time", value: formatTime(start, end))
                    }
                    
                    DetailRow(icon: "mappin.circle.fill", title: "Location", value: "Within \(event.radiusMeters)m")
                    
                    if !event.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.blue)
                                Text("Tags")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            FlowLayout(spacing: 8) {
                                ForEach(event.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Join button
                Button {
                    // Handle join action
                    dismiss()
                } label: {
                    Text("Join Event")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func formatTime(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
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

#Preview { CrowdHomeView() }
