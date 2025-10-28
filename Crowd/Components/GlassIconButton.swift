//
//  GlassIconButton.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

/// Small circular glass button with icon for floating action buttons
/// - 56x56pt, fully circular (cornerRadius: 28)
/// - Glass blur effect matching "Start a Crowd" card
/// - Light scale animation + glow effect + haptic feedback on tap
struct GlassIconButton: View {
    let systemName: String
    var action: () -> Void
    
    @State private var isPressed = false
    @State private var isGlowing = false
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Trigger glow effect
            withAnimation(.spring(response: 0.12, dampingFraction: 0.7)) {
                isGlowing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.85)) {
                    isGlowing = false
                }
            }
            
            action()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .shadow(color: .yellow.opacity(isGlowing ? 0.6 : 0.0),
                            radius: isGlowing ? 16 : 0, x: 0, y: 0)
                
                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isGlowing ? .yellow : .black.opacity(0.78))
                    .animation(.spring(response: 0.12, dampingFraction: 0.8), value: isGlowing)
            }
        }
        .frame(width: 56, height: 56)
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

