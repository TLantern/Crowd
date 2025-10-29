//
//  EventChatService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

struct ChatMessage: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let text: String
    let timestamp: Date
    let isCurrentUser: Bool
    
    init(userId: String, userName: String, text: String, isCurrentUser: Bool = false) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.text = text
        self.timestamp = Date()
        self.isCurrentUser = isCurrentUser
    }
    
    init(id: String, userId: String, userName: String, text: String, timestamp: Date, isCurrentUser: Bool) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.text = text
        self.timestamp = timestamp
        self.isCurrentUser = isCurrentUser
    }
}

@MainActor
final class EventChatService: ObservableObject {
    static let shared = EventChatService()
    
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = FirebaseManager.shared.db
    private var listener: ListenerRegistration?
    
    private init() {}
    
    func startListening(eventId: String, currentUserId: String) {
        stopListening() // Stop any existing listener
        
        isLoading = true
        error = nil
        
        listener = db.collection("eventChats")
            .document(eventId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        print("❌ EventChatService: Error listening to messages - \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.messages = []
                        return
                    }
                    
                    let newMessages = documents.compactMap { doc -> ChatMessage? in
                        let data = doc.data()
                        guard let userId = data["userId"] as? String,
                              let userName = data["userName"] as? String,
                              let text = data["text"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            return nil
                        }
                        
                        return ChatMessage(
                            id: doc.documentID,
                            userId: userId,
                            userName: userName,
                            text: text,
                            timestamp: timestamp.dateValue(),
                            isCurrentUser: userId == currentUserId
                        )
                    }
                    
                    self?.messages = newMessages
                    print("✅ EventChatService: Loaded \(newMessages.count) messages")
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
    }
    
    func sendMessage(eventId: String, text: String, userId: String, userName: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Check authentication state before sending
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            print("❌ EventChatService: No authenticated user found")
            throw NSError(domain: "EventChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🔍 EventChatService: Sending message with userId: \(userId)")
        print("🔍 EventChatService: Current auth user: \(currentUser.uid)")
        print("🔍 EventChatService: Is anonymous: \(currentUser.isAnonymous)")
        
        let messageData: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("eventChats")
                .document(eventId)
                .collection("messages")
                .addDocument(data: messageData)
            
            print("✅ EventChatService: Message sent successfully")
        } catch {
            print("❌ EventChatService: Failed to send message - \(error.localizedDescription)")
            print("❌ EventChatService: Error details - \(error)")
            throw error
        }
    }
}
