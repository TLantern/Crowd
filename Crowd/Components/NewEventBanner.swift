//
//  NewEventBanner.swift
//  Crowd
//
//  Banner notification for new events
//

import SwiftUI
import ComponentsKit

struct NewEventBanner: View {
    let event: CrowdEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var emoji: String {
        TagEmoji.emoji(for: event.tags, fallbackCategory: event.category)
    }
    
    private var cardModel: CardVM {
        CardVM {
            $0.cornerRadius = .medium
            $0.shadow = .medium
            $0.backgroundColor = .background
            $0.borderWidth = .medium
        }
    }
    
    var body: some View {
        SUCard(model: cardModel) {
            HStack(spacing: 10) {
                // Event emoji
                Text(emoji)
                    .font(.system(size: 24))
                
                // Event info
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Join button on right side
                Button(action: onJoin) {
                    Text("Join")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x02853E), Color(hex: 0x03A04E)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        NewEventBanner(
            event: CrowdEvent(
                id: "test",
                title: "Test Event",
                hostId: "123",
                hostName: "Test Host",
                latitude: 33.21,
                longitude: -97.15,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 3,
                attendeeCount: 5,
                tags: ["party"],
                category: "party"
            ),
            onJoin: { print("Join tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
    }
}

