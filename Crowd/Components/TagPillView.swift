//
//  TagPillView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct TagPillView: View {
    let tag: String
    let action: () -> Void
    
    init(tag: String, action: @escaping () -> Void = {}) {
        self.tag = tag
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            print("Tapped tag: \(tag)")
            action()
        }) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.tint.opacity(0.15), in: Capsule())
                .overlay(Capsule().stroke(.tint.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 8) {
            TagPillView(tag: "Tech")
            TagPillView(tag: "Music")
            TagPillView(tag: "Sports")
            TagPillView(tag: "Food")
            TagPillView(tag: "Art")
        }
        .padding()
    }
}

