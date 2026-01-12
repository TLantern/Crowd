//
//  EventImagePrefetcher.swift
//  Crowd
//
//  Service for prefetching event images to eliminate visible loading states
//

import Foundation
import SDWebImage

class EventImagePrefetcher {
    static let shared = EventImagePrefetcher()
    private let prefetcher = SDWebImagePrefetcher.shared
    private var lastPrefetchedRange: Range<Int>?
    
    private init() {
        // Prefetcher config
        prefetcher.maxConcurrentPrefetchCount = 3
        prefetcher.options = [.highPriority, .continueInBackground]
    }
    
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
        
        prefetcher.prefetchURLs(urls) { finished, total in
            if finished == total {
                print("✅ Prefetched \(finished) event images")
            }
        }
    }
    
    /// Cancel ongoing prefetch operations
    func cancelPrefetch() {
        prefetcher.cancelPrefetching()
        lastPrefetchedRange = nil
    }
}

