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
    
    private var badgeContent: some View {
        HStack(spacing: 6) {
            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 14))
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
            ? Color(hex: 0x02853E)
            : Color(.systemGray5)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isSelected
                    ? Color(hex: 0x02853E).opacity(0.3)
                    : Color(.systemGray4),
                    lineWidth: 1
                )
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

