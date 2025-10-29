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

struct EventNavigationModal: View {
    let event: CrowdEvent
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = EventChatService.shared
    @StateObject private var locationService = AppEnvironment.current.location
    @StateObject private var motionManager = MotionManager()
    
    @State private var chatMessage = ""
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var deviceHeading: Double = 0
    @State private var distanceToEvent: Double = 0
    @State private var bearingToEvent: Double = 0
    @State private var compassRotation: Double = 0
    @State private var locationUpdateTimer: Timer?
    @State private var keyboardHeight: CGFloat = 0
    @State private var isChatMinimized: Bool = false
    
    @EnvironmentObject private var appState: AppState
    @FocusState private var isChatFocused: Bool
    
    @State private var currentUserId: String = "unknown"
    
    var currentUserName: String {
        appState.sessionUser?.displayName ?? "You"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Full UNT green background
                Color(hex: 0x02853E)
                    .ignoresSafeArea()
                
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        // Top area with green background and close button
                        ZStack {
                            Color(hex: 0x02853E)
                                .frame(height: 40)

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
                        
                        // White container for map and chat
                        VStack(spacing: 0) {
                            // Top map route view (dynamic)
                            RouteMapView(destination: event.coordinates, userCoordinate: userLocation)
                            .frame(height: isChatMinimized ? geo.size.height * 0.85 - 100 : geo.size.height * 0.5 - 100)
                            .background(Color.white)

                            // Bottom (chat) - adjustable by splitter
                            VStack(spacing: 0) {
                        // Chat header
                        HStack {
                            Text("Event Chat")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Spacer()
                            
                            Button("Close") {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
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
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                    isChatMinimized = false
                                }
                            }
                        }
                        
                        if !isChatMinimized {
                            // Chat messages
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
                                    if let lastMessage = chatService.messages.last {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if !isChatMinimized {
                            // Chat input
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
                            .padding(.bottom, max(12, keyboardHeight > 0 ? keyboardHeight - 20 : 12))
                            .background(.ultraThinMaterial)
                        }
                        .background(Color.white)
                    }
                    .frame(height: isChatMinimized ? 56 : geo.size.height * 0.5)
                    .background(Color.white)
                }
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            // Load draft message for this event
            if let draft = UserDefaults.standard.string(forKey: draftKey()) {
                chatMessage = draft
            }
            
            // Ensure user is authenticated
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
            
            // Start listening after a short delay to ensure currentUserId is set
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                chatService.startListening(eventId: event.id, currentUserId: currentUserId)
            }
        }
        .onDisappear {
            // Persist draft on close
            UserDefaults.standard.set(chatMessage, forKey: draftKey())
            stopLocationUpdates()
            stopMotionUpdates()
            chatService.stopListening()
        }
        .onReceive(motionManager.$heading) { newHeading in
            deviceHeading = newHeading
        }
        .onAppear {
            if let location = userLocation {
                updateDistanceAndBearing(to: event.coordinates, from: location)
            }
        }
        .onChange(of: deviceHeading) { _, newHeading in
            updateCompassRotation()
        }
        .onChange(of: bearingToEvent) { _, newBearing in
            updateCompassRotation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
    
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
        if let category = event.category, let cat = EventCategory(rawValue: category) {
            return cat.emoji
        }
        return EventCategory.other.emoji
    }
    
    private func startLocationUpdates() {
        locationService.requestSoftAuth()
        locationService.startUpdatingLocation()
        
        // Get current location
        if let currentLocation = locationService.lastKnown {
            userLocation = currentLocation
            updateDistanceAndBearing(to: event.coordinates, from: currentLocation)
        }
        
        // Start timer to check for location updates
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let newLocation = locationService.lastKnown, 
               userLocation == nil || 
               abs(newLocation.latitude - (userLocation?.latitude ?? 0)) > 0.0001 ||
               abs(newLocation.longitude - (userLocation?.longitude ?? 0)) > 0.0001 {
                userLocation = newLocation
                updateDistanceAndBearing(to: event.coordinates, from: newLocation)
            }
        }
    }
    
    private func stopLocationUpdates() {
        locationService.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func startMotionUpdates() {
        motionManager.startUpdates()
    }
    
    private func stopMotionUpdates() {
        motionManager.stopUpdates()
    }
    
    private func updateDistanceAndBearing(to eventCoord: CLLocationCoordinate2D, from userCoord: CLLocationCoordinate2D) {
        let userLocation = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let eventLocation = CLLocation(latitude: eventCoord.latitude, longitude: eventCoord.longitude)
        
        distanceToEvent = userLocation.distance(from: eventLocation)
        bearingToEvent = calculateBearing(from: userCoord, to: eventCoord)
        
        updateCompassRotation()
    }
    
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func updateCompassRotation() {
        compassRotation = bearingToEvent - deviceHeading
    }
    
    private func sendMessage() {
        guard !chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            do {
                try await chatService.sendMessage(
                    eventId: event.id,
                    text: chatMessage,
                    userId: currentUserId,
                    userName: currentUserName
                )
                
                await MainActor.run {
                    chatMessage = ""
                }
            } catch {
                print("❌ Failed to send message: \(error.localizedDescription)")
            }
        }
    }

    private func draftKey() -> String { "chat_draft_\(event.id)" }
}

// Motion Manager for device heading
@MainActor
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var heading: Double = 0
    
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            
            let heading = atan2(motion.magneticField.field.y, motion.magneticField.field.x) * 180 / .pi
            let adjustedHeading = (heading + 360).truncatingRemainder(dividingBy: 360)
            
            DispatchQueue.main.async {
                self?.heading = adjustedHeading
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// Chat Message Bubble (reused from EventDetailSheet)
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
