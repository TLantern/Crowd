//
//  OptimizedImageLoader.swift
//  Crowd
//
//  High-performance image loader with viewport-based loading, prefetching, and memory management
//

import SwiftUI
import Combine

@MainActor
final class OptimizedImageLoader: ObservableObject {
    static let shared = OptimizedImageLoader()
    
    @Published var loadedImages: [String: UIImage] = [:]
    @Published var placeholderImages: [String: UIImage] = [:]
    
    private var memoryCache = NSCache<NSString, UIImage>()
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    private var viewportIndices: Set<Int> = []
    private var prefetchQueue: Set<String> = []
    
    private init() {
        configureCache()
    }
    
    private func configureCache() {
        // Optimize cache for performance
        memoryCache.countLimit = 100 // Limit concurrent images in memory
        memoryCache.totalCostLimit = 150 * 1024 * 1024 // 150MB memory
    }
    
    /// Generate optimized URL (no CDN parameters, use raw URL like parties)
    func optimizedURL(from originalURL: String?, width: CGFloat, height: CGFloat) -> URL? {
        guard let urlString = originalURL,
              let url = URL(string: urlString) else { return nil }
        
        // Use raw URL without CDN parameters, same as parties
        return url
    }
    
    /// Generate low-res placeholder URL (no CDN parameters, use raw URL like parties)
    func placeholderURL(from originalURL: String?) -> URL? {
        guard let url = originalURL,
              let urlObj = URL(string: url) else { return nil }
        
        // Use raw URL without CDN parameters, same as parties
        return urlObj
    }
    
    /// Get placeholder from cache (synchronous, for instant paint)
    func getCachedPlaceholder(for urlString: String) -> UIImage? {
        // Check memory cache first
        if let cached = placeholderImages[urlString] {
            return cached
        }
        
        let key = cacheKey(for: urlString, isPlaceholder: true) as NSString
        // Check NSCache
        if let cached = memoryCache.object(forKey: key) {
            placeholderImages[urlString] = cached
            return cached
        }
        
        return nil
    }
    
    /// Load low-res placeholder immediately
    func loadPlaceholder(for urlString: String, width: CGFloat, height: CGFloat) async -> UIImage? {
        // Check cache first (already done in getCachedPlaceholder, but double-check)
        if let cached = getCachedPlaceholder(for: urlString) {
            return cached
        }
        
        let key = cacheKey(for: urlString, isPlaceholder: true) as NSString
        
        guard let url = placeholderURL(from: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                // Resize to match target size
                let resized = image.resized(to: CGSize(width: width, height: height))
                placeholderImages[urlString] = resized
                memoryCache.setObject(resized, forKey: key)
                return resized
            }
        } catch {
            // Silent failure for placeholders
        }
        
        return nil
    }
    
    /// Load high-res image with caching
    func loadImage(for urlString: String, width: CGFloat, height: CGFloat, priority: Bool = false) async -> UIImage? {
        let key = cacheKey(for: urlString, isPlaceholder: false) as NSString
        
        // Check memory cache first
        if let cached = loadedImages[urlString] {
            return cached
        }
        
        // Check NSCache
        if let cached = memoryCache.object(forKey: key) {
            loadedImages[urlString] = cached
            return cached
        }
        
        // Cancel existing task if lower priority
        if let existingTask = loadingTasks[urlString], !priority {
            existingTask.cancel()
        }
        
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            guard let url = self.optimizedURL(from: urlString, width: width, height: height),
                  !Task.isCancelled else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                
                if let image = UIImage(data: data) {
                    // Resize if needed
                    let finalImage = image.size.width > width * 2 
                        ? image.resized(to: CGSize(width: width * 2, height: height * 2))
                        : image
                    
                    await MainActor.run {
                        self.loadedImages[urlString] = finalImage
                    }
                    
                    // Store in cache
                    self.memoryCache.setObject(finalImage, forKey: key)
                }
            } catch {
                // Silent failure
            }
        }
        
        loadingTasks[urlString] = task
        await task.value
        
        return loadedImages[urlString]
    }
    
    /// Update viewport indices and manage memory
    func updateViewport(visibleIndices: Set<Int>, allEvents: [CrowdEvent], viewportSize: Int = 2) {
        viewportIndices = visibleIndices
        
        // Prefetch next 3 images
        let prefetchIndices = visibleIndices.flatMap { index in
            (index..<min(index + 3, allEvents.count)).map { $0 }
        }
        
        let prefetchSet = Set(prefetchIndices)
        for index in prefetchSet {
            guard index < allEvents.count,
                  let imageURL = allEvents[index].imageURL else { continue }
            prefetchImage(for: imageURL, width: 350, height: 450)
        }
        
        // Keep all images in cache - don't unload
        // Images stay in SDWebImage cache (150MB limit, 50 images max)
        // System will handle memory pressure automatically
    }
    
    /// Prefetch image in background
    private func prefetchImage(for urlString: String, width: CGFloat, height: CGFloat) {
        guard !prefetchQueue.contains(urlString),
              !loadedImages.keys.contains(urlString) else { return }
        
        prefetchQueue.insert(urlString)
        
        Task {
            _ = await loadImage(for: urlString, width: width, height: height, priority: false)
            await MainActor.run {
                prefetchQueue.remove(urlString)
            }
        }
    }
    
    /// Unload image from memory
    func unloadImage(for urlString: String) {
        loadedImages.removeValue(forKey: urlString)
        loadingTasks[urlString]?.cancel()
        loadingTasks.removeValue(forKey: urlString)
    }
    
    /// Get cache key
    private func cacheKey(for urlString: String, isPlaceholder: Bool) -> String {
        let prefix = isPlaceholder ? "placeholder_" : "full_"
        return prefix + urlString
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
