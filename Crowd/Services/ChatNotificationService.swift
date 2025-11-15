//
//  ChatNotificationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import Foundation
import FirebaseFirestore
import UserNotifications
import Combine

@MainActor
final class ChatNotificationService: ObservableObject {
    static let shared = ChatNotificationService()
    
    private let db = FirebaseManager.shared.db
    private let attendedEventsService = AttendedEventsService.shared
    private var eventListeners: [String: ListenerRegistration] = [:]
    private var lastSeenTimestamps: [String: Date] = [:]
    private var latestMessageTimestamps: [String: Date] = [:]
    @Published private(set) var unreadEventIds: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Setup
    
    func start() {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            print("⚠️ ChatNotificationService: No user ID, cannot start")
            return
        }
        
        currentUserId = userId
        setupListenersForJoinedEvents()
    }
    
    func stop() {
        stopAllListeners()
        cancellables.removeAll()
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe changes to attended events
        attendedEventsService.$attendedEvents
            .sink { [weak self] events in
                Task { @MainActor in
                    self?.handleAttendedEventsChanged(events)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAttendedEventsChanged(_ events: [CrowdEvent]) {
        let currentEventIds = Set(events.map { $0.id })
        let listeningEventIds = Set(eventListeners.keys)
        
        // Stop listening to events that are no longer joined
        for eventId in listeningEventIds {
            if !currentEventIds.contains(eventId) {
                stopListening(to: eventId)
            }
        }
        
        // Start listening to newly joined events
        for event in events {
            if !listeningEventIds.contains(event.id) {
                startListening(to: event)
            }
        }
    }
    
    // MARK: - Listeners
    
    private func setupListenersForJoinedEvents() {
        let events = attendedEventsService.getAttendedEvents()
        for event in events {
            startListening(to: event)
        }
    }
    
    private func startListening(to event: CrowdEvent) {
        guard let userId = currentUserId else { return }
        
        // Don't start duplicate listeners
        guard eventListeners[event.id] == nil else {
            print("⚠️ ChatNotificationService: Already listening to event \(event.id)")
            return
        }
        
        print("🔔 ChatNotificationService: Starting listener for event \(event.id) - \(event.title)")
        
        // Initialize last seen timestamp if not exists
        if lastSeenTimestamps[event.id] == nil {
            lastSeenTimestamps[event.id] = Date()
        }
        
        let listener = db.collection("eventChats")
            .document(event.id)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ ChatNotificationService: Error listening to messages for event \(event.id) - \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents,
                          let latestDoc = documents.first,
                          let data = latestDoc.data() as? [String: Any],
                          let messageUserId = data["userId"] as? String,
                          let userName = data["userName"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return
                    }
                    
                    let messageDate = timestamp.dateValue()
                    
                    // Track latest message timestamp
                    self.latestMessageTimestamps[event.id] = messageDate
                    
                    // Don't notify for own messages
                    if messageUserId == userId {
                        // Update last seen timestamp to current message
                        self.lastSeenTimestamps[event.id] = messageDate
                        // Mark as read since it's our own message
                        self.unreadEventIds.remove(event.id)
                        return
                    }
                    
                    // Check if this is a new message (after last seen timestamp)
                    if let lastSeen = self.lastSeenTimestamps[event.id],
                       messageDate > lastSeen {
                        // Send notification
                        self.sendNotification(
                            eventId: event.id,
                            eventTitle: event.title,
                            userName: userName,
                            message: text
                        )
                        
                        // Update last seen timestamp
                        self.lastSeenTimestamps[event.id] = messageDate
                    }
                    
                    // Update unread status - check if latest message is newer than last seen
                    if let lastSeen = self.lastSeenTimestamps[event.id],
                       messageDate > lastSeen {
                        self.unreadEventIds.insert(event.id)
                    } else {
                        self.unreadEventIds.remove(event.id)
                    }
                }
            }
        
        eventListeners[event.id] = listener
    }
    
    private func stopListening(to eventId: String) {
        print("🔔 ChatNotificationService: Stopping listener for event \(eventId)")
        eventListeners[eventId]?.remove()
        eventListeners.removeValue(forKey: eventId)
        lastSeenTimestamps.removeValue(forKey: eventId)
    }
    
    private func stopAllListeners() {
        for (eventId, listener) in eventListeners {
            print("🔔 ChatNotificationService: Stopping listener for event \(eventId)")
            listener.remove()
        }
        eventListeners.removeAll()
        lastSeenTimestamps.removeAll()
    }
    
    // MARK: - Notifications
    
    private func sendNotification(eventId: String, eventTitle: String, userName: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(eventTitle)"
        content.body = "\(userName): \(message)"
        content.sound = .default
        content.badge = 1
        
        // Add custom data for navigation
        content.userInfo = [
            "type": "chat_message",
            "eventId": eventId,
            "userName": userName,
            "message": message
        ]
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: "chat_\(eventId)_\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        // Add notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ ChatNotificationService: Failed to send notification - \(error.localizedDescription)")
            } else {
                print("✅ ChatNotificationService: Sent notification for event \(eventId)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func markAsRead(eventId: String) {
        lastSeenTimestamps[eventId] = Date()
        // If there's a latest message, compare with it; otherwise mark as read
        if let latestMessage = latestMessageTimestamps[eventId] {
            if Date() >= latestMessage {
                unreadEventIds.remove(eventId)
            }
        } else {
            unreadEventIds.remove(eventId)
        }
    }
    
    func updateLastSeen(eventId: String, timestamp: Date) {
        lastSeenTimestamps[eventId] = timestamp
        // Update unread status based on latest message
        if let latestMessage = latestMessageTimestamps[eventId],
           latestMessage > timestamp {
            unreadEventIds.insert(eventId)
        } else {
            unreadEventIds.remove(eventId)
        }
    }
    
    func hasUnreadMessages(eventId: String) -> Bool {
        return unreadEventIds.contains(eventId)
    }
    
    // MARK: - Anchor Chat Tracking
    
    func startListeningToAnchor(anchorId: String, anchorName: String) {
        guard let userId = currentUserId else { return }
        
        // Don't start duplicate listeners
        guard eventListeners[anchorId] == nil else {
            return
        }
        
        print("🔔 ChatNotificationService: Starting listener for anchor \(anchorId) - \(anchorName)")
        
        // Initialize last seen timestamp if not exists
        if lastSeenTimestamps[anchorId] == nil {
            lastSeenTimestamps[anchorId] = Date()
        }
        
        let listener = db.collection("eventChats")
            .document(anchorId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ ChatNotificationService: Error listening to anchor messages \(anchorId) - \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents,
                          let latestDoc = documents.first,
                          let data = latestDoc.data() as? [String: Any],
                          let messageUserId = data["userId"] as? String,
                          let userName = data["userName"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return
                    }
                    
                    let messageDate = timestamp.dateValue()
                    
                    // Track latest message timestamp
                    self.latestMessageTimestamps[anchorId] = messageDate
                    
                    // Don't notify for own messages
                    if messageUserId == userId {
                        self.lastSeenTimestamps[anchorId] = messageDate
                        self.unreadEventIds.remove(anchorId)
                        return
                    }
                    
                    // Update unread status - check if latest message is newer than last seen
                    if let lastSeen = self.lastSeenTimestamps[anchorId],
                       messageDate > lastSeen {
                        self.unreadEventIds.insert(anchorId)
                    } else {
                        self.unreadEventIds.remove(anchorId)
                    }
                }
            }
        
        eventListeners[anchorId] = listener
    }
    
    func stopListeningToAnchor(anchorId: String) {
        stopListening(to: anchorId)
    }
    
    // MARK: - Mock/Testing
    
    func addMockUnreadMessages(eventIds: [String]) {
        // Add mock unread messages for testing
        let now = Date()
        for eventId in eventIds {
            // Set last seen to past
            lastSeenTimestamps[eventId] = now.addingTimeInterval(-3600) // 1 hour ago
            // Set latest message to now (newer than last seen)
            latestMessageTimestamps[eventId] = now
            // Mark as unread
            unreadEventIds.insert(eventId)
        }
        print("🧪 ChatNotificationService: Added mock unread messages for \(eventIds.count) events")
    }
}

