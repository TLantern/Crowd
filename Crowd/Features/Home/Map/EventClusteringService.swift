//
//  EventClusteringService.swift
//  Crowd
//
//  Created by AI Assistant on 10/29/25.
//

import Foundation
import CoreLocation

class EventClusteringService {
    /// Clusters events that are within the specified distance threshold
    /// - Parameters:
    ///   - events: Array of CrowdEvents to cluster
    ///   - distanceThreshold: Maximum distance in meters to group events (default: 30m)
    /// - Returns: Array of EventClusters (single events are treated as 1-event clusters)
    static func clusterEvents(_ events: [CrowdEvent], distanceThreshold: Double = 30.0) -> [EventCluster] {
        guard !events.isEmpty else { return [] }
        
        var processedEventIds = Set<String>()
        var clusters: [EventCluster] = []
        
        for event in events {
            // Skip if already processed
            if processedEventIds.contains(event.id) {
                continue
            }
            
            // Find all nearby events within threshold
            var clusterEvents: [CrowdEvent] = [event]
            processedEventIds.insert(event.id)
            
            // Check all other events
            for otherEvent in events {
                if processedEventIds.contains(otherEvent.id) {
                    continue
                }
                
                // Check if within clustering distance
                if EventCluster.isWithinClusterDistance(
                    event.coordinates,
                    otherEvent.coordinates,
                    threshold: distanceThreshold
                ) {
                    clusterEvents.append(otherEvent)
                    processedEventIds.insert(otherEvent.id)
                }
            }
            
            // Create cluster with all found events
            let cluster = EventCluster(events: clusterEvents)
            clusters.append(cluster)
        }
        
        print("📍 Clustered \(events.count) events into \(clusters.count) clusters")
        print("   - Single events: \(clusters.filter { $0.isSingleEvent }.count)")
        print("   - Multi-event clusters: \(clusters.filter { !$0.isSingleEvent }.count)")
        
        return clusters
    }
}

