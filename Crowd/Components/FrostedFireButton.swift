//
//  FrostedFireButton.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import Lottie

/// Frosted circular button with animated Lottie fire:
/// - Tap: quick pop to `targetSize` + highlight color, then return.
/// - Hold (>= 0.15s): stays enlarged with highlight color until released.
struct FrostedFireButton: View {
    var baseSize: CGFloat = 72
    var targetSize: CGFloat = 82
    var frostOpacity: Double = 1.0
    var highlightColor: Color = Color(hex: 0x02853E)
    var containerColor: Color = Color(hex: 0xFFFFFF)
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

            LottieView(name: "Fire animation", loopMode: .loop)
                .frame(width: animationSize, height: animationSize)
                .allowsHitTesting(false)
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
