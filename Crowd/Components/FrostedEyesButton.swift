//
//  FrostedEyesButton.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import Lottie

/// Frosted circular button with animated Lottie eyes or ghost icon:
/// - Tap: quick pop to `targetSize` + highlight color, then return.
/// - Hold (>= 0.15s): stays enlarged with highlight color until released.
/// - Shows eyes when visibility OFF, ghost when visibility ON
struct FrostedEyesButton: View {
    var baseSize: CGFloat = 54
    var targetSize: CGFloat = 54
    var frostOpacity: Double = 1.0
    var highlightColor: Color = Color(hex: 0x8A5A3C)
    var containerColor: Color = Color(hex: 0xFFFFFF)
    var isGhostMode: Bool = false // Shows ghost icon when true (visibility ON)
    var action: () -> Void

    @State private var isActive = false

    private var currentSize: CGFloat { isActive ? targetSize : baseSize }
    private var animationSize: CGFloat { currentSize * 0.72 }

    var body: some View {
        ZStack {
            Circle()
                .fill(containerColor)
                .shadow(color: highlightColor.opacity(isActive ? 0.45 : 0.0),
                        radius: isActive ? 12 : 0, x: 0, y: 0)

            // Show both icons with cross-fade animation
            ZStack {
                // Eyes - visible when NOT in ghost mode
            LottieView(name: "eyes", loopMode: .loop, animationSpeed: 0.25)
                .frame(width: animationSize, height: animationSize)
                .allowsHitTesting(false)
                    .opacity(isGhostMode ? 0.0 : 1.0)
                    .scaleEffect(isGhostMode ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: isGhostMode)
                
                // Ghost - visible when in ghost mode
                Image("Ghost")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: animationSize, height: animationSize)
                    .foregroundColor(highlightColor)
                    .allowsHitTesting(false)
                    .opacity(isGhostMode ? 1.0 : 0.0)
                    .scaleEffect(isGhostMode ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.4), value: isGhostMode)
            }
        }
        .frame(width: currentSize, height: currentSize)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        .contentShape(Circle())

        // Fast pop on tap
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            
            isActive = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                isActive = false
            }
            action()
        }

        // Hold keeps it enlarged; release returns to base
        .onLongPressGesture(minimumDuration: 0.15, maximumDistance: .infinity,
                            pressing: { pressing in
                                isActive = pressing
                            }, perform: {})
    }
}
