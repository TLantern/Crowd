//
//  EventAnnotationView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import FirebaseFirestore

struct EventAnnotationView: View {
    let event: CrowdEvent
    var isInExpandedCluster: Bool = false
    var currentUserId: String? = nil
    var isOnMainCampus: Bool = false
    @ObservedObject private var chatNotificationService = ChatNotificationService.shared
    @ObservedObject private var attendedEventsService = AttendedEventsService.shared
    @State private var liveAttendeeCount: Int = 0
    @State private var eventListener: ListenerRegistration?
    
    var emoji: String { TagEmoji.emoji(for: event.tags, fallbackCategory: event.category) }
    
    var isOnFire: Bool {
        liveAttendeeCount > 2
    }
    
    /// Check if this event belongs to the current user
    var isUserOwned: Bool {
        guard let userId = currentUserId else { return false }
        return event.hostId == userId
    }
    
    var hasUnread: Bool {
        attendedEventsService.isAttendingEvent(event.id) && chatNotificationService.hasUnreadMessages(eventId: event.id)
    }
    
    var scaleMultiplier: CGFloat {
        isInExpandedCluster ? 0.5 : 0.75  // Shrink to 50% when expanded
    }
    
    var isSchoolHosted: Bool {
        event.sourceURL != nil
    }

    var body: some View {
        ZStack {
            // Fire effect for popular events (>2 people)
            if isOnFire {
                FireEffectView()
                    .offset(y: -10)
            }
            
            // Pulsing animation for user-owned events (glowing ring around the pin)
            if isUserOwned {
                PulseView(color: .orange)
                    .offset(y: 0) // Center on the pin circle
            }
            
            // Pointer at the bottom (rendered first, behind circle)
            Triangle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .overlay(
                    Triangle()
                        .stroke(Color.black, lineWidth: 2)
                )
                .rotationEffect(.degrees(180))
                .offset(y: 54)
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            
            // Circular head of the pin (rendered on top to cover triangle's top edge)
            Circle()
                .fill(Color.white)
                .frame(width: 90, height: 90)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .overlay(
                    // Always show emoji
                    Text(emoji)
                        .font(.system(size: 40, weight: .regular))
                )
                .overlay(
                    // Red dot indicator for unread messages (top-left corner)
                    Group {
                        if hasUnread {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .offset(x: -30, y: -30)
                        }
                    }
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Circle())
        .scaleEffect(scaleMultiplier)
        .onAppear {
            liveAttendeeCount = event.attendeeCount
            startEventListener()
        }
        .onDisappear {
            stopEventListener()
        }
        .accessibilityLabel("\(emoji) event pin, \(liveAttendeeCount) attendees")
        .accessibilityHint("Double tap to view event details")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Event Listener
    
    private func startEventListener() {
        let db = FirebaseManager.shared.db
        
        // Try events collection first
        let eventRef = db.collection("events").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ EventAnnotationView: Error listening to event: \(error)")
                    // Try userEvents collection as fallback
                    tryUserEventsListener()
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                } else if !(snapshot?.exists ?? false) {
                    // Document doesn't exist in events, try userEvents
                    tryUserEventsListener()
                }
            }
        }
    }
    
    private func tryUserEventsListener() {
        let db = FirebaseManager.shared.db
        eventListener?.remove()
        
        let eventRef = db.collection("userEvents").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ EventAnnotationView: Error listening to userEvent: \(error)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                }
            }
        }
    }
    
    private func stopEventListener() {
        eventListener?.remove()
        eventListener = nil
    }
}

// MARK: - Pulse Animation View
/// A reusable pulse animation component that displays a glowing ring expanding and fading out.
/// Used to highlight user-owned event pins on the map.
struct PulseView: View {
    @State private var isAnimating = false
    var color: Color = .blue
    
