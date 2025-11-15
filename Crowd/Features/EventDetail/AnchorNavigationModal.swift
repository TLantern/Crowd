//
//  AnchorNavigationModal.swift
//  Crowd
//
//  Navigation modal for anchors - shows map and chat
//

import SwiftUI
import CoreLocation
import CoreMotion
import Combine
import FirebaseFirestore

// MARK: - Anchor Navigation Modal
struct AnchorNavigationModal: View {
    let anchor: Anchor
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var locationService = AppEnvironment.current.location
    @StateObject private var motionManager = MotionManager()
    
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var deviceHeading: Double = 0
    @State private var distanceToAnchor: Double = 0
    @State private var bearingToAnchor: Double = 0
    @State private var compassRotation: Double = 0
    @State private var locationUpdateTimer: Timer?
    
    @State private var currentUserId: String = "unknown"
    @State private var currentUserName: String = "Guest"
    @StateObject private var chatService = EventChatService.shared
    @State private var messageText: String = ""
    @State private var selectedTab: TabSelection = .chat
    @State private var isSendingMessage = false
    
    enum TabSelection {
        case map
        case chat
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Full UNT green background
                Color(hex: 0x02853E)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar with close button
                    VStack(spacing: 0) {
                        ZStack {
                            Color(hex: 0x02853E)
                                .frame(height: 40)

                            // Center title: slow-moving marquee when long
                            MarqueeTitle(text: "\(anchor.emoji) \(anchor.name)")
                                .padding(.horizontal, 5)
                                .padding(.bottom, 4)

                            HStack {
                                Spacer()
                                Button(action: { 
                                    dismiss() 
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 12)
                            }
                        }
                        .padding(.bottom, 4)
                        
                        // Tab switcher
                        HStack(spacing: 0) {
                            TabButton(
                                title: "Chat 💬",
                                isSelected: selectedTab == .chat,
                                action: { selectedTab = .chat }
                            )
                            
                            TabButton(
                                title: "Map 📍",
                                isSelected: selectedTab == .map,
                                action: { selectedTab = .map }
                            )
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .background(Color(hex: 0x02853E))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Distance and direction info (only show on map tab)
                        if selectedTab == .map {
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Text(formatDistance(distanceToAnchor))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(directionText)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Spacer()
                            }
                            .frame(height: 60)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: 0x02853E))
                        }
                    }
                    .padding(.top, 20)
                    
