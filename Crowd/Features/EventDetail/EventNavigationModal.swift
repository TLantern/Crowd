//
//  EventNavigationModal.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI
import CoreLocation
// import MapKit
import CoreMotion
import Combine
import FirebaseFirestore

// MARK: - Motion Manager for device heading
@MainActor
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var heading: Double = 0
    
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: .main
        ) { [weak self] motion, _ in
            guard let motion = motion else { return }
            
            let rawHeadingDeg = atan2(
                motion.magneticField.field.y,
                motion.magneticField.field.x
            ) * 180 / .pi
            
            let adjustedHeading = (rawHeadingDeg + 360)
                .truncatingRemainder(dividingBy: 360)
            
            self?.heading = adjustedHeading
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Event Navigation Modal
struct EventNavigationModal: View {
    let event: CrowdEvent
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @StateObject private var locationService = AppEnvironment.current.location
    @StateObject private var motionManager = MotionManager()
    
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var deviceHeading: Double = 0
    @State private var distanceToEvent: Double = 0
    @State private var bearingToEvent: Double = 0
    @State private var compassRotation: Double = 0
    @State private var locationUpdateTimer: Timer?
    
    @State private var currentUserId: String = "unknown"
    @State private var currentUserName: String = "Guest"
    @StateObject private var chatService = EventChatService.shared
    @State private var messageText: String = ""
    @State private var liveAttendeeCount: Int = 0
    @State private var eventListener: ListenerRegistration?
    // @State private var transportMode: TransportMode = .automobile
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Full UNT green background
                Color(hex: 0x02853E)
                    .ignoresSafeArea()
                
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        // Top bar with close button
                        VStack(spacing: 0) {
                            ZStack {
                                Color(hex: 0x02853E)
                                    .frame(height: 40)

                                // Center title: slow-moving marquee when long
                                MarqueeTitle(text: "\(eventEmoji) \(event.title)")
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
                            
                            // Joined status row
                            HStack(spacing: 12) {
                                GlassPill(height: 32, horizontalPadding: 12) {
                                    Text("Joined")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                
                                Text("\(liveAttendeeCount)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Green live indicator
                                HStack(spacing: 4) {
                                    LiveIndicatorView()
                                    Text("LIVE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: 0x02853E))
                        }
                        .padding(.top, 20)
                        
                        // Split view: 50% map (top), 50% chat (bottom)
                        VStack(spacing: 0) {
                            // MAP AREA (50% - top)
                            RouteMapView(
                                destination: event.coordinates,
                                userCoordinate: userLocation
                            )
                            .frame(height: max(0, (geo.size.height * 0.85 - 100) / 2))
                            .background(Color.white)
                            
                            Divider()
                            
                            // CHAT AREA (50% - bottom)
                            VStack(spacing: 0) {
                                // Messages list
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        LazyVStack(spacing: 12) {
                                            ForEach(chatService.messages) { message in
                                                ChatMessageBubble(
                                                    message: message.text,
                                                    author: message.userName,
                                                    isCurrentUser: message.isCurrentUser
                                                )
                                                .id(message.id)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .onChange(of: chatService.messages.count) { _, _ in
                                        if let lastMessage = chatService.messages.last {
                                            withAnimation {
                                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                            }
                                        }
                                    }
                                }
                                .background(Color(uiColor: .systemBackground))
                                
                                Divider()
                                
                                // Message input
                                HStack(spacing: 12) {
                                    TextField("Type a message...", text: $messageText)
                                        .textFieldStyle(.plain)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(20)
                                    
                                    Button(action: sendMessage) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : Color(hex: 0x02853E))
                                    }
                                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(uiColor: .systemBackground))
                            }
                            .frame(height: max(0, (geo.size.height * 0.85 - 100) / 2))
                        }
                        .frame(height: max(0, geo.size.height * 0.85 - 100))
                        .ignoresSafeArea(edges: .top)
                    }
                }
                .navigationBarHidden(true)
            }
        }
        // MARK: lifecycle / listeners
        .onAppear {
            // Track screen view
            AnalyticsService.shared.trackScreenView("event_navigation")
            
            // Initialize live attendee count
            liveAttendeeCount = event.attendeeCount
            
            // Start listening to event document for real-time attendee count
            startEventListener()
            
            // ensure user auth
            Task {
                var userId: String?
                
                if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
                    userId = existingUserId
                    await MainActor.run {
                        currentUserId = existingUserId
                    }
                    // Fetch user profile for display name
                    do {
                        let profile = try await UserProfileService.shared.fetchProfile(userId: existingUserId)
                        await MainActor.run {
                            currentUserName = profile.displayName
                        }
                    } catch {
                        print("⚠️ EventNavigationModal: Failed to fetch profile: \(error)")
                    }
                } else {
                    do {
                        let newUserId = try await FirebaseManager.shared.signInAnonymously()
                        userId = newUserId
                        await MainActor.run {
                            currentUserId = newUserId
                        }
                        print("✅ EventNavigationModal: User signed in anonymously: \(newUserId)")
                    } catch {
                        print("❌ EventNavigationModal: Failed to sign in anonymously: \(error)")
                    }
                }
                
                // Start chat listening after userId is set
                if let finalUserId = userId {
                    await MainActor.run {
                        chatService.startListening(eventId: event.id, currentUserId: finalUserId)
                    }
                }
            }
            
            startLocationUpdates()
            startMotionUpdates()
        }
        .onDisappear {
            stopLocationUpdates()
            stopMotionUpdates()
            chatService.stopListening()
            eventListener?.remove()
            eventListener = nil
        }
        .onReceive(motionManager.$heading) { newHeading in
            deviceHeading = newHeading
        }
        .onAppear {
            if let loc = userLocation {
                updateDistanceAndBearing(
                    to: event.coordinates,
                    from: loc
                )
            }
        }
        .onChange(of: deviceHeading) { _, _ in
            updateCompassRotation()
        }
        .onChange(of: bearingToEvent) { _, _ in
            updateCompassRotation()
        }
    } // ← THIS closes body
    
    // -------------------------
    // Everything below here is NOW outside `body`.
    // Compiler stops whining.
    // -------------------------
    
    // MARK: - Computed Props
    
    private var directionText: String {
        let direction = Int(bearingToEvent)
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
    
    private var eventEmoji: String {
        if let category = event.category,
           let cat = EventCategory(rawValue: category) {
            return cat.emoji
        }
        return EventCategory.other.emoji
    }
    
    // MARK: - Location
    
    private func startLocationUpdates() {
        locationService.requestSoftAuth()
        locationService.startUpdatingLocation()
        
        // seed with last known
        if let currentLocation = locationService.lastKnown {
            userLocation = currentLocation
            updateDistanceAndBearing(
                to: event.coordinates,
                from: currentLocation
            )
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
                    updateDistanceAndBearing(
                        to: event.coordinates,
                        from: newLocation
                    )
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
        to eventCoord: CLLocationCoordinate2D,
        from userCoord: CLLocationCoordinate2D
    ) {
        let userLoc = CLLocation(
            latitude: userCoord.latitude,
            longitude: userCoord.longitude
        )
        let eventLoc = CLLocation(
            latitude: eventCoord.latitude,
            longitude: eventCoord.longitude
        )
        
        distanceToEvent = userLoc.distance(from: eventLoc)
        bearingToEvent = calculateBearing(
            from: userCoord,
            to: eventCoord
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
        compassRotation = bearingToEvent - deviceHeading
    }
    
    // MARK: - Event Listener
    
    private func startEventListener() {
        let db = FirebaseManager.shared.db
        
        // Try events collection first
        let eventRef = db.collection("events").document(event.id)
        eventListener = eventRef.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    print("⚠️ EventNavigationModal: Error listening to event: \(error)")
                    // Try userEvents collection as fallback
                    self.tryUserEventsListener()
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    self.liveAttendeeCount = attendeeCount
                    print("📊 EventNavigationModal: Updated attendee count to \(attendeeCount)")
                } else if !(snapshot?.exists ?? false) {
                    // Document doesn't exist in events, try userEvents
                    self.tryUserEventsListener()
                }
            }
        }
    }
    
    private func tryUserEventsListener() {
        let db = FirebaseManager.shared.db
        eventListener?.remove()
        
        let eventRef = db.collection("userEvents").document(event.id)
        eventListener = eventRef.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    print("⚠️ EventNavigationModal: Error listening to userEvent: \(error)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    self.liveAttendeeCount = attendeeCount
                    print("📊 EventNavigationModal: Updated attendee count to \(attendeeCount)")
                }
            }
        }
    }
    
    // MARK: - Chat
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            do {
                try await chatService.sendMessage(
                    eventId: event.id,
                    text: text,
                    userId: currentUserId,
                    userName: currentUserName
                )
                
                // Track analytics
                AnalyticsService.shared.trackMessageSent(eventId: event.id, messageLength: text.count)
                
                await MainActor.run {
                    messageText = ""
                }
            } catch {
                print("❌ EventNavigationModal: Failed to send message: \(error)")
            }
        }
    }
}

