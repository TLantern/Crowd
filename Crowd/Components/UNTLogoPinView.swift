//
//  UNTLogoPinView.swift
//  Crowd
//
//  Annotation pin view for UNT logo with caching
//

import SwiftUI

struct UNTLogoPinView: View {
    @StateObject private var imageLoader = OptimizedImageLoader.shared
    @State private var logoImage: UIImage?
    @State private var isLoading = true
    
    var size: CGFloat = 60
    
    var body: some View {
        VStack(spacing: 0) {
            // Pin head with logo
            ZStack {
                // Circular background (pin head style)
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.8), lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                
                // Logo image
                if let logoImage = logoImage {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .clipShape(Circle())
                } else if isLoading {
                    // Loading placeholder
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    // Fallback to asset if cache fails
                    Image("UNTLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.7, height: size * 0.7)
                        .clipShape(Circle())
                }
            }
            
            // Pin point (triangle)
            PinTriangle()
                .fill(Color.green.opacity(0.8))
                .frame(width: size * 0.4, height: size * 0.3)
                .offset(y: -2)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
        }
        .task {
            await loadLogo()
        }
    }
    
    private func loadLogo() async {
        // Try to get from cache first (synchronous)
        if let cached = imageLoader.getCachedLocalAssetImage(named: "UNTLogo") {
            await MainActor.run {
                logoImage = cached
                isLoading = false
            }
            return
        }
        
        // Load and cache the logo
        isLoading = true
        let image = await imageLoader.loadLocalAssetImage(
            named: "UNTLogo",
            width: size * 2,
            height: size * 2
        )
        
        await MainActor.run {
            logoImage = image
            isLoading = false
        }
    }
}

// Triangle shape for pin point
struct PinTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        UNTLogoPinView(size: 60)
        UNTLogoPinView(size: 80)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
