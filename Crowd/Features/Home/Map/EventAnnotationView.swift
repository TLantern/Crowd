//
//  EventAnnotationView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct EventAnnotationView: View {
    let event: CrowdEvent
    
    var emoji: String {
        // Map category to emoji using EventCategory enum
        guard let categoryString = event.category,
              let eventCategory = EventCategory(rawValue: categoryString) else {
            return "🔥" // Default fallback
        }
        return eventCategory.emoji
    }

    var body: some View {
        ZStack {
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
        .scaleEffect(0.75)  // Reduced by 25% from 1.0
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

#Preview {
    EventAnnotationView(event: CrowdEvent(
        id: "1",
        title: "Test Event",
        hostId: "123",
        hostName: "Test User",
        latitude: 33.2099,
        longitude: -97.1515,
        radiusMeters: 60,
        startsAt: Date(),
        endsAt: Date().addingTimeInterval(3600),
        createdAt: Date(),
        signalStrength: 3,
        attendeeCount: 5,
        tags: [],
        category: "hangout",
        description: "Test"
    ))
}
