//
//  AvatarView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    let color: Color
    let size: CGFloat
    let showOnlineStatus: Bool
    
    init(name: String, color: Color, size: CGFloat = 90, showOnlineStatus: Bool = false) {
        self.name = name
        self.color = color
        self.size = size
        self.showOnlineStatus = showOnlineStatus
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(color.opacity(0.25))
                .overlay(
                    Text(initials(from: name))
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(color)
                )
                .frame(width: size, height: size)
            
            if showOnlineStatus {
                OnlineStatusIndicator(size: size * 0.2)
                    .offset(x: -size * 0.05, y: -size * 0.05)
            }
        }
    }
    
    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
}

// MARK: - Online Status Indicator
private struct OnlineStatusIndicator: View {
    let size: CGFloat
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Color.green, lineWidth: size * 0.15)
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        AvatarView(name: "Teni Owojori", color: .cyan, size: 90, showOnlineStatus: true)
        AvatarView(name: "Sarah Chen", color: .purple, size: 60, showOnlineStatus: false)
        AvatarView(name: "Marcus Webb", color: .orange, size: 40, showOnlineStatus: false)
    }
    .padding()
}

