//
//  OptimizedEventImage.swift
//  Crowd
//
//  High-performance event image component with blur→sharp→fade transition
//

import SwiftUI

struct OptimizedEventImage: View {
    let imageURL: String?
    let width: CGFloat
    let height: CGFloat
    let contentMode: ContentMode
    let priority: Bool
    
    @StateObject private var loader = OptimizedImageLoader.shared
    @State private var placeholderImage: UIImage?
    @State private var fullImage: UIImage?
    @State private var isLoading = false
    @State private var showFullImage = false
    
    init(
        imageURL: String?,
        width: CGFloat = 350,
        height: CGFloat = 450,
        contentMode: ContentMode = .fill,
        priority: Bool = false
    ) {
        self.imageURL = imageURL
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.priority = priority
    }
    
    var body: some View {
        ZStack {
            // Low-res placeholder with blur
            if let placeholder = placeholderImage {
                Image(uiImage: placeholder)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .blur(radius: 15)
                    .opacity(showFullImage ? 0 : 1)
                    .animation(.easeOut(duration: 0.3), value: showFullImage)
            } else {
                // Initial gray placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
            }
            
            // High-res image with fade-in
            if let full = fullImage {
                Image(uiImage: full)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(showFullImage ? 1 : 0)
                    .animation(.easeIn(duration: 0.2), value: showFullImage)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        guard let url = imageURL else { return }
        
        print("📸 Starting to load school event image: \(url)")
        
        // Try to load placeholder from cache synchronously first (instant paint)
        let cached = await loader.getCachedPlaceholder(for: url)
        if let cached = cached {
            print("✅ Loaded school event placeholder from cache: \(url)")
            await MainActor.run {
                placeholderImage = cached
            }
        }
        
        // Load placeholder (will use cache if available, otherwise fetch)
        isLoading = true
        let placeholder = await loader.loadPlaceholder(for: url, width: width, height: height)
        
        await MainActor.run {
            if placeholderImage == nil {
                placeholderImage = placeholder
                if placeholder != nil {
                    print("✅ Loaded school event placeholder: \(url)")
                }
            }
            isLoading = false
        }
        
        // Load full image in background (non-blocking)
        if priority {
            print("📸 Loading high-priority school event image: \(url)")
        }
        let full = await loader.loadImage(for: url, width: width, height: height, priority: priority)
        
        await MainActor.run {
            fullImage = full
            if full != nil {
                showFullImage = true
                print("✅ Loaded school event full image: \(url)")
            } else {
                print("⚠️ Failed to load school event full image: \(url)")
            }
        }
    }
}

