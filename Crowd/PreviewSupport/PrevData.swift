//
//  PrevData.swift
//  Crowd
//

import Foundation

enum PrevData {
    static let events: [CrowdEvent] = [
        .init(
            id: "1",
            title: "Fry St. Jam",
            hostId: "u1",
            hostName: "Alex",
            latitude: 33.2089,
            longitude: -97.1439,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: .now,
            signalStrength: 12,
            attendeeCount: 24,
            tags: ["music"],
            category: "Music/Concert",
            description: "📍 Fry Street\n⏰ Starting now\n🎵 Live music vibes"
        ),
        .init(
            id: "2",
            title: "Dorm Game Night",
            hostId: "u2",
            hostName: "Jordan",
            latitude: 33.2080,
            longitude: -97.1525,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: .now,
            signalStrength: 7,
            attendeeCount: 10,
            tags: ["games"],
            category: "Gaming",
            description: "📍 Victory Hall Dorms\n⏰ Starting now\n🎮 Casual gaming session"
        ),
        .init(
            id: "3",
            title: "Library Study Sesh",
            hostId: "u3",
            hostName: "Casey",
            latitude: 33.2095,
            longitude: -97.1490,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: .now,
            signalStrength: 4,
            attendeeCount: 3,
            tags: ["study"],
            category: "Study Group",
            description: "📍 Willis Library\n⏰ Starting now\n📚 Quiet study time"
        )
    ]
}