                    // Full screen tab content
                    Group {
                        if selectedTab == .map {
                            if let anchorCoord = anchor.coordinates {
                                RouteMapView(
                                    destination: anchorCoord,
                                    userCoordinate: userLocation
                                )
                                .background(Color.white)
                                .ignoresSafeArea(edges: .bottom)
                            } else {
                                VStack {
                                    Spacer()
                                    Text("Location not available")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.white)
                            }
                        } else {
                            ChatTabView(
                                chatService: chatService,
                                messageText: $messageText,
                                sendMessage: sendMessage,
                                isSendingMessage: $isSendingMessage
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                }
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            // Initialize user ID immediately from cache (fast, synchronous)
            if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
                currentUserId = existingUserId
                currentUserName = "Guest"
            }
            
            // Defer all heavy operations to async tasks to prevent blocking render
            Task.detached(priority: .userInitiated) {
                // Track analytics (non-blocking)
                AnalyticsService.shared.trackScreenView("anchor_navigation")
                AnalyticsService.shared.trackAnchorPinTapped(
                    anchorId: anchor.id,
                    anchorName: anchor.name,
                    location: anchor.location
                )
                
                // Start location updates (non-blocking)
                await MainActor.run {
                    startLocationUpdates()
                }
                
                // Start motion updates in background (slow, defer)
                Task.detached(priority: .utility) {
                    await MainActor.run {
                        startMotionUpdates()
                    }
                }
                
                // Ensure chat is listening (already started in handleAnchorTap, but verify)
                await MainActor.run {
                    if let userId = FirebaseManager.shared.getCurrentUserId() {
                        chatService.startListening(eventId: anchor.id, currentUserId: userId)
                        ChatNotificationService.shared.startListeningToAnchor(anchorId: anchor.id, anchorName: anchor.name)
                        ChatNotificationService.shared.markAsRead(eventId: anchor.id)
                    }
                }
                
                // Handle auth and profile fetch in background (non-critical)
                var userId: String?
                
                if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
                    userId = existingUserId
                    await MainActor.run {
                        currentUserId = existingUserId
                    }
                    
                    // Fetch user profile in background (non-critical)
                    do {
                        let profile = try await UserProfileService.shared.fetchProfile(userId: existingUserId)
                        await MainActor.run {
                            currentUserName = profile.displayName
                        }
                    } catch {
                        print("⚠️ AnchorNavigationModal: Failed to fetch profile: \(error)")
                    }
                } else {
                    // Sign in anonymously in background
                    do {
                        let newUserId = try await FirebaseManager.shared.signInAnonymously()
                        userId = newUserId
                        await MainActor.run {
                            currentUserId = newUserId
                            chatService.startListening(eventId: anchor.id, currentUserId: newUserId)
                            ChatNotificationService.shared.startListeningToAnchor(anchorId: anchor.id, anchorName: anchor.name)
                            ChatNotificationService.shared.markAsRead(eventId: anchor.id)
                        }
                        print("✅ AnchorNavigationModal: User signed in anonymously: \(newUserId)")
                    } catch {
                        print("❌ AnchorNavigationModal: Failed to sign in anonymously: \(error)")
                    }
                }
            }
        }
        .onDisappear {
            stopLocationUpdates()
            stopMotionUpdates()
            chatService.stopListening()
            // Keep listening to anchor for unread tracking even after closing modal
        }
        .onChange(of: selectedTab) { _, newTab in
            // Mark messages as read when switching to chat tab
            if newTab == .chat {
                ChatNotificationService.shared.markAsRead(eventId: anchor.id)
            }
        }
        .onChange(of: chatService.messages.count) { _, _ in
            // Update last seen timestamp when new messages arrive (if on chat tab)
            if selectedTab == .chat, let lastMessage = chatService.messages.last {
                ChatNotificationService.shared.updateLastSeen(eventId: anchor.id, timestamp: lastMessage.timestamp)
            }
        }
        .onReceive(motionManager.$heading) { newHeading in
            deviceHeading = newHeading
        }
        .onChange(of: deviceHeading) { _, _ in
            updateCompassRotation()
        }
        .onChange(of: bearingToAnchor) { _, _ in
            updateCompassRotation()
        }
    }
    
    // MARK: - Chat
    
    private func sendMessage() {
        // Prevent multiple simultaneous sends
        guard !isSendingMessage else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Clear text immediately for better UX
        let messageToSend = text
        messageText = ""
        
        isSendingMessage = true
        
        Task.detached(priority: .userInitiated) {
            do {
                try await chatService.sendMessage(
                    eventId: anchor.id,
                    text: messageToSend,
                    userId: await currentUserId,
                    userName: await currentUserName
                )
                
                // Track analytics on main thread
                await MainActor.run {
                    AnalyticsService.shared.trackMessageSent(eventId: anchor.id, messageLength: messageToSend.count)
                    ChatNotificationService.shared.updateLastSeen(eventId: anchor.id, timestamp: Date())
                    isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    print("❌ AnchorNavigationModal: Failed to send message: \(error)")
                    // Restore message text on error
                    messageText = messageToSend
                    isSendingMessage = false
                }
            }
        }
    }
    
    // MARK: - Computed Props
    
    private var directionText: String {
        let direction = Int(bearingToAnchor)
        switch direction {
        case 0..<22, 338...360: return "North"
        case 22..<67: return "Northeast"
        case 67..<112: return "East"
        case 112..<157: return "Southeast"
        case 157..<202: return "South"
        case 202..<247: return "Southwest"
        case 247..<292: return "West"
        case 292..<338: return "Northwest"
        default: return "Unknown"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
    
    // MARK: - Location
    
    private func startLocationUpdates() {
        locationService.requestSoftAuth()
        locationService.startUpdatingLocation()
        
        // seed with last known
        if let currentLocation = locationService.lastKnown {
            userLocation = currentLocation
            if let anchorCoord = anchor.coordinates {
                updateDistanceAndBearing(
                    to: anchorCoord,
                    from: currentLocation
                )
            }
        }
        
        // poll for new location every second
        locationUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { _ in
            if let newLocation = locationService.lastKnown {
                
                let oldLat = userLocation?.latitude ?? 0
                let oldLon = userLocation?.longitude ?? 0
                
                let movedEnough =
                    abs(newLocation.latitude - oldLat) > 0.0001 ||
                    abs(newLocation.longitude - oldLon) > 0.0001
                
                if userLocation == nil || movedEnough {
                    userLocation = newLocation
                    if let anchorCoord = anchor.coordinates {
                        updateDistanceAndBearing(
                            to: anchorCoord,
                            from: newLocation
                        )
                    }
                }
            }
        }
    }
    
    private func stopLocationUpdates() {
        locationService.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    // MARK: - Motion
    
    private func startMotionUpdates() {
        motionManager.startUpdates()
    }
    
    private func stopMotionUpdates() {
        motionManager.stopUpdates()
    }
    
    // MARK: - Navigation math
    
    private func updateDistanceAndBearing(
        to anchorCoord: CLLocationCoordinate2D,
        from userCoord: CLLocationCoordinate2D
    ) {
        let userLoc = CLLocation(
            latitude: userCoord.latitude,
            longitude: userCoord.longitude
        )
        let anchorLoc = CLLocation(
            latitude: anchorCoord.latitude,
            longitude: anchorCoord.longitude
        )
        
        distanceToAnchor = userLoc.distance(from: anchorLoc)
        bearingToAnchor = calculateBearing(
            from: userCoord,
            to: anchorCoord
        )
        
        updateCompassRotation()
    }
    
    private func calculateBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2)
            - sin(lat1) * cos(lat2) * cos(dLon)
        
        let bearingDeg = atan2(y, x) * 180 / .pi
        
        return (bearingDeg + 360)
            .truncatingRemainder(dividingBy: 360)
    }
    
    private func updateCompassRotation() {
        compassRotation = bearingToAnchor - deviceHeading
    }
}

