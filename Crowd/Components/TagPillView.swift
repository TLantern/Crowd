//
//  TagPillView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct TagPillView: View {
    let interest: Interest
    let isEditMode: Bool
    let onDelete: () -> Void
    let onTap: () -> Void
    
    init(interest: Interest, isEditMode: Bool = false, onDelete: @escaping () -> Void = {}, onTap: @escaping () -> Void = {}) {
        self.interest = interest
        self.isEditMode = isEditMode
        self.onDelete = onDelete
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            print("Tapped interest: \(interest.name)")
            onTap()
        }) {
            HStack(spacing: 6) {
                Text(interest.emoji)
                    .font(.system(size: 14))
                
                Text(interest.name)
                    .font(.system(size: 14, weight: .medium))
                
                if isEditMode {
                    Button(action: {
                        onDelete()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Interest Button
struct AddInterestPillView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                TagPillView(interest: Interest(emoji: "💻", name: "Tech"))
                TagPillView(interest: Interest(emoji: "🎵", name: "Music"))
                TagPillView(interest: Interest(emoji: "🏀", name: "Sports"))
            }
            .padding()
        }
        
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                TagPillView(interest: Interest(emoji: "💻", name: "Tech"), isEditMode: true, onDelete: {})
                TagPillView(interest: Interest(emoji: "🎵", name: "Music"), isEditMode: true, onDelete: {})
                AddInterestPillView(action: {})
            }
            .padding()
        }
    }
}

