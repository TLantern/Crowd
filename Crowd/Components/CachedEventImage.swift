//
//  CachedEventImage.swift
//  Crowd
//
//  Reusable cached event image component using native SwiftUI AsyncImage
//

import SwiftUI

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
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(ProgressView())
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    )
            @unknown default:
                EmptyView()
            }
        }
        .frame(height: height)
        .clipped()
    }
}
