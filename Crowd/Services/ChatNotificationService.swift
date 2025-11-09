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
                    
                    // Don't notify for own messages
                    if messageUserId == userId {
                        // Update last seen timestamp to current message
                        self.lastSeenTimestamps[event.id] = messageDate
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
    }
    
    func updateLastSeen(eventId: String, timestamp: Date) {
        lastSeenTimestamps[eventId] = timestamp
    }
}

