//
//  MockEventRepository.swift
//  Crowd
//

import Foundation
import CoreLocation

actor MockEventRepository: EventRepository {
    private var store: [String: CrowdEvent] = [:]
    private var seeded = false

    func fetchEvents(in region: CampusRegion) async throws -> [CrowdEvent] {
        // Read spec once (pure data), then seed using that spec.
        let spec = await region.spec
        if !seeded {
            seed(using: spec, regionName: region.rawValue)
            seeded = true
        }

        let center = spec.center
        let maxMeters: Double = 600

        func meters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> CLLocationDistance {
            let a = CLLocation(latitude: lat1, longitude: lon1)
            let b = CLLocation(latitude: lat2, longitude: lon2)
            return a.distance(from: b)
        }

        return store.values
            .filter {
                meters(lat1: $0.latitude, lon1: $0.longitude,
                       lat2: center.latitude, lon2: center.longitude) <= maxMeters
            }
            .sorted { $0.signalStrength > $1.signalStrength }
    }

    func create(event: CrowdEvent) async throws {
        store[event.id] = event
    }

    func join(eventId: String, userId: String) async throws {
        guard var e = store[eventId] else { return }
        e.attendeeCount += 1
        e.signalStrength += 2
        store[eventId] = e
    }
    
    func deleteEvent(eventId: String) async throws {
        store.removeValue(forKey: eventId)
    }

    func boostSignal(eventId: String, delta: Int) async throws {
        guard var e = store[eventId] else { return }
        e.signalStrength += delta
        store[eventId] = e
    }

    // MARK: - Private

    private func seed(using spec: RegionSpec, regionName: String) {
        let c = spec.center

        let e1 = CrowdEvent(
            id: UUID().uuidString,
            title: "Pop-up on \(regionName)",
            hostId: "u1",
            hostName: "Alex",
            latitude: c.latitude + 0.0009,
            longitude: c.longitude + 0.0007,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: Date(),
            signalStrength: 8,
            attendeeCount: 14,
            tags: ["music"],
            category: "Music/Concert",
            description: "📍 \(regionName)\n⏰ Starting now\n🎵 Live music pop-up"
        )

        let e2 = CrowdEvent(
            id: UUID().uuidString,
            title: "Game Night",
            hostId: "u2",
            hostName: "Jordan",
            latitude: c.latitude - 0.0011,
            longitude: c.longitude - 0.0005,
            radiusMeters: 60,
            startsAt: nil,
            endsAt: nil,
            createdAt: Date(),
            signalStrength: 5,
            attendeeCount: 9,
            tags: ["games"],
            category: "Gaming",
            description: "📍 \(regionName)\n⏰ Starting now\n🎮 Casual game night"
        )

        store[e1.id] = e1
        store[e2.id] = e2
    }
}
