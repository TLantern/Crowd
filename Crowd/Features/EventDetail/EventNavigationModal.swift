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
    
    @EnvironmentObject private var appState: AppState
    @FocusState private var isChatFocused: Bool
    
    var currentUserId: String {
        FirebaseManager.shared.getCurrentUserId() ?? "unknown"
    }
    
    var currentUserName: String {
        appState.sessionUser?.displayName ?? "You"
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Top map route view (50%)
                    RouteMapView(destination: event.coordinates, userCoordinate: userLocation)
                    .frame(height: geo.size.height * 0.5)
                    .padding(.top, 40)

                    // Bottom (chat) - adjustable by splitter
                    VStack(spacing: 0) {
                        // Chat header
                        HStack {
                            Text("Event Chat")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Spacer()
                            
                            Button("Close") {
                                dismiss()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: 0x02853E))
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        
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
                        
                        // Chat input
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $chatMessage)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                                .focused($isChatFocused)
                            
                            Button {
                                // Posting disabled per requirement
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                            }
                            .disabled(true)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .padding(.bottom, 12) // move input up from bottom
                        .background(.ultraThinMaterial)
                    }
                    .frame(height: geo.size.height * 0.5)
                }
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            // Load draft message for this event
            if let draft = UserDefaults.standard.string(forKey: draftKey()) {
                chatMessage = draft
            }
            startLocationUpdates()
            startMotionUpdates()
            chatService.startListening(eventId: event.id, currentUserId: currentUserId)
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
