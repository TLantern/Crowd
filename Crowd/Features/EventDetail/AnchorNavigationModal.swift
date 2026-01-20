//
//  AnchorNavigationModal.swift
//  Crowd
//
//  Navigation modal for anchors - shows map and chat
//

import SwiftUI
import CoreLocation
import Combine
import FirebaseFirestore
import UIKit
import PhotosUI

// MARK: - Anchor Navigation Modal
struct AnchorNavigationModal: View {
    let anchor: Anchor
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var locationService = AppEnvironment.current.location
    
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var locationUpdateTimer: Timer?
    
    @State private var currentUserId: String = "unknown"
    @State private var currentUserName: String = "Guest"
    @StateObject private var chatService = EventChatService.shared
    @State private var messageText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedTab: TabSelection = .chat
    @State private var isSendingMessage = false
    @State private var liveParticipantCount: Int = 0
    
    enum TabSelection {
        case map
        case chat
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Full UNT green background
                Color(hex: 0x02853E)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar - compressed
                    VStack(spacing: 0) {
                        // Title row
                        ZStack {
                            MarqueeTitle(text: "\(anchor.emoji) \(anchor.name)")
                                .padding(.horizontal, 5)
                        }
                        .frame(height: 32)
                        .padding(.bottom, 4)
                        
                        // Tab switcher row
                        HStack(spacing: 8) {
                            // Back button (left)
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 4)
                            
                            Spacer()
                            
                            // Tabs (center)
                            HStack(spacing: 0) {
                                TabButton(
                                    title: "Chat 💬",
                                    isSelected: selectedTab == .chat,
                                    action: { selectedTab = .chat }
                                )
                                
                                TabButton(
                                    title: "Map 📍",
                                    isSelected: selectedTab == .map,
                                    action: { selectedTab = .map }
                                )
                            }
                            .frame(height: 36)
                            .frame(width: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .padding(.top, 8)
                    .background(Color(hex: 0x02853E))
                    
                    // Full screen tab content
                    Group {
                        if selectedTab == .map {
                            if let anchorCoord = anchor.coordinates {
                                RouteMapView(
                                    destination: anchorCoord,
                                    userCoordinate: userLocation
                                )
                                .background(Color.white)
                                .ignoresSafeArea(edges: .bottom)
                            } else {
                                VStack {
                                    Spacer()
                                    Text("Location not available")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.white)
                            }
                        } else {
                            ChatTabView(
                                eventId: anchor.id,
                                attendeeCount: liveParticipantCount,
                                chatService: chatService,
                                messageText: $messageText,
                                selectedImage: $selectedImage,
                                selectedImageData: $selectedImageData,
                                sendMessage: sendMessage,
                                isSendingMessage: $isSendingMessage
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                }
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            // Initialize participant count from existing messages
            let uniqueUsers = Set(chatService.messages.map { $0.userId })
            liveParticipantCount = max(uniqueUsers.count, 1)
            
            // Initialize user ID immediately from cache (fast, synchronous)
            if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
                currentUserId = existingUserId
                currentUserName = "Guest"
            }
            
            // Defer all heavy operations to async tasks to prevent blocking render
            Task.detached(priority: .userInitiated) {
                // Track analytics (non-blocking)
                AnalyticsService.shared.trackScreenView("anchor_navigation")
                AnalyticsService.shared.trackAnchorPinTapped(
                    anchorId: anchor.id,
                    anchorName: anchor.name,
                    location: anchor.location
                )
                
                // Start location updates (non-blocking)
                await MainActor.run {
                    startLocationUpdates()
                }
                
                // Ensure chat is listening (already started in handleAnchorTap, but verify)
                await MainActor.run {
                    if let userId = FirebaseManager.shared.getCurrentUserId() {
                        chatService.startListening(eventId: anchor.id, currentUserId: userId)
                        ChatNotificationService.shared.startListeningToAnchor(anchorId: anchor.id, anchorName: anchor.name)
                        ChatNotificationService.shared.markAsRead(eventId: anchor.id)
                    }
                }
                
                // Handle auth and profile fetch in background (non-critical)
                var userId: String?
                
                if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
                    userId = existingUserId
                    await MainActor.run {
                        currentUserId = existingUserId
                    }
                    
                    // Fetch user profile in background (non-critical)
                    do {
                        let profile = try await UserProfileService.shared.fetchProfile(userId: existingUserId)
                        await MainActor.run {
                            currentUserName = profile.displayName
                        }
                    } catch {
                        print("⚠️ AnchorNavigationModal: Failed to fetch profile: \(error)")
                    }
                } else {
                    // Sign in anonymously in background
                    do {
                        let newUserId = try await FirebaseManager.shared.signInAnonymously()
                        userId = newUserId
                        await MainActor.run {
                            currentUserId = newUserId
                            chatService.startListening(eventId: anchor.id, currentUserId: newUserId)
                            ChatNotificationService.shared.startListeningToAnchor(anchorId: anchor.id, anchorName: anchor.name)
                            ChatNotificationService.shared.markAsRead(eventId: anchor.id)
                        }
                        print("✅ AnchorNavigationModal: User signed in anonymously: \(newUserId)")
                    } catch {
                        print("❌ AnchorNavigationModal: Failed to sign in anonymously: \(error)")
                    }
                }
            }
        }
        .onDisappear {
            stopLocationUpdates()
            chatService.stopListening()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Mark messages as read when switching to chat tab
            if newTab == .chat {
                ChatNotificationService.shared.markAsRead(eventId: anchor.id)
            }
        }
        .onChange(of: chatService.messages.count) { _, _ in
            // Update last seen timestamp when new messages arrive (if on chat tab)
            if selectedTab == .chat, let lastMessage = chatService.messages.last {
                ChatNotificationService.shared.updateLastSeen(eventId: anchor.id, timestamp: lastMessage.timestamp)
            }
            // Update participant count from unique message senders
            let uniqueUsers = Set(chatService.messages.map { $0.userId })
            liveParticipantCount = max(uniqueUsers.count, 1)
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    // Swipe from left edge to right (standard iOS back gesture)
                    if value.translation.width > 100 && abs(value.translation.height) < 100 {
                        dismiss()
                    }
                }
        )
    }
    
