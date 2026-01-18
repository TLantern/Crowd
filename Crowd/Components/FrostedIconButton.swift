//
//  FrostedIconButton.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

/// Frosted circular icon button:
/// - Tap: quick pop to `targetSize` + highlight color, then return.
/// - Hold (>= 0.15s): stays enlarged with highlight color until released.
/// No jiggle/hover animations.
struct FrostedIconButton: View {
    let systemName: String
    var baseSize: CGFloat = 54
    var targetSize: CGFloat = 72
    var frostOpacity: Double = 0.22
    var iconBaseColor: Color = .black
    var highlightColor: Color               // e.g. yellow or baby blue
    var containerColor: Color? = nil        // Optional solid container color
    var action: () -> Void

    @State private var isActive = false     // drives both size + color

    private var currentSize: CGFloat { isActive ? targetSize : baseSize }
    private var iconSize: CGFloat { currentSize * 0.41 }

    var body: some View {
        ZStack {
            if let containerColor = containerColor {
                Circle()
                    .fill(containerColor)
                    .shadow(color: highlightColor.opacity(isActive ? 0.45 : 0.0),
                            radius: isActive ? 12 : 0, x: 0, y: 0)
            } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.white.opacity(frostOpacity)))
                .shadow(color: highlightColor.opacity(isActive ? 0.45 : 0.0),
                        radius: isActive ? 12 : 0, x: 0, y: 0)
            }

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? highlightColor : iconBaseColor)
                .animation(.easeOut(duration: 0.12), value: isActive)
        }
        .frame(width: currentSize, height: currentSize)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        .contentShape(Circle())

        // Fast pop on tap (no hover)
        .onTapGesture {
            // Haptic feedback (prepared for instant response)
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
