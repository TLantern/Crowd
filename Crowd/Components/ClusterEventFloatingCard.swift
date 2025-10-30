//
//  ClusterEventFloatingCard.swift
//  Crowd
//
//  Created by AI Assistant on 10/30/25.
//

import SwiftUI

struct ClusterEventFloatingCard: View {
    let cluster: EventCluster
    let onSelect: (CrowdEvent) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with count
            HStack {
                Text("\(cluster.eventCount) Events Here")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            
            Divider()
            
            // Scrollable event list
            ScrollView(showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(cluster.events) { event in
                        Button(action: { 
                            onSelect(event)
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                // Event emoji
                                Text(event.categoryEmoji)
                                    .font(.system(size: 32))
                                    .frame(width: 44, height: 44)
                                
                                // Event details
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(event.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                    
                                    if let timeText = event.dateFormatted {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .font(.caption)
                                            Text(timeText)
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    // Attendee count
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                            .font(.caption)
                                        Text("\(event.attendeeCount) attending")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                // Chevron
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color(uiColor: .systemBackground))
                        }
                        .buttonStyle(.plain)
                        
                        if event.id != cluster.events.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .frame(maxHeight: min(CGFloat(cluster.eventCount) * 90, 320))
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
        .frame(width: 340)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Arrow Pointer Shape
struct ArrowPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Triangle pointing down
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Helper Extension for Event Category Emoji
extension CrowdEvent {
    var categoryEmoji: String {
        guard let categoryString = category,
              let eventCategory = EventCategory(rawValue: categoryString) else {
            return "🔥"
        }
        return eventCategory.emoji
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        ClusterEventFloatingCard(
            cluster: EventCluster(events: [
                CrowdEvent(
                    id: "1",
                    title: "Study Session @ Library",
                    hostId: "123",
                    hostName: "Alex",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date().addingTimeInterval(3600),
                    endsAt: Date().addingTimeInterval(7200),
                    createdAt: Date(),
                    signalStrength: 3,
                    attendeeCount: 5,
                    tags: ["study"],
                    category: "study",
                    description: "Quiet study"
                ),
                CrowdEvent(
                    id: "2",
                    title: "Basketball Pickup Game",
                    hostId: "124",
                    hostName: "Jordan",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date().addingTimeInterval(1800),
                    endsAt: Date().addingTimeInterval(5400),
                    createdAt: Date(),
                    signalStrength: 4,
                    attendeeCount: 12,
                    tags: ["sports"],
                    category: "sports",
                    description: "Casual game"
                ),
                CrowdEvent(
                    id: "3",
                    title: "Coffee & Chat",
                    hostId: "125",
                    hostName: "Sam",
                    latitude: 33.21,
                    longitude: -97.15,
                    radiusMeters: 60,
                    startsAt: Date(),
                    endsAt: Date().addingTimeInterval(3600),
                    createdAt: Date(),
                    signalStrength: 2,
                    attendeeCount: 3,
                    tags: ["hangout"],
                    category: "hangout",
                    description: "Chill vibes"
                )
            ]),
            onSelect: { event in
                print("Selected: \(event.title)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
        .padding()
    }
}