// MARK: - Transport mode helper (temporarily disabled)
/*
private enum TransportMode: Hashable {
    case automobile
    case walking
    case transit
}
*/

// MARK: - Marquee Title
struct MarqueeTitle: View {
    let text: String
    private let speed: Double = 20 // points per second
    private let spacing: CGFloat = 40

    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var shouldAnimate: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                if shouldAnimate {
                    HStack(spacing: spacing) {
                        title
                        title
                    }
                    .offset(x: offset)
                    .onAppear { startAnimation(container: w) }
                } else {
                    HStack { Spacer(); title; Spacer() }
                }
            }
            .onAppear { containerWidth = w }
        }
        .frame(height: 28)
    }

    private var title: some View {
        Text(text)
            .font(.custom("Lato-Bold", size: 22))
            .foregroundColor(.white)
            .lineLimit(1)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear {
                            contentWidth = g.size.width
                            shouldAnimate = contentWidth > containerWidth
                        }
                }
            )
    }

    private func startAnimation(container: CGFloat) {
        guard contentWidth > container else { return }
        let cycle = (contentWidth + spacing) / speed
        withAnimation(.linear(duration: cycle).repeatForever(autoreverses: false)) {
            offset = -(contentWidth + spacing)
        }
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: String
    let author: String
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(
            alignment: isCurrentUser ? .trailing : .leading,
            spacing: 4
        ) {
            Text(author)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isCurrentUser
                    ? Color(hex: 0x02853E)
                    : Color(.systemGray5)
                )
                .foregroundColor(
                    isCurrentUser
                    ? .white
                    : .primary
                )
                .cornerRadius(16)
        }
        .frame(
            maxWidth: .infinity,
            alignment: isCurrentUser ? .trailing : .leading
        )
    }
}

// MARK: - Live Indicator View
struct LiveIndicatorView: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseScale = 2.0
                }
            }
    }
}
