//
//  EventDetailSheet.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import FirebaseFirestore

struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let message: String
    let isCurrentUser: Bool
}

struct EventDetailView: View {
    let event: CrowdEvent
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var hasJoined = false
    @State private var chatMessage = ""
    @State private var chatMessages: [ChatMessage] = [
        ChatMessage(author: "Sarah", message: "Hey everyone! Excited for this!", isCurrentUser: false),
        ChatMessage(author: "Mike", message: "Same here! What time are we starting?", isCurrentUser: false)
    ]
    @FocusState private var isChatFocused: Bool
    @EnvironmentObject private var appState: AppState
    @State private var showCancelConfirmation = false
    
    var currentUserName: String {
        appState.sessionUser?.displayName ?? "You"
    }
    
    var isHost: Bool {
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId() else {
            return false
        }
        return event.hostId == currentUserId
    }
    
    var emoji: String {
        guard let categoryString = event.category,
              let eventCategory = EventCategory(rawValue: categoryString) else {
            return "📍" // Default fallback matching EventCategory.unknown
        }
        return eventCategory.emoji
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Cancel button for hosts
            if isHost {
                HStack {
                    Spacer()
                    Button {
                        showCancelConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                            .background(Circle().fill(Color(.systemBackground)))
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header: Emoji + Title (centered together)
                    HStack(spacing: 8) {
                        Text(emoji)
                            .font(.system(size: 40))
                        
                        Text(event.title)
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, isHost ? 0 : 20)
                    
                    // Host info with aura points
                    VStack(spacing: 4) {
                        if viewModel.isLoadingHost {
                            ProgressView()
                                .controlSize(.small)
                        } else if let host = viewModel.hostProfile {
                            Text("Hosted by: \(host.displayName) • \(host.auraPoints) points")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Hosted by: \(event.hostName) • 0 points")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    if hasJoined {
                        // Chat view
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Event Chat")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            // Chat messages
                            ScrollViewReader { proxy in
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(chatMessages) { message in
                                        ChatMessageBubble(
                                            message: message.message,
                                            author: message.author,
                                            isCurrentUser: message.isCurrentUser
                                        )
                                        .id(message.id)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .onChange(of: chatMessages.count) { _, _ in
                                    if let lastMessage = chatMessages.last {
                                        withAnimation {
                                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .frame(minHeight: 200)
                    } else {
                        // Event details
                        VStack(spacing: 20) {
                            // Crowd Size (centered)
                            VStack(spacing: 8) {
                                Text("Crowd Size")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("\(event.attendeeCount)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            // Time
                            if let start = event.startsAt, let end = event.endsAt {
                                VStack(spacing: 8) {
                                    Text("Time")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Text(formatTime(start, end))
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            // Location
                            VStack(spacing: 8) {
                                Text("Location")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("Within \(Int(event.radiusMeters))m")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // Friends Attending
                            VStack(spacing: 12) {
                                Text("Friends Attending")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                if viewModel.isLoadingFriends {
                                    ProgressView()
                                        .controlSize(.small)
                                } else if viewModel.friendsAttending.isEmpty {
                                    Text("No friends attending yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                } else {
                                    HStack(spacing: -8) {
                                        ForEach(viewModel.friendsAttending.prefix(5)) { friend in
                                            AvatarView(
                                                name: friend.displayName,
                                                color: friend.avatarColor,
                                                size: 40
                                            )
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2)
                                            )
                                        }
                                        
                                        if viewModel.friendsAttending.count > 5 {
                                            ZStack {
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                                    .frame(width: 40, height: 40)
                                                Text("+\(viewModel.friendsAttending.count - 5)")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            
            // Chat input (only when joined)
            if hasJoined {
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $chatMessage)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isChatFocused)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(chatMessage.isEmpty ? .gray : Color(hex: 0x02853E))
                    }
                    .disabled(chatMessage.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            
            // Action button
            Button {
                if hasJoined {
                    // Open invite friends sheet
                } else {
                    Task {
                        let success = await viewModel.joinEvent(eventId: event.id)
                        if success {
                            withAnimation(.spring(response: 0.3)) {
                                hasJoined = true
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if viewModel.isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .controlSize(.small)
                    }
                    Text(hasJoined ? "Invite Friends" : "Join Crowd")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x02853E), Color(hex: 0x03A04E)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.isJoining)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .task {
            await viewModel.loadHostProfile(hostId: event.hostId)
            await viewModel.loadFriendsAttending(eventId: event.id)
        }
        .alert("Error", isPresented: .constant(viewModel.joinError != nil)) {
            Button("OK") {
                viewModel.joinError = nil
            }
        } message: {
            Text(viewModel.joinError ?? "Unknown error")
        }
        .confirmationDialog("Cancel Crowd", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel Crowd", role: .destructive) {
                cancelEvent()
            }
            Button("Keep Crowd", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this crowd? This action cannot be undone.")
        }
    }
    
    private func formatTime(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func sendMessage() {
        guard !chatMessage.isEmpty else { return }
        
        // Add message to chat
        let newMessage = ChatMessage(
            author: currentUserName,
            message: chatMessage,
            isCurrentUser: true
        )
        chatMessages.append(newMessage)
        
        // TODO: Send message to Firebase
        print("Sending message: \(chatMessage)")
        chatMessage = ""
    }
    
    private func cancelEvent() {
        // Verify user is the host
        guard let currentUserId = FirebaseManager.shared.getCurrentUserId(),
              currentUserId == event.hostId else {
            print("⚠️ Only the host can delete the event")
            return
        }
        
        Task {
            do {
                try await AppEnvironment.current.eventRepo.deleteEvent(eventId: event.id)
                
                // Track analytics
                AnalyticsService.shared.trackEventDeleted(eventId: event.id)
                
                print("✅ Event deleted: \(event.id)")
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Failed to delete event: \(error)")
            }
        }
    }
}

struct ChatMessageBubble: View {
    let message: String
    let author: String
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            Text(author)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isCurrentUser ? Color(hex: 0x02853E) : Color(.systemGray5))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

