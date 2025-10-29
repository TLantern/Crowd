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
    ///   - distanceThreshold: Maximum distance in meters to group events (default: 5m)
    /// - Returns: Array of EventClusters (single events are treated as 1-event clusters)
    static func clusterEvents(_ events: [CrowdEvent], distanceThreshold: Double = 5.0) -> [EventCluster] {
        guard !events.isEmpty else { return [] }
        
        // For large datasets, use spatial bucketing
        if events.count > 100 {
            return clusterEventsOptimized(events, distanceThreshold: distanceThreshold)
        }
        
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
    
    /// Optimized clustering for large datasets using spatial bucketing
    private static func clusterEventsOptimized(_ events: [CrowdEvent], distanceThreshold: Double) -> [EventCluster] {
        // Grid-based spatial bucketing
        let gridSize = distanceThreshold * 2 // 10m grid cells for 5m threshold
        var grid: [String: [CrowdEvent]] = [:]
        
        // Bucket events into grid cells
        for event in events {
            let cellX = Int(event.latitude / gridSize * 10000)
            let cellY = Int(event.longitude / gridSize * 10000)
            let cellKey = "\(cellX),\(cellY)"
            grid[cellKey, default: []].append(event)
        }
        
        // Only check events in same/adjacent cells
        var processedEventIds = Set<String>()
        var clusters: [EventCluster] = []
        
        for (_, cellEvents) in grid {
            for event in cellEvents {
                if processedEventIds.contains(event.id) { continue }
                
                var clusterEvents: [CrowdEvent] = [event]
                processedEventIds.insert(event.id)
                
                // Check only nearby cells (same cell for now - can extend to 9 cells if needed)
                for otherEvent in cellEvents {
                    if processedEventIds.contains(otherEvent.id) { continue }
                    
                    if EventCluster.isWithinClusterDistance(
                        event.coordinates,
                        otherEvent.coordinates,
                        threshold: distanceThreshold
                    ) {
                        clusterEvents.append(otherEvent)
                        processedEventIds.insert(otherEvent.id)
                    }
                }
                
                clusters.append(EventCluster(events: clusterEvents))
            }
        }
        
        print("📍 Clustered \(events.count) events into \(clusters.count) clusters (optimized)")
        print("   - Single events: \(clusters.filter { $0.isSingleEvent }.count)")
        print("   - Multi-event clusters: \(clusters.filter { !$0.isSingleEvent }.count)")
        
        return clusters
    }
}

