//
//  EventNavigationModal.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI
import CoreLocation
import CoreMotion
import Combine

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
    
    @StateObject private var chatService = EventChatService.shared
    @StateObject private var locationService = AppEnvironment.current.location
    @StateObject private var motionManager = MotionManager()
    
    @FocusState private var isChatFocused: Bool
    
    @State private var chatMessage: String = ""
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var deviceHeading: Double = 0
    @State private var distanceToEvent: Double = 0
    @State private var bearingToEvent: Double = 0
    @State private var compassRotation: Double = 0
    @State private var locationUpdateTimer: Timer?
    @State private var keyboardHeight: CGFloat = 0
    @State private var isChatMinimized: Bool = false
    
    @State private var currentUserId: String = "unknown"
    
    // current user's display name
    private var currentUserName: String {
        appState.sessionUser?.displayName ?? "You"
    }
    
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
                        ZStack {
                            Color(hex: 0x02853E)
                                .frame(height: 40)

                            // Center title: emoji + event name
                            Text("\(eventEmoji) \(event.title)")
                                .font(.custom("Lato-Bold", size: 32))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .overlay(
                                    Text("\(eventEmoji) \(event.title)")
                                        .font(.custom("Lato-Bold", size: 32))
                                        .foregroundColor(.black.opacity(0.3))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .offset(x: 1, y: 1)
                                        .blendMode(.multiply)
                                )

                            HStack {
                                Spacer()
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 12)
                            }
                        }
                        .padding(.top, 20)
                        
                        // White container for map + chat
                        VStack(spacing: 0) {
                            // MAP AREA
                            RouteMapView(
                                destination: event.coordinates,
                                userCoordinate: userLocation
                            )
                            .frame(
                                height: isChatMinimized
                                ? geo.size.height * 0.85 - 100
                                : geo.size.height * 0.5 - 100
                            )
                            .background(Color.white)
                            
                            // CHAT AREA
                            VStack(spacing: 0) {
                                // Chat header
                                HStack {
                                    Text("Event Chat")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Button("Close") {
                                        withAnimation(
                                            .spring(
                                                response: 0.28,
                                                dampingFraction: 0.9
                                            )
                                        ) {
                                            isChatMinimized = true
                                            isChatFocused = false
                                        }
                                    }
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: 0x02853E))
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isChatMinimized {
                                        withAnimation(
                                            .spring(
                                                response: 0.28,
                                                dampingFraction: 0.9
                                            )
                                        ) {
                                            isChatMinimized = false
                                        }
                                    }
                                }
                                
                                // Messages list
                                if !isChatMinimized {
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
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                        }
                                        .onChange(of: chatService.messages.count) { _, _ in
                                            if let last = chatService.messages.last {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo(last.id, anchor: .bottom)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Input bar
                                if !isChatMinimized {
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
                                                .foregroundColor(
                                                    chatMessage.isEmpty
                                                    ? .gray
                                                    : Color(hex: 0x02853E)
                                                )
                                        }
                                        .disabled(chatMessage.isEmpty)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .padding(.bottom,
                                             max(
                                                12,
                                                keyboardHeight > 0
                                                ? keyboardHeight - 20
                                                : 12
                                             )
                                    )
                                    .background(.ultraThinMaterial)
                                }
                            }
                            .frame(
                                height: isChatMinimized
                                ? 56
                                : geo.size.height * 0.5
                            )
                            .background(Color.white)
                        }
                    }
                }
                .navigationBarHidden(true)
            }
        }
        // MARK: lifecycle / listeners
        .onAppear {
            // restore draft
            if let draft = UserDefaults.standard.string(forKey: draftKey()) {
                chatMessage = draft
            }
            
            // ensure user auth
            Task {
                if let userId = FirebaseManager.shared.getCurrentUserId() {
                    await MainActor.run {
                        currentUserId = userId
                    }
                } else {
                    do {
                        let userId = try await FirebaseManager.shared.signInAnonymously()
                        await MainActor.run {
                            currentUserId = userId
                        }
                        print("✅ EventNavigationModal: User signed in anonymously: \(userId)")
                    } catch {
                        print("❌ EventNavigationModal: Failed to sign in anonymously: \(error)")
                    }
                }
            }
            
            startLocationUpdates()
            startMotionUpdates()
            
            // start chat listener after short delay so we have currentUserId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                chatService.startListening(
                    eventId: event.id,
                    currentUserId: currentUserId
                )
            }
        }
        .onDisappear {
            // save draft
            UserDefaults.standard.set(chatMessage, forKey: draftKey())
            
            stopLocationUpdates()
            stopMotionUpdates()
            chatService.stopListening()
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )
        ) { notification in
            if let frame = notification.userInfo?[
                UIResponder.keyboardFrameEndUserInfoKey
            ] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { _ in
            keyboardHeight = 0
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
    
    // MARK: - Chat
    
    private func sendMessage() {
        guard !chatMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        else { return }
        
        // Ensure user is authenticated before sending
        guard let authUserId = FirebaseManager.shared.getCurrentUserId() else {
            print("❌ EventNavigationModal: User not authenticated, cannot send message")
            return
        }
        
        // Use the authenticated user ID instead of the stored currentUserId
        Task {
            do {
                try await chatService.sendMessage(
                    eventId: event.id,
                    text: chatMessage,
                    userId: authUserId,
                    userName: currentUserName
                )
                
                await MainActor.run {
                    // Clear the message input
                    chatMessage = ""
                    
                    // Close the keyboard
                    isChatFocused = false
                    
                    // Reset chat to minimized state (first state)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        isChatMinimized = true
                    }
                }
            } catch {
                print("❌ Failed to send message: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Draft key
    
    private func draftKey() -> String {
        "chat_draft_\(event.id)"
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
