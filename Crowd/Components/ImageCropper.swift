//
//  ImageCropper.swift
//  Crowd
//
//  Created by Teni Owojori on 10/28/25.
//

import SwiftUI
import UIKit

struct ImageCropper: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        // Image with crop overlay
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, 0.5), 3.0)
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                            },
                                        DragGesture()
                                            .onChanged { value in
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                                )
                            
                            // Crop overlay
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: cropSize, height: cropSize)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .frame(width: cropSize, height: cropSize)
                        .clipped()
                        
                        Spacer()
                        
                        // Instructions
                        Text("Pinch to zoom, drag to position")
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func cropImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        
        croppedImage = renderer.image { context in
            // Calculate the crop area
            let imageSize = image.size
            let scaleX = imageSize.width / cropSize
            let scaleY = imageSize.height / cropSize
            let imageScale = max(scaleX, scaleY) * scale
            
            let scaledImageSize = CGSize(
                width: imageSize.width / imageScale,
                height: imageSize.height / imageScale
            )
            
            let cropRect = CGRect(
                x: (cropSize - scaledImageSize.width) / 2 - offset.width,
                y: (cropSize - scaledImageSize.height) / 2 - offset.height,
                width: scaledImageSize.width,
                height: scaledImageSize.height
            )
            
            // Draw the cropped image
            image.draw(in: cropRect)
            
            // Apply circular mask
            let rect = CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize))
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()
        }
        
        dismiss()
    }
}
