//
//  ClusterAnnotationView.swift
//  Crowd
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI
import CoreLocation

struct ClusterAnnotationView: View {
    let cluster: EventCluster
    let isExpanded: Bool
    let cameraDistance: Double
    let onTap: () -> Void
    let onEventTap: (CrowdEvent) -> Void
    
    @State private var animationTrigger = false
    
    // Convert meters to screen points based on map zoom and cluster size
    private var expansionRadius: CGFloat {
        // Approximate conversion: at 1000m altitude, ~1 meter = 0.3 points
        let metersToPoints = 1000.0 / cameraDistance * 0.3
        
        // Scale radius based on event count to prevent overlap
        // More events = larger circle for better spacing and clickability
        let baseRadius: Double = {
            switch cluster.eventCount {
            case 1...3: return 20.0
            case 4...6: return 30.0
            case 7...9: return 40.0
            default: return 50.0  // 10+ events
            }
        }()
        
        return CGFloat(baseRadius * metersToPoints)
    }
    
    // Badge text showing count or "9+" for 10+
    private var badgeText: String {
        cluster.eventCount > 9 ? "9+" : "\(cluster.eventCount)"
    }
    
    var body: some View {
        ZStack {
            if isExpanded && cluster.eventCount > 1 {
                // Expanded: Show events in circle
                ForEach(Array(cluster.events.enumerated()), id: \.element.id) { index, event in
                    let angle = (2.0 * .pi * Double(index)) / Double(cluster.eventCount)
                    let xOffset = expansionRadius * cos(angle)
                    let yOffset = expansionRadius * sin(angle)
                    
                    EventAnnotationView(event: event, isInExpandedCluster: true)
                        .contentShape(Circle())
                        .onTapGesture {
                            print("📍 Event tapped in expanded cluster: \(event.title)")
                            onEventTap(event)
                        }
                    .offset(
                        x: animationTrigger ? xOffset : 0,
                        y: animationTrigger ? yOffset : 0
                    )
                    .scaleEffect(animationTrigger ? 1.0 : 0.8)
                    .opacity(animationTrigger ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.3), value: animationTrigger)
                    .zIndex(100 + index)
                }
            } else {
                // Collapsed: Show single cluster pin
                ZStack {
                    // Use the first event's emoji for the cluster pin
                    if let firstEvent = cluster.events.first {
                        EventAnnotationView(event: firstEvent, isInExpandedCluster: false)
                    }
                    
                    // Badge showing event count (only if > 1)
                    if cluster.eventCount > 1 {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                    
                                    Circle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(badgeText)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                }
                                .offset(x: 10, y: -10)
                            }
                            Spacer()
                        }
                        .frame(width: 90, height: 90)
                        .scaleEffect(0.75) // Match EventAnnotationView scale
                    }
                }
                .onTapGesture {
                    print("📍 Cluster tapped: \(cluster.eventCount) events")
                    onTap()
                }
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            print("📍 Cluster expansion state changed: \(newValue)")
            if newValue {
                // Trigger expansion animation
                withAnimation(.easeOut(duration: 0.3)) {
                    animationTrigger = true
                }
            } else {
                // Trigger collapse animation
                withAnimation(.easeOut(duration: 0.3)) {
                    animationTrigger = false
                }
            }
        }
        .onAppear {
            // Set initial state
            animationTrigger = isExpanded
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        // Single event cluster
        ClusterAnnotationView(
            cluster: EventCluster(events: [
                CrowdEvent(
                    id: "1",
                    title: "Single Event",
                    hostId: "123",
                    hostName: "Host",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date(),
                    endsAt: Date().addingTimeInterval(3600),
                    createdAt: Date(),
                    signalStrength: 3,
                    attendeeCount: 5,
                    tags: [],
                    category: "hangout",
                    description: "Test"
                )
            ]),
            isExpanded: false,
            cameraDistance: 1000,
            onTap: { print("Tapped") },
            onEventTap: { _ in print("Event tapped") }
        )
        
        // Multi-event cluster
        ClusterAnnotationView(
            cluster: EventCluster(events: [
                CrowdEvent(
                    id: "1",
                    title: "Event 1",
                    hostId: "123",
                    hostName: "Host",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date(),
                    endsAt: Date().addingTimeInterval(3600),
                    createdAt: Date(),
                    signalStrength: 3,
                    attendeeCount: 5,
                    tags: [],
                    category: "hangout",
                    description: "Test"
                ),
                CrowdEvent(
                    id: "2",
                    title: "Event 2",
                    hostId: "124",
                    hostName: "Host 2",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date(),
                    endsAt: Date().addingTimeInterval(3600),
                    createdAt: Date(),
                    signalStrength: 4,
                    attendeeCount: 8,
                    tags: [],
                    category: "party",
                    description: "Test 2"
                ),
                CrowdEvent(
                    id: "3",
                    title: "Event 3",
                    hostId: "125",
                    hostName: "Host 3",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date(),
                    endsAt: Date().addingTimeInterval(3600),
                    createdAt: Date(),
                    signalStrength: 2,
                    attendeeCount: 3,
                    tags: [],
                    category: "study",
                    description: "Test 3"
                )
            ]),
            isExpanded: false,
            cameraDistance: 1000,
            onTap: { print("Cluster tapped") },
            onEventTap: { _ in print("Event tapped") }
        )
    }
    .padding()
}

