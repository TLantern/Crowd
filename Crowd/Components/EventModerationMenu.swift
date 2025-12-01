//
//  EventModerationMenu.swift
//  Crowd
//
//  Menu component for flagging, blocking, and hiding events
//

import SwiftUI

struct EventModerationMenu: View {
    let event: CrowdEvent
    let hostName: String
    @State private var showFlagAlert = false
    @State private var showBlockAlert = false
    @State private var showHideConfirmation = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var flagReason: String = ""
    
    var body: some View {
        Menu {
            Button(role: .destructive) {
                showFlagAlert = true
            } label: {
                Label("Report Event", systemImage: "flag.fill")
            }
            
            Button(role: .destructive) {
                showBlockAlert = true
            } label: {
                Label("Block \(hostName)", systemImage: "person.crop.circle.badge.xmark")
            }
            
            Divider()
            
            Button {
                showHideConfirmation = true
            } label: {
                Label("Hide from Feed", systemImage: "eye.slash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .alert("Report Event", isPresented: $showFlagAlert) {
            TextField("Reason (optional)", text: $flagReason)
            Button("Cancel", role: .cancel) {
                flagReason = ""
            }
            Button("Report", role: .destructive) {
                flagEvent(reason: flagReason.isEmpty ? "User reported" : flagReason)
                flagReason = ""
            }
        } message: {
            Text("Help us keep the community safe. What's wrong with this event?")
        }
        .alert("Block User", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Block \(hostName)? You won't see events from this user anymore.")
        }
        .confirmationDialog("Hide Event", isPresented: $showHideConfirmation, titleVisibility: .visible) {
            Button("Hide", role: .destructive) {
                hideEvent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This event will be removed from your feed. You can unhide it later from your profile.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func flagEvent(reason: String) {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        
        isProcessing = true
        Task {
            do {
                try await ContentModerationService.shared.flagEvent(
                    eventId: event.id,
                    userId: userId,
                    reason: reason
                )
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to report event: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func blockUser() {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        
        isProcessing = true
        Task {
            do {
                try await ContentModerationService.shared.blockUser(
                    blockedUserId: event.hostId,
                    currentUserId: userId
                )
                await MainActor.run {
                    isProcessing = false
                    // Post notification to refresh feed
                    NotificationCenter.default.post(name: .userBlocked, object: event.hostId)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to block user: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func hideEvent() {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        
        isProcessing = true
        Task {
            do {
                try await ContentModerationService.shared.hideEvent(
                    eventId: event.id,
                    userId: userId
                )
                await MainActor.run {
                    isProcessing = false
                    // Post notification to refresh feed
                    NotificationCenter.default.post(name: .eventHidden, object: event.id)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to hide event: \(error.localizedDescription)"
                }
            }
        }
    }
}

extension Notification.Name {
    static let userBlocked = Notification.Name("userBlocked")
    static let eventHidden = Notification.Name("eventHidden")
}

