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
            latitude: 33.2089,
            longitude: -97.1439,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: .now,
            signalStrength: 12,
            attendeeCount: 24,
            tags: ["music"]
        ),
        .init(
            id: "2",
            title: "Dorm Game Night",
            hostId: "u2",
            latitude: 33.2080,
            longitude: -97.1525,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: .now,
            signalStrength: 7,
            attendeeCount: 10,
            tags: ["games"]
        )
    ]
}