    var body: some View {
        // Single expanding ring for better performance
        Circle()
            .stroke(color.opacity(0.6), lineWidth: 6.0)
            .frame(width: 90, height: 90)
            .scaleEffect(isAnimating ? 2.0 : 1.0)
            .opacity(isAnimating ? 0.0 : 0.8)
            .allowsHitTesting(false) // Ensure taps pass through to the pin
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Fire Effect View
struct FireEffectView: View {
    @State private var isFlickering = false
    
    var body: some View {
        ZStack {
            // Multiple flame layers for depth - BIGGER
            FlameShape(flameStyle: .large)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange, Color.red.opacity(0.8)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 180, height: 200)
                .opacity(isFlickering ? 0.85 : 0.95)
                .scaleEffect(isFlickering ? 0.95 : 1.0)
                .blur(radius: 1.5)
            
            FlameShape(flameStyle: .medium)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.7)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 150, height: 170)
                .opacity(isFlickering ? 0.9 : 0.8)
                .scaleEffect(isFlickering ? 1.05 : 1.0)
                .blur(radius: 1)
            
            FlameShape(flameStyle: .small)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow, Color.white.opacity(0.8)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 120, height: 140)
                .opacity(isFlickering ? 0.95 : 0.85)
                .scaleEffect(isFlickering ? 1.0 : 0.95)
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 0.3)
                    .repeatForever(autoreverses: true)
            ) {
                isFlickering = true
            }
        }
    }
}

// MARK: - Flame Shape
struct FlameShape: Shape {
    enum FlameStyle {
        case small, medium, large
    }
    
    let flameStyle: FlameStyle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Bottom center (base of flame)
        path.move(to: CGPoint(x: width / 2, y: height))
        
        // Create flame shape with organic curves
        // Left side flame
        path.addCurve(
            to: CGPoint(x: width * 0.15, y: height * 0.6),
            control1: CGPoint(x: width * 0.25, y: height * 0.9),
            control2: CGPoint(x: width * 0.1, y: height * 0.75)
        )
        
        // Left tip curve
        path.addCurve(
            to: CGPoint(x: width * 0.35, y: height * 0.2),
            control1: CGPoint(x: width * 0.2, y: height * 0.45),
            control2: CGPoint(x: width * 0.25, y: height * 0.3)
        )
        
        // Top center tip
        path.addCurve(
            to: CGPoint(x: width / 2, y: 0),
            control1: CGPoint(x: width * 0.4, y: height * 0.1),
            control2: CGPoint(x: width * 0.45, y: height * 0.05)
        )
        
        // Right tip curve
        path.addCurve(
            to: CGPoint(x: width * 0.65, y: height * 0.2),
            control1: CGPoint(x: width * 0.55, y: height * 0.05),
            control2: CGPoint(x: width * 0.6, y: height * 0.1)
        )
        
        // Right side flame
        path.addCurve(
            to: CGPoint(x: width * 0.85, y: height * 0.6),
            control1: CGPoint(x: width * 0.75, y: height * 0.3),
            control2: CGPoint(x: width * 0.8, y: height * 0.45)
        )
        
        // Back to bottom
        path.addCurve(
            to: CGPoint(x: width / 2, y: height),
            control1: CGPoint(x: width * 0.9, y: height * 0.75),
            control2: CGPoint(x: width * 0.75, y: height * 0.9)
        )
        
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        // Regular event (not on fire)
        VStack {
            EventAnnotationView(event: CrowdEvent(
                id: "1",
                title: "Regular Event",
                hostId: "123",
                hostName: "Test User",
                latitude: 33.2099,
                longitude: -97.1515,
                radiusMeters: 60,
                time: Date(),
                createdAt: Date(),
                signalStrength: 3,
                attendeeCount: 3,
                tags: [],
                category: EventCategory.chillHangout.rawValue,
                description: "Test"
            ))
            Text("Regular Event (3 people)")
                .font(.caption)
        }
        
        // Popular event (on fire 🔥)
        VStack {
            EventAnnotationView(event: CrowdEvent(
                id: "2",
                title: "Hot Event",
                hostId: "456",
                hostName: "Popular Host",
                latitude: 33.2099,
                longitude: -97.1515,
                radiusMeters: 60,
                time: Date(),
                createdAt: Date(),
                signalStrength: 5,
                attendeeCount: 15,
                tags: [],
                category: "party",
                description: "Lit party"
            ))
            Text("Popular Event (15 people) 🔥")
                .font(.caption)
        }
    }
    .padding()
}
