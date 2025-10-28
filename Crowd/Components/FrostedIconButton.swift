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
    var iconBaseColor: Color = .primary
    var highlightColor: Color               // e.g. yellow or baby blue
    var action: () -> Void

    @State private var isActive = false     // drives both size + color

    private var currentSize: CGFloat { isActive ? targetSize : baseSize }
    private var iconSize: CGFloat { currentSize * 0.41 }

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.white.opacity(frostOpacity)))
                .shadow(color: highlightColor.opacity(isActive ? 0.45 : 0.0),
                        radius: isActive ? 12 : 0, x: 0, y: 0)

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? highlightColor : iconBaseColor)
                .animation(.spring(response: 0.12, dampingFraction: 0.8), value: isActive)
        }
        .frame(width: currentSize, height: currentSize)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        .contentShape(Circle())

        // Fast pop on tap (no hover)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.12, dampingFraction: 0.7)) { isActive = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.85)) { isActive = false }
            }
            action()
        }

        // Hold keeps it enlarged; release returns to base
        .onLongPressGesture(minimumDuration: 0.15, maximumDistance: .infinity,
                            pressing: { pressing in
                                withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) {
                                    isActive = pressing
                                }
                            }, perform: {})
    }
}
