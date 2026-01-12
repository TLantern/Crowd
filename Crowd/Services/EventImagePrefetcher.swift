//
//  EventImagePrefetcher.swift
//  Crowd
//
//  Service for prefetching event images to eliminate visible loading states
//

import Foundation

class EventImagePrefetcher {
    static let shared = EventImagePrefetcher()
    private var lastPrefetchedRange: Range<Int>?
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private let maxConcurrentPrefetch = 3
    
    private init() {}
    
    /// Prefetch images for a range of events
    func prefetchEvents(
        _ events: [CrowdEvent],
        range: Range<Int>
    ) {
        // Avoid duplicate prefetch
        guard lastPrefetchedRange != range else { return }
        lastPrefetchedRange = range
        
        let urls = events[range]
            .compactMap { $0.imageURL }
            .compactMap { URL(string: $0) }
        
        guard !urls.isEmpty else { return }
        
        // Limit concurrent prefetches
        let urlsToFetch = Array(urls.prefix(maxConcurrentPrefetch))
        
        for url in urlsToFetch {
            // Skip if already prefetching
            guard prefetchTasks[url] == nil else { continue }
            
            let task = Task {
                do {
                    let (_, _) = try await URLSession.shared.data(from: url)
                } catch {
                    // Silent failure for prefetch
                }
            }
            prefetchTasks[url] = task
        }
        
        print("✅ Prefetching \(urlsToFetch.count) event images")
    }
    
    /// Cancel ongoing prefetch operations
    func cancelPrefetch() {
        for task in prefetchTasks.values {
            task.cancel()
        }
        prefetchTasks.removeAll()
        lastPrefetchedRange = nil
    }
}
