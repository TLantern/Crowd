//
//  CachedEventImage.swift
//  Crowd
//
//  Reusable cached event image component using SDWebImage
//

import SwiftUI
import SDWebImageSwiftUI

struct CachedEventImage: View {
    let url: URL?
    let height: CGFloat
    let contentMode: ContentMode
    
    init(
        imageURL: String?,
        height: CGFloat = 250,
        contentMode: ContentMode = .fill
    ) {
        self.url = imageURL.flatMap { URL(string: $0) }
        self.height = height
        self.contentMode = contentMode
    }
    
    var body: some View {
        WebImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(ProgressView())
        }
        .onFailure { error in
            print("❌ Failed to load event image: \(error.localizedDescription)")
        }
        .indicator(.activity)
        .transition(.fade(duration: 0.3))
        .frame(height: height)
        .clipped()
    }
}

