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

struct ChatGif: Identifiable, Codable {
    let id: String
    let provider: String
    let sourceUrl: String
    let thumbnailUrl: String
    let width: Int
    let height: Int
    let createdAt: Date
    let uploadedBy: String
    let tags: [String]
    let nsfw: Bool
}

struct TenorGifSelection: Sendable {
    let url: String
    let preview: String
    let width: Int
    let height: Int
    let tags: [String]
    let isNsfw: Bool
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let text: String
    let timestamp: Date
    let isCurrentUser: Bool
    let imageURL: String?
    let gifId: String?
    var gif: ChatGif?
    
    init(userId: String, userName: String, text: String, imageURL: String? = nil, gifId: String? = nil, gif: ChatGif? = nil, isCurrentUser: Bool = false) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.text = text
        self.timestamp = Date()
        self.isCurrentUser = isCurrentUser
        self.imageURL = imageURL
        self.gifId = gifId
        self.gif = gif
    }
    
    init(id: String, userId: String, userName: String, text: String, timestamp: Date, isCurrentUser: Bool, imageURL: String? = nil, gifId: String? = nil, gif: ChatGif? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.text = text
        self.timestamp = timestamp
        self.isCurrentUser = isCurrentUser
        self.imageURL = imageURL
        self.gifId = gifId
        self.gif = gif
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
    private var gifCache: [String: ChatGif] = [:]
    
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
                        let gifId = data["gifId"] as? String
                        let cachedGif = gifId.flatMap { self?.gifCache[$0] }
                        
                        return ChatMessage(
                            id: doc.documentID,
                            userId: userId,
                            userName: userName,
                            text: text,
                            timestamp: timestamp.dateValue(),
                            isCurrentUser: userId == currentUserId,
                            imageURL: imageURL,
                            gifId: gifId,
                            gif: cachedGif
                        )
                    }
                    
                    self?.messages = newMessages
                    self?.prefetchMissingGifs(for: newMessages)
                    print("✅ EventChatService: Loaded \(newMessages.count) messages")
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
    }
    
    func sendGifMessage(eventId: String, tenorGif: TenorGifSelection, userId: String, userName: String) async throws {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            throw NSError(domain: "EventChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard currentUser.uid == userId else {
            throw NSError(domain: "EventChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "User mismatch"])
        }
        
        let gifRef = db.collection("gifs").document()
        let gifData: [String: Any] = [
            "id": gifRef.documentID,
            "provider": "tenor",
            "sourceUrl": tenorGif.url,
            "thumbnailUrl": tenorGif.preview,
            "width": tenorGif.width,
            "height": tenorGif.height,
            "createdAt": FieldValue.serverTimestamp(),
            "uploadedBy": userId,
            "tags": tenorGif.tags,
            "nsfw": tenorGif.isNsfw
        ]
        
        try await db.runTransaction { transaction, _ in
            transaction.setData(gifData, forDocument: gifRef)
            transaction.setData([
                "userId": userId,
                "userName": userName,
                "text": "",
                "timestamp": FieldValue.serverTimestamp(),
                "gifId": gifRef.documentID
            ], forDocument: self.db.collection("eventChats").document(eventId).collection("messages").document())
            return nil
        }
    }
    
    func sendMessage(eventId: String, text: String, userId: String, userName: String, image: UIImage? = nil, imageData: Data? = nil) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || image != nil else {
            print("⚠️ EventChatService: Cannot send empty message (no text or image)")
            throw NSError(domain: "EventChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot send empty message"])
        }
        
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
        let fileExtension: String = "jpg"
        
        if let providedData = imageData {
            let isGIF = providedData.prefix(6) == Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) || providedData.prefix(6) == Data([0x47, 0x49, 0x46, 0x38, 0x37, 0x61])
            if isGIF {
                throw NSError(domain: "EventChatService", code: 415, userInfo: [NSLocalizedDescriptionKey: "GIF uploads are not supported"])
            } else {
                let resizedImage = resizeImage(image, to: CGSize(width: 2048, height: 2048))
                guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "EventChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
                }
                finalImageData = jpegData
            }
        } else {
            let resizedImage = resizeImage(image, to: CGSize(width: 2048, height: 2048))
            guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "EventChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
            }
            finalImageData = jpegData
        }
        
        let imagePath = "chat_images/\(eventId)/\(messageId).\(fileExtension)"
        let imageRef = storageRef.child(imagePath)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
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
    
    private func prefetchMissingGifs(for messages: [ChatMessage]) {
        let missing = Set(messages.compactMap(\.gifId)).subtracting(gifCache.keys)
        guard !missing.isEmpty else { return }
        
        for gifId in missing {
            db.collection("gifs").document(gifId).getDocument { [weak self] snapshot, _ in
                guard let self, let data = snapshot?.data() else { return }
                guard let id = data["id"] as? String,
                      let provider = data["provider"] as? String,
                      let sourceUrl = data["sourceUrl"] as? String,
                      let thumbnailUrl = data["thumbnailUrl"] as? String,
                      let width = data["width"] as? Int,
                      let height = data["height"] as? Int,
                      let createdAt = data["createdAt"] as? Timestamp,
                      let uploadedBy = data["uploadedBy"] as? String,
                      let tags = data["tags"] as? [String],
                      let nsfw = data["nsfw"] as? Bool else { return }
                
                Task { @MainActor in
                    let gif = ChatGif(
                        id: id,
                        provider: provider,
                        sourceUrl: sourceUrl,
                        thumbnailUrl: thumbnailUrl,
                        width: width,
                        height: height,
                        createdAt: createdAt.dateValue(),
                        uploadedBy: uploadedBy,
                        tags: tags,
                        nsfw: nsfw
                    )
                    self.gifCache[gifId] = gif
                    self.messages = self.messages.map { msg in
                        guard msg.gifId == gifId else { return msg }
                        var updated = msg
                        updated.gif = gif
                        return updated
                    }
                }
            }
        }
    }
}
