//
//  EventNavigationModal.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI
import CoreLocation
import MapKit
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
    
    @StateObject private var locationService = AppEnvironment.current.location
    @StateObject private var motionManager = MotionManager()
    
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var deviceHeading: Double = 0
    @State private var distanceToEvent: Double = 0
    @State private var bearingToEvent: Double = 0
    @State private var compassRotation: Double = 0
    @State private var locationUpdateTimer: Timer?
    
    @State private var currentUserId: String = "unknown"
    @State private var transport: MKDirectionsTransportType = .automobile
    
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

                            // Center title: slow-moving marquee when long
                            MarqueeTitle(text: "\(eventEmoji) \(event.title)")
                                .padding(.horizontal, 5)
                                .padding(.bottom, 4)

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
                        
                        // White container for map and transport picker
                        VStack(spacing: 0) {
                            // MAP AREA
                            RouteMapView(
                                destination: event.coordinates,
                                userCoordinate: userLocation
                            )
                            .frame(height: geo.size.height * 0.85 - 100)
                            .background(Color.white)

                            // Transport mode picker below the map
                            Picker("", selection: $transport) {
                                Text("Car").tag(MKDirectionsTransportType.automobile)
                                Text("Walk").tag(MKDirectionsTransportType.walking)
                                Text("Transit").tag(MKDirectionsTransportType.transit)
                            }
                            .pickerStyle(.segmented)
                            .padding()
                        }
                        .ignoresSafeArea(edges: .top)
                    }
                }
                .navigationBarHidden(true)
            }
        }
        // MARK: lifecycle / listeners
        .onAppear {
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
        }
        .onDisappear {
            stopLocationUpdates()
            stopMotionUpdates()
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
    
    // Chat removed
}

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
            .font(.custom("Lato-Bold", size: 12))
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
