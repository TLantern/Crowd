//
//  CrowdHomeView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit
import FirebaseFirestore

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
    @State private var firebaseEvents: [CrowdEvent] = []
    @State private var isLoadingEvents = false
    @State private var eventListener: ListenerRegistration?

    // MARK: - Bottom overlay routing
    enum OverlayRoute { case none, profile, leaderboard }
    @State private var route: OverlayRoute = .none
    @State private var overlayPresented = false
    @State private var overlaySnapIndex = 0 // 0 = peek, 1 = open

    // MARK: - Floating button navigation
    @State private var showCalendar = false
    
    // MARK: - Event detail
    @State private var selectedEvent: CrowdEvent?
    @State private var showEventDetail = false
    
    // MARK: - Computed
    var allEvents: [CrowdEvent] {
        firebaseEvents + hostedEvents
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // === MAP ===
                Map(position: $cameraPosition) {
                    // Event annotations - always visible (mock + user-created)
                    ForEach(allEvents) { event in
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
                    
                    // User location marker (character icon)
                    if let userLocation = locationService.lastKnown {
                        Annotation("", coordinate: userLocation) {
                            ZStack {
                                // Small black dot shadow - rendered first (behind)
                                Circle()
                                    .fill(.black.opacity(0.4))
                                    .frame(width: 16, height: 16)
                                    .blur(radius: 2)
                                    .offset(x: -30, y: 20)
                                
                                Circle()
                                    .fill(.black.opacity(0.6))
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
                .mapControls { MapCompass() }
                    .ignoresSafeArea()
                    .onAppear { snapTo(selectedRegion) }
                    .onChange(of: selectedRegion) { _, new in snapTo(new) }
                    .onMapCameraChange { ctx in
                        currentCamera = ctx.camera
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

                            Spacer()
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
                                        highlightColor: .yellow
                                    ) {
                                        route = .leaderboard
                                        overlaySnapIndex = 1
                                        overlayPresented = true
                                        Haptics.light()
                                    }
                                    .accessibilityLabel("Open leaderboard")
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
                    if r == .profile || r == .leaderboard {
                        overlaySnapIndex = 1
                    }
                }
                .fullScreenCover(isPresented: $showCalendar) { CalenderView() }
            }
        }
        .sheet(isPresented: $showHostSheet) {
            HostEventSheet(defaultRegion: selectedRegion) { hostedEvents.append($0) }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
                    .environmentObject(appState)
                    .presentationDetents([.fraction(0.75)])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            startListeningToEvents()
        }
        .onDisappear {
            stopListeningToEvents()
        }
        .onChange(of: selectedRegion) { _, newRegion in
            startListeningToEvents(region: newRegion)
        }
    }
    
    // MARK: - Real-Time Event Listening
    
    private func startListeningToEvents(region: CampusRegion? = nil) {
        // Remove existing listener if any
        stopListeningToEvents()
        
        let targetRegion = region ?? selectedRegion
        print("🔄 Starting real-time listener for region: \(targetRegion.rawValue)")
        
        isLoadingEvents = true
        
        eventListener = env.eventRepo.listenToEvents(in: targetRegion) { [self] events in
            DispatchQueue.main.async {
                self.firebaseEvents = events
                self.isLoadingEvents = false
                print("✅ Real-time update: Loaded \(events.count) events from Firebase")
            }
        }
    }
    
    private func stopListeningToEvents() {
        eventListener?.remove()
        eventListener = nil
        print("🛑 Stopped listening to events")
    }

    // MARK: - Camera snap helper
    private func snapTo(_ region: CampusRegion) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = MapCameraController.position(from: region.spec)
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

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let message: String
    let isCurrentUser: Bool
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: CrowdEvent
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var hasJoined = false
    @State private var chatMessage = ""
    @State private var chatMessages: [ChatMessage] = [
        ChatMessage(author: "Sarah", message: "Hey everyone! Excited for this!", isCurrentUser: false),
        ChatMessage(author: "Mike", message: "Same here! What time are we starting?", isCurrentUser: false)
    ]
    @FocusState private var isChatFocused: Bool
    @EnvironmentObject private var appState: AppState
    @State private var showCancelConfirmation = false
    
    var currentUserName: String {
        appState.sessionUser?.displayName ?? "You"
    }
    
    var isHost: Bool {
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId() else {
            return false
        }
        return event.hostId == currentUserId
    }
    
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
        VStack(spacing: 0) {
            // Cancel button for hosts
            if isHost {
                HStack {
                    Spacer()
                    Button {
                        showCancelConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                            .background(Circle().fill(Color(.systemBackground)))
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header: Emoji + Title (centered together)
                    HStack(spacing: 8) {
                        Text(emoji)
                            .font(.system(size: 40))
                        
                        Text(event.title)
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, isHost ? 0 : 20)
                    
                    // Host info with aura points
                    VStack(spacing: 4) {
                        if viewModel.isLoadingHost {
                            ProgressView()
                                .controlSize(.small)
                        } else if let host = viewModel.hostProfile {
                            Text("Hosted by: \(host.displayName) • \(host.auraPoints) points")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Hosted by: \(event.hostName) • 0 points")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    if hasJoined {
                        // Chat view
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Event Chat")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            // Chat messages
                            ScrollViewReader { proxy in
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(chatMessages) { message in
                                        ChatMessageBubble(
                                            message: message.message,
                                            author: message.author,
                                            isCurrentUser: message.isCurrentUser
                                        )
                                        .id(message.id)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .onChange(of: chatMessages.count) { _, _ in
                                    if let lastMessage = chatMessages.last {
                                        withAnimation {
                                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .frame(minHeight: 200)
                    } else {
                        // Event details
                        VStack(spacing: 20) {
                            // Crowd Size (centered)
                            VStack(spacing: 8) {
                                Text("Crowd Size")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("\(event.attendeeCount)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            // Time
                            if let start = event.startsAt, let end = event.endsAt {
                                VStack(spacing: 8) {
                                    Text("Time")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Text(formatTime(start, end))
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            // Location
                            VStack(spacing: 8) {
                                Text("Location")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("Within \(Int(event.radiusMeters))m")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // Friends Attending
                            VStack(spacing: 12) {
                                Text("Friends Attending")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                if viewModel.isLoadingFriends {
                                    ProgressView()
                                        .controlSize(.small)
                                } else if viewModel.friendsAttending.isEmpty {
                                    Text("No friends attending yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                } else {
                                    HStack(spacing: -8) {
                                        ForEach(viewModel.friendsAttending.prefix(5)) { friend in
                                            AvatarView(
                                                name: friend.displayName,
                                                color: friend.avatarColor,
                                                size: 40
                                            )
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2)
                                            )
                                        }
                                        
                                        if viewModel.friendsAttending.count > 5 {
                                            ZStack {
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                                    .frame(width: 40, height: 40)
                                                Text("+\(viewModel.friendsAttending.count - 5)")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            
            // Chat input (only when joined)
            if hasJoined {
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $chatMessage)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isChatFocused)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(chatMessage.isEmpty ? .gray : Color(hex: 0x02853E))
                    }
                    .disabled(chatMessage.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            
            // Action button
            Button {
                if hasJoined {
                    // Open invite friends sheet
                } else {
                    Task {
                        let success = await viewModel.joinEvent(eventId: event.id)
                        if success {
                            withAnimation(.spring(response: 0.3)) {
                                hasJoined = true
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if viewModel.isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .controlSize(.small)
                    }
                    Text(hasJoined ? "Invite Friends" : "Join Crowd")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x02853E), Color(hex: 0x03A04E)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.isJoining)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .task {
            await viewModel.loadHostProfile(hostId: event.hostId)
            await viewModel.loadFriendsAttending(eventId: event.id)
        }
        .alert("Error", isPresented: .constant(viewModel.joinError != nil)) {
            Button("OK") {
                viewModel.joinError = nil
            }
        } message: {
            Text(viewModel.joinError ?? "Unknown error")
        }
        .confirmationDialog("Cancel Crowd", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel Crowd", role: .destructive) {
                cancelEvent()
            }
            Button("Keep Crowd", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this crowd? This action cannot be undone.")
        }
    }
    
    private func formatTime(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func sendMessage() {
        guard !chatMessage.isEmpty else { return }
        
        // Add message to chat
        let newMessage = ChatMessage(
            author: currentUserName,
            message: chatMessage,
            isCurrentUser: true
        )
        chatMessages.append(newMessage)
        
        // TODO: Send message to Firebase
        print("Sending message: \(chatMessage)")
        chatMessage = ""
    }
    
    private func cancelEvent() {
        // Verify user is the host
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId(),
              currentUserId == event.hostId else {
            print("⚠️ Only the host can delete the event")
            return
        }
        
        Task {
            do {
                try await AppEnvironment.current.eventRepo.deleteEvent(eventId: event.id)
                
                // Track analytics
                AnalyticsService.shared.trackEventDeleted(eventId: event.id)
                
                print("✅ Event deleted: \(event.id)")
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Failed to delete event: \(error)")
            }
        }
    }
}

struct ChatMessageBubble: View {
    let message: String
    let author: String
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            Text(author)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isCurrentUser ? Color(hex: 0x02853E) : Color(.systemGray5))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
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

#Preview {
    CrowdHomeView()
        .environmentObject(AppState())
}
