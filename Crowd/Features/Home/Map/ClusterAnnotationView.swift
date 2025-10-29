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
    
    // Badge text showing count or "9+" for 10+
    private var badgeText: String {
        cluster.eventCount > 9 ? "9+" : "\(cluster.eventCount)"
    }
    
    var body: some View {
        // Collapsed: Show single cluster pin with badge
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
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Event cluster with \(cluster.eventCount) events")
        .accessibilityHint("Double tap to expand and see individual events")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            print("📍 Cluster tapped: \(cluster.eventCount) events")
            onTap()
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

