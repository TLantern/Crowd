//
//  EventAnnotationView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct EventAnnotationView: View {
    let event: CrowdEvent
    var isInExpandedCluster: Bool = false
    
    var emoji: String {
        // Map category to emoji using EventCategory enum
        guard let categoryString = event.category,
              let eventCategory = EventCategory(rawValue: categoryString) else {
            return "📅" // Default matches calendar card
        }
        return eventCategory.emoji
    }
    
    var isOnFire: Bool {
        event.attendeeCount > 5
    }
    
    var scaleMultiplier: CGFloat {
        isInExpandedCluster ? 0.5 : 0.75  // Shrink to 50% when expanded
    }

    var body: some View {
        ZStack {
            // Fire effect for popular events (>5 people)
            if isOnFire {
                FireEffectView()
                    .offset(y: -10)
            }
            
            // Pulsing animation at the base
            PulseView()
                .offset(y: 65)
            
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
                    Text(emoji)
                        .font(.system(size: 40))
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Circle())
        .scaleEffect(scaleMultiplier)
        .accessibilityLabel("\(emoji) event pin, \(event.attendeeCount) attendees")
        .accessibilityHint("Double tap to view event details")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Pulse Animation View
struct PulseView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // First pulse ring
            Circle()
                .stroke(Color.blue.opacity(0.5), lineWidth: 3)
                .frame(width: 30, height: 30)
                .scaleEffect(isAnimating ? 2.5 : 1.0)
                .opacity(isAnimating ? 0.0 : 0.8)
            
            // Second pulse ring (delayed)
            Circle()
                .stroke(Color.blue.opacity(0.5), lineWidth: 3)
                .frame(width: 30, height: 30)
                .scaleEffect(isAnimating ? 2.5 : 1.0)
                .opacity(isAnimating ? 0.0 : 0.8)
                .animation(
                    Animation.easeOut(duration: 3.0)
                        .repeatForever(autoreverses: false)
                        .delay(1.0),
                    value: isAnimating
                )
            
            // Center dot
            Circle()
                .fill(Color.blue)
                .frame(width: 10, height: 10)
                .opacity(0.8)
        }
        .onAppear {
            withAnimation(
                Animation.easeOut(duration: 3.0)
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
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 3,
                attendeeCount: 3,
                tags: [],
                category: EventCategory.other.rawValue,
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
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
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
