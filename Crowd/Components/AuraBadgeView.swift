//
//  AuraBadgeView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct AuraBadgeView: View {
    let points: Int
    let rank: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
            
            Text("\(points)")
                .font(.system(size: 14, weight: .bold))
            
            Text(rank)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AuraBadgeView(points: 1280, rank: "Legend")
        AuraBadgeView(points: 450, rank: "Regular")
        AuraBadgeView(points: 2500, rank: "Mythic")
    }
    .padding()
    .background(Color.black)
}

