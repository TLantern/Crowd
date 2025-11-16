//
//  AnchorAnnotationView.swift
//  Crowd
//
//  Map pin view for anchor locations with emoji and name
//

import SwiftUI

struct AnchorAnnotationView: View {
    let anchor: Anchor
    var count: Int? = nil // Optional count badge for grouped anchors
    var onTap: (() -> Void)? = nil
    @ObservedObject private var chatNotificationService = ChatNotificationService.shared
    
    var hasUnread: Bool {
        chatNotificationService.hasUnreadMessages(eventId: anchor.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Rounded square pin head (distinct from circular event pins)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .frame(width: 75, height: 75)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                
                // Emoji centered
                Text(anchor.emoji)
                    .font(.system(size: 34))
                
                // Red dot indicator for unread messages (top-left corner)
                if hasUnread {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: -27.5, y: -27.5)
                }
                
                // Count badge for grouped anchors - positioned at top-right corner
                if let count = count, count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                }
            }
            
            // Name label below pin
            Text(anchor.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .offset(y: -5)
        }
        .contentShape(Rectangle())
        .frame(width: 75, height: 91) // Explicit frame to ensure full hit area
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    print("🔵 AnchorAnnotationView tapped: \(anchor.name)")
                    onTap?()
                }
        )
        .accessibilityLabel("\(anchor.emoji) anchor pin, \(anchor.name)")
        .accessibilityHint("Double tap to view anchor details")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 40) {
        AnchorAnnotationView(
            anchor: Anchor(
                id: "test",
                name: "Pohl Rec Center – Gym",
                emoji: "🏋️",
                location: "Pohl Recreation Center",
                type: "anchor",
                daysActive: ["Mon", "Tue", "Wed"],
                anchorStartLocal: "08:00",
                anchorEndLocal: "22:00",
                sendNotification: false,
                notificationTimeLocal: nil,
                notificationMessage: nil,
                description: "Test anchor"
            )
        )
        
        AnchorAnnotationView(
            anchor: Anchor(
                id: "test2",
                name: "Willis Library – Floor 2",
                emoji: "📚",
                location: "Willis Library, Floor 2",
                type: "anchor",
                daysActive: ["Mon", "Tue"],
                anchorStartLocal: "10:00",
                anchorEndLocal: "23:00",
                sendNotification: true,
                notificationTimeLocal: "19:00",
                notificationMessage: "Test message",
                description: "Test anchor 2"
            )
        )
    }
    .padding()
}

