//
//  OptimizedEventImage.swift
//  Crowd
//
//  High-performance event image component using SDWebImage's WebImage
//

import SwiftUI
import SDWebImageSwiftUI

struct OptimizedEventImage: View {
    let imageURL: String?
    let width: CGFloat
    let height: CGFloat
    let contentMode: ContentMode
    let priority: Bool
    
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
        WebImage(url: imageURL.flatMap { URL(string: $0) }) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    ProgressView()
                        .tint(.gray.opacity(0.5))
                )
        }
        .onSuccess { image, data, cacheType in
            if priority {
                print("✅ Loaded high-priority school event image from \(cacheType)")
            }
        }
        .onFailure { error in
            print("❌ Failed to load school event image: \(error.localizedDescription)")
        }
        .indicator(.activity)
        .transition(.fade(duration: 0.3))
        .frame(maxWidth: .infinity, maxHeight: height)
        .frame(height: height)
        .clipped()
    }
}