    // MARK: - Chat
    
    private func sendMessage() {
        // Prevent multiple simultaneous sends
        guard !isSendingMessage else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else { return }
        
        // Clear text immediately for better UX
        let messageToSend = text
        messageText = ""
        
        isSendingMessage = true
        
        Task.detached(priority: .userInitiated) {
            do {
                try await chatService.sendMessage(
                    eventId: anchor.id,
                    text: messageToSend,
                    userId: await currentUserId,
                    userName: await currentUserName
                )
                
                // Track analytics on main thread
                await MainActor.run {
                    AnalyticsService.shared.trackMessageSent(eventId: anchor.id, messageLength: messageToSend.count)
                    ChatNotificationService.shared.updateLastSeen(eventId: anchor.id, timestamp: Date())
                    isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    print("❌ AnchorNavigationModal: Failed to send message: \(error)")
                    // Restore message text and image on error
                    messageText = messageToSend
                    isSendingMessage = false
                }
            }
        }
    }
    
    // MARK: - Location
    
    private func startLocationUpdates() {
        locationService.requestSoftAuth()
        locationService.startUpdatingLocation()
        
        // seed with last known
        if let currentLocation = locationService.lastKnown {
            userLocation = currentLocation
        }
        
        // poll for new location every second
        locationUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { _ in
            if let newLocation = locationService.lastKnown {
                let oldLat = userLocation?.latitude ?? 0
                let oldLon = userLocation?.longitude ?? 0
                
                let movedEnough =
                    abs(newLocation.latitude - oldLat) > 0.0001 ||
                    abs(newLocation.longitude - oldLon) > 0.0001
                
                if userLocation == nil || movedEnough {
                    userLocation = newLocation
                }
            }
        }
    }
    
    private func stopLocationUpdates() {
        locationService.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
}

// MARK: - Preview
#Preview {
    AnchorNavigationModal(
        anchor: {
            var anchor = Anchor(
                id: "preview-anchor",
                name: "Willis Library",
                emoji: "📚",
                location: "1506 Highland St, Denton, TX",
                type: "study",
                daysActive: ["Mon", "Tue", "Wed", "Thu", "Fri"],
                anchorStartLocal: "08:00",
                anchorEndLocal: "22:00",
                sendNotification: false,
                notificationTimeLocal: nil,
                notificationMessage: nil,
                description: "Main campus library"
            )
            anchor.latitude = 33.2107
            anchor.longitude = -97.1517
            return anchor
        }()
    )
}

