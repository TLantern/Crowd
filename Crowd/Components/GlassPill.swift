//
//  GlassPill.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct GlassButton: View {
    let icon: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
                .scaleEffect(pressed ? 1.08 : 1.0)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
    }
}

// Components/GlassPill.swift
import SwiftUI

struct GlassPill: View {
    private let content: AnyView
    private let height: CGFloat
    private let horizontalPadding: CGFloat

    // MARK: Text/Icon convenience init
    init(text: String, icon: String? = nil, height: CGFloat = 48, horizontalPadding: CGFloat = 20) {
        self.height = height
        self.horizontalPadding = horizontalPadding
        self.content = AnyView(
            HStack(spacing: 10) {
                if let icon { Label(text, systemImage: icon).labelStyle(.titleAndIcon) }
                else { Text(text) }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .lineLimit(1)
        )
    }

    // MARK: Builder-style init
    init(height: CGFloat = 48, horizontalPadding: CGFloat = 20, @ViewBuilder content: () -> some View) {
        self.height = height
        self.horizontalPadding = horizontalPadding
        self.content = AnyView(content())
    }

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}
