//
//  EventAnnotationView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

struct EventAnnotationView: View {
    let event: CrowdEvent

    var body: some View {
        VStack(spacing: 4) {
            Text("🔥 \(event.title)")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                )
            Text("\(event.attendeeCount) • sig \(event.signalStrength)")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .shadow(radius: 4)
    }
}
