//
//  FABPlusButton.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

/// Floating circular action button with a white "+" icon.
/// - Parameters:
///   - size: circle diameter (default 68)
///   - color: background color (defaults to brand green #02853E)
///   - elevation: shadow radius (default 14)
///   - action: tap handler
struct FABPlusButton: View {
    var size: CGFloat = 68
    var color: Color = Color(hex: 0x02853E)   // brand green
    var elevation: CGFloat = 14
    var action: () -> Void

    var body: some View {
        Button(action: {
            // subtle haptic for delight
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(color)
                // You can tune size to taste; this reads well at 68–72pt circle
                Image(systemName: "plus")
                    .font(.system(size: size * 0.42, weight: .bold)) // scales with circle
                    .foregroundStyle(.white)
                    .accessibilityLabel(Text("Create / Host"))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: elevation, x: 0, y: 8)
        .buttonStyle(.plain)
        .accessibilityIdentifier("FABPlusButton")
    }
}
