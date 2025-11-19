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
import FirebaseStorage
import UIKit

struct ChatMessage: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let text: String
    let timestamp: Date
    let isCurrentUser: Bool
    let imageURL: String?
    
    init(userId: String, userName: String, text: String, imageURL: String? = nil, isCurrentUser: Bool = false) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.text = text
        self.timestamp = Date()
        self.isCurrentUser = isCurrentUser
        self.imageURL = imageURL
    }
    
    init(id: String, userId: String, userName: String, text: String, timestamp: Date, isCurrentUser: Bool, imageURL: String? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.text = text
        self.timestamp = timestamp
        self.isCurrentUser = isCurrentUser
        self.imageURL = imageURL
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
                        
                        let imageURL = data["imageURL"] as? String
                        
                        return ChatMessage(
                            id: doc.documentID,
                            userId: userId,
                            userName: userName,
                            text: text,
                            timestamp: timestamp.dateValue(),
                            isCurrentUser: userId == currentUserId,
                            imageURL: imageURL
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
    
    func sendMessage(eventId: String, text: String, userId: String, userName: String, image: UIImage? = nil, imageData: Data? = nil) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || image != nil else { return }
        
        // Check authentication state before sending
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            print("❌ EventChatService: No authenticated user found")
            throw NSError(domain: "EventChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🔍 EventChatService: Sending message with userId: \(userId)")
        print("🔍 EventChatService: Current auth user: \(currentUser.uid)")
        print("🔍 EventChatService: Is anonymous: \(currentUser.isAnonymous)")
        
        var imageURL: String? = nil
        
        if let image = image {
            let messageId = UUID().uuidString
            imageURL = try await uploadChatImage(image, eventId: eventId, messageId: messageId, imageData: imageData)
        }
        
        var messageData: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "text": trimmedText.isEmpty ? "" : trimmedText,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        if let imageURL = imageURL {
            messageData["imageURL"] = imageURL
        }
        
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
    
    func uploadChatImage(_ image: UIImage, eventId: String, messageId: String, imageData: Data? = nil) async throws -> String {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let finalImageData: Data
        let fileExtension: String
        
        if let providedData = imageData {
            let isGIF = providedData.prefix(6) == Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) || providedData.prefix(6) == Data([0x47, 0x49, 0x46, 0x38, 0x37, 0x61])
            if isGIF {
                finalImageData = providedData
                fileExtension = "gif"
            } else {
                let resizedImage = resizeImage(image, to: CGSize(width: 2048, height: 2048))
                guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "EventChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
                }
                finalImageData = jpegData
                fileExtension = "jpg"
            }
        } else {
            let resizedImage = resizeImage(image, to: CGSize(width: 2048, height: 2048))
            guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "EventChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
            }
            finalImageData = jpegData
            fileExtension = "jpg"
        }
        
        let imagePath = "chat_images/\(eventId)/\(messageId).\(fileExtension)"
        let imageRef = storageRef.child(imagePath)
        
        let metadata = StorageMetadata()
        metadata.contentType = fileExtension == "gif" ? "image/gif" : "image/jpeg"
        
        return try await withCheckedThrowingContinuation { continuation in
            _ = imageRef.putData(finalImageData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                imageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let url = url else {
                        continuation.resume(throwing: NSError(domain: "EventChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                        return
                    }
                    
                    print("✅ EventChatService: Image uploaded successfully: \(url.absoluteString)")
                    continuation.resume(returning: url.absoluteString)
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
