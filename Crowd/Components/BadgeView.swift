//
//  BadgeView.swift
//  Crowd
//
//  Created by Cursor on 12/19/25.
//

import SwiftUI

struct BadgeView: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let onTap: (() -> Void)?
    
    init(title: String, emoji: String? = nil, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.title = title
        self.emoji = emoji
        self.isSelected = isSelected
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    badgeContent
                }
                .buttonStyle(.plain)
            } else {
                badgeContent
            }
        }
    }
    
    // Color schemes for badges based on title hash
    private let colorSchemes: [(background: Color, border: Color, text: Color)] = [
        (Color.blue.opacity(0.25), Color.blue.opacity(0.5), Color.blue),
        (Color.green.opacity(0.25), Color.green.opacity(0.5), Color.green),
        (Color.purple.opacity(0.25), Color.purple.opacity(0.5), Color.purple),
        (Color.orange.opacity(0.25), Color.orange.opacity(0.5), Color.orange),
        (Color.pink.opacity(0.25), Color.pink.opacity(0.5), Color.pink),
        (Color.red.opacity(0.25), Color.red.opacity(0.5), Color.red),
        (Color.cyan.opacity(0.25), Color.cyan.opacity(0.5), Color.cyan)
    ]
    
    private var colorSchemeForTitle: (background: Color, border: Color, text: Color) {
        if isSelected {
            return (Color(hex: 0x02853E), Color(hex: 0x02853E).opacity(0.3), .white)
        }
        let hash = abs(title.hashValue)
        return colorSchemes[hash % colorSchemes.count]
    }
    
    private var badgeContent: some View {
        HStack(spacing: 6) {
            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 14))
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(colorSchemeForTitle.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(colorSchemeForTitle.background, in: Capsule())
        .overlay(
            Capsule()
                .stroke(colorSchemeForTitle.border, lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        BadgeView(title: "Option 1", emoji: "🎉")
        BadgeView(title: "Option 2", emoji: "🔥", isSelected: true)
        BadgeView(title: "Option 3")
    }
    .padding()
}

