//
//  CrowdAvatarGroup.swift
//  Crowd
//

import SwiftUI
import ComponentsKit

struct Member: Identifiable {
    let id: String
    let imageURL: String?
    let initials: String
}

struct CrowdAvatarGroup: View {
    let members: [Member]
    let totalCount: Int?
    
    init(members: [Member], totalCount: Int? = nil) {
        self.members = members
        self.totalCount = totalCount
    }
    
    private let maxAvatars = 3
    private let avatarSize: CGFloat = 48
    private let minBubbles = 3
    
    private var effectiveTotal: Int { max(totalCount ?? members.count, members.count) }
    private var overflow: Int { max(0, effectiveTotal - min(members.count, maxAvatars)) }
    private var showOverflow: Bool { overflow >= 3 }
    
    var body: some View {
        HStack(spacing: -14) {
            ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                avatarBubble(for: item)
                    .zIndex(Double(maxAvatars - index))
            }
            
            if showOverflow {
                overflowBubble
                    .padding(.leading, 6)
                    .zIndex(0)
            }
        }
    }
    
    private var displayItems: [(imageURL: String?, initials: String)] {
        var items: [(imageURL: String?, initials: String)] = members.prefix(maxAvatars).map { ($0.imageURL, $0.initials) }
        let placeholdersNeeded = max(0, minBubbles - items.count)
        for _ in 0..<placeholdersNeeded {
            items.append((nil, ""))
        }
        return items
    }
    
    private func avatarBubble(for item: (imageURL: String?, initials: String)) -> some View {
        Group {
            if let urlString = item.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView(item.initials)
                }
            } else if !item.initials.isEmpty {
                initialsView(item.initials)
            } else {
                placeholderView
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
    
    private func initialsView(_ initials: String) -> some View {
        Circle()
            .fill(Color(.systemGray5))
            .overlay(
                Text(initials)
                    .font(.system(size: avatarSize * 0.4, weight: .semibold))
                    .foregroundColor(.primary)
            )
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color(.systemGray6))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: avatarSize * 0.45))
                    .foregroundColor(.gray.opacity(0.4))
            )
    }
    
    private var overflowBubble: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text("+\(overflow)")
                    .font(.system(size: avatarSize * 0.35, weight: .semibold))
                    .foregroundColor(.primary)
            )
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 24) {
        // 1 member → 3 bubbles (2 placeholders)
        CrowdAvatarGroup(members: [
            Member(id: "1", imageURL: nil, initials: "JD")
        ])
        
        // 3 members → 3 avatars, no overflow
        CrowdAvatarGroup(members: [
            Member(id: "1", imageURL: nil, initials: "JD"),
            Member(id: "2", imageURL: nil, initials: "AB"),
            Member(id: "3", imageURL: nil, initials: "XY")
        ])
        
        // 6 members → 3 avatars + "+3"
        CrowdAvatarGroup(members: [
            Member(id: "1", imageURL: nil, initials: "JD"),
            Member(id: "2", imageURL: nil, initials: "AB"),
            Member(id: "3", imageURL: nil, initials: "XY"),
            Member(id: "4", imageURL: nil, initials: "MN"),
            Member(id: "5", imageURL: nil, initials: "QR"),
            Member(id: "6", imageURL: nil, initials: "ST")
        ])
        
        // 10 members → 3 avatars + "+7"
        CrowdAvatarGroup(members: (1...10).map {
            Member(id: "\($0)", imageURL: nil, initials: "U\($0)")
        })
    }
    .padding()
}
