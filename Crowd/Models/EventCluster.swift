//
//  EventCluster.swift
//  Crowd
//
//  Created by AI Assistant on 10/29/25.
//

import Foundation
import CoreLocation

struct EventCluster: Identifiable, Hashable {
    let id: String
    let events: [CrowdEvent]
    let centerCoordinate: CLLocationCoordinate2D
    
    var isSingleEvent: Bool {
        events.count == 1
    }
    
    var eventCount: Int {
        events.count
    }
    
    init(events: [CrowdEvent]) {
        self.id = events.map { $0.id }.sorted().joined(separator: "-")
        self.events = events
        
        // Calculate center coordinate as average of all event coordinates
        if events.isEmpty {
            self.centerCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        } else {
            let totalLat = events.reduce(0.0) { $0 + $1.latitude }
            let totalLon = events.reduce(0.0) { $0 + $1.longitude }
            self.centerCoordinate = CLLocationCoordinate2D(
                latitude: totalLat / Double(events.count),
                longitude: totalLon / Double(events.count)
            )
        }
    }
    
    // Helper to check if an event is within clustering distance
    static func isWithinClusterDistance(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D, threshold: Double = 5.0) -> Bool {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        let distance = location1.distance(from: location2)
        return distance <= threshold
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: EventCluster, rhs: EventCluster) -> Bool {
        lhs.id == rhs.id
    }
}

