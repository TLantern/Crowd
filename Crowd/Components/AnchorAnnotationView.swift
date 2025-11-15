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
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color.white)
                    .frame(width: 240, height: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Color.blue.opacity(0.6), lineWidth: 9)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
                
                // Emoji centered
                Text(anchor.emoji)
                    .font(.system(size: 120))
                
                // Red dot indicator for unread messages (top-left corner)
                if hasUnread {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .offset(x: -100, y: -100)
                }
                
                // Count badge for grouped anchors - positioned at top-right corner
                if let count = count, count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.blue)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white, lineWidth: 4)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                .offset(x: 10, y: -10)
                        }
                        Spacer()
                    }
                }
            }
            
            // Name label below pin
            Text(anchor.name)
                .font(.system(size: 33, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.2), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .offset(y: -12)
        }
        .contentShape(Rectangle())
        .frame(width: 240, height: 280) // Explicit frame to ensure full hit area
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

