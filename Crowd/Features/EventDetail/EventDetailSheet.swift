//
//  EventDetailSheet.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import FirebaseFirestore

extension Notification.Name {
    static let eventDeleted = Notification.Name("eventDeleted")
}


struct EventDetailView: View {
    @State var event: CrowdEvent
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = EventDetailViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showCancelConfirmation = false
    @State private var showNavigationModal = false
    
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
            return "📅" // Default fallback matching EventCategory.other
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
                        Text("🗑️")
                            .font(.system(size: 28))
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
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            
            
            // Action button
            Button {
                Task {
                    let success = await viewModel.joinEvent(event: event)
                    if success {
                        showNavigationModal = true
                    }
                }
            } label: {
                HStack {
                    if viewModel.isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .controlSize(.small)
                    }
                    Text("Join Crowd")
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
        .fullScreenCover(isPresented: $showNavigationModal) {
            EventNavigationModal(event: event)
        }
    }
    
    private func formatTime(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    
    private func cancelEvent() {
        // Get current user ID with detailed logging
        let currentUserId = FirebaseManager.shared.getCurrentUserId()
        print("🔍 Delete Event Debug:")
        print("   - Current User ID: \(currentUserId ?? "nil")")
        print("   - Event Host ID: \(event.hostId)")
        print("   - Event ID: \(event.id)")
        print("   - User authenticated: \(currentUserId != nil)")
        
        // Verify user is authenticated
        guard let currentUserId = currentUserId else {
            print("❌ User not authenticated - cannot delete event")
            // TODO: Show user-friendly error message
            return
        }
        
        // Verify user is the host
        guard currentUserId == event.hostId else {
            print("❌ User (\(currentUserId)) is not the host (\(event.hostId)) - cannot delete event")
            // TODO: Show user-friendly error message
            return
        }
        
        print("✅ User is authenticated and is the host - proceeding with deletion")
        
        Task {
            do {
                try await AppEnvironment.current.eventRepo.deleteEvent(eventId: event.id)
                
                // Track analytics
                AnalyticsService.shared.trackEventDeleted(eventId: event.id)
                
                print("✅ Event deleted: \(event.id)")
                
                // Post notification to remove from hostedEvents array
                NotificationCenter.default.post(name: .eventDeleted, object: event.id)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Failed to delete event: \(error)")
                // TODO: Show user-friendly error message
            }
        }
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

