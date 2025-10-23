//
//  UserCardView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI

struct UserCardView: View {
    let user: MiniUser
    let onTap: () -> Void
    let onAdd: () -> Void
    
    init(user: MiniUser, onTap: @escaping () -> Void = {}, onAdd: @escaping () -> Void = {}) {
        self.user = user
        self.onTap = onTap
        self.onAdd = onAdd
    }
    
    var body: some View {
        Button(action: {
            print("Tapped user: \(user.name)")
            onTap()
        }) {
            HStack(spacing: 12) {
                AvatarView(name: user.name, color: user.avatarColor, size: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    if !user.tags.isEmpty {
                        Text(user.tags.prefix(2).joined(separator: " • "))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    
                    if user.mutualFriendsCount > 0 {
                        Text("\(user.mutualFriendsCount) mutual friends")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    print("Add friend: \(user.name)")
                    onAdd()
                }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        UserCardView(
            user: MiniUser(
                id: "1",
                name: "Sarah Chen",
                avatarColor: .purple,
                tags: ["Music", "Art"],
                mutualFriendsCount: 12
            )
        )
        
        UserCardView(
            user: MiniUser(
                id: "2",
                name: "Marcus Webb",
                avatarColor: .orange,
                tags: ["Sports", "Tech"],
                mutualFriendsCount: 8
            )
        )
    }
    .padding()
}

