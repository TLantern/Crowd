//
//  ContentModerationService.swift
//  Crowd
//
//  Content moderation service for filtering, flagging, and blocking
//

import Foundation
import FirebaseFirestore

final class ContentModerationService {
    static let shared = ContentModerationService()
    
    private let db: Firestore
    private var blockedUsersCache: Set<String> = []
    private var hiddenEventIdsCache: Set<String> = []
    
    private init() {
        self.db = FirebaseManager.shared.db
    }
    
    // MARK: - Content Filtering
    
    func filterObjectionableContent(_ text: String) -> Bool {
        let objectionableKeywords = [
            "hate", "violence", "harassment", "abuse", "threat",
            "discrimination", "bullying", "spam", "scam", "illegal"
        ]
        
        let lowercased = text.lowercased()
        return objectionableKeywords.contains { keyword in
            lowercased.contains(keyword)
        }
    }
    
    func shouldFilterEvent(_ event: CrowdEvent, blockedUserIds: Set<String>, hiddenEventIds: Set<String>, bannedUserIds: Set<String> = []) -> Bool {
        // Filter if event is hidden
        if hiddenEventIds.contains(event.id) {
            return true
        }
        
        // Filter if host is blocked
        if blockedUserIds.contains(event.hostId) {
            return true
        }
        
        // Filter if host is banned
        if bannedUserIds.contains(event.hostId) {
            return true
        }
        
        // Filter if title contains objectionable content
        if filterObjectionableContent(event.title) {
            return true
        }
        
        // Filter if description contains objectionable content
        if let description = event.description, filterObjectionableContent(description) {
            return true
        }
        
        return false
    }
    
    func getBannedUsers() async throws -> Set<String> {
        let snapshot = try await db.collection("users")
            .whereField("banned", isEqualTo: true)
            .getDocuments()
        
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Flagging Content
    
    func flagEvent(eventId: String, userId: String, reason: String) async throws {
        // Get event hostId before flagging
        var hostId: String? = nil
        do {
            let eventDoc = try await db.collection("events").document(eventId).getDocument()
            if !eventDoc.exists {
                let userEventDoc = try await db.collection("userEvents").document(eventId).getDocument()
                if userEventDoc.exists, let data = userEventDoc.data() {
                    hostId = data["hostId"] as? String
                }
            } else if let data = eventDoc.data() {
                hostId = data["hostId"] as? String
            }
        } catch {
            print("⚠️ Could not fetch hostId for event: \(error)")
        }
        
        let flagData: [String: Any] = [
            "eventId": eventId,
            "hostId": hostId ?? "",
            "reportedBy": userId,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        try await db.collection("flaggedEvents").addDocument(data: flagData)
        print("✅ Event flagged: \(eventId) by user: \(userId) - will be reviewed within 24 hours")
    }
    
    func flagUser(userId: String, reportedBy: String, reason: String) async throws {
        let flagData: [String: Any] = [
            "userId": userId,
            "reportedBy": reportedBy,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        try await db.collection("flaggedUsers").addDocument(data: flagData)
        print("✅ User flagged: \(userId) by user: \(reportedBy)")
    }
    
    // MARK: - Blocking Users
    
    func blockUser(blockedUserId: String, currentUserId: String) async throws {
        let userRef = db.collection("users").document(currentUserId)
        
        try await userRef.updateData([
            "blockedUsers": FieldValue.arrayUnion([blockedUserId])
        ])
        
        // Update cache
        blockedUsersCache.insert(blockedUserId)
        
        print("✅ User blocked: \(blockedUserId) by user: \(currentUserId)")
    }
    
    func unblockUser(blockedUserId: String, currentUserId: String) async throws {
        let userRef = db.collection("users").document(currentUserId)
        
        try await userRef.updateData([
            "blockedUsers": FieldValue.arrayRemove([blockedUserId])
        ])
        
        // Update cache
        blockedUsersCache.remove(blockedUserId)
        
        print("✅ User unblocked: \(blockedUserId) by user: \(currentUserId)")
    }
    
    func getBlockedUsers(userId: String) async throws -> Set<String> {
        // Check cache first
        if !blockedUsersCache.isEmpty {
            return blockedUsersCache
        }
        
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = userDoc.data(),
              let blocked = data["blockedUsers"] as? [String] else {
            return []
        }
        
        let blockedSet = Set(blocked)
        blockedUsersCache = blockedSet
        return blockedSet
    }
    
    // MARK: - Hiding Posts
    
    func hideEvent(eventId: String, userId: String) async throws {
        let hideData: [String: Any] = [
            "eventId": eventId,
            "userId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("hiddenEvents").document("\(userId)_\(eventId)").setData(hideData)
        
        // Update cache
        hiddenEventIdsCache.insert(eventId)
        
        print("✅ Event hidden: \(eventId) by user: \(userId)")
    }
    
    func unhideEvent(eventId: String, userId: String) async throws {
        try await db.collection("hiddenEvents").document("\(userId)_\(eventId)").delete()
        
        // Update cache
        hiddenEventIdsCache.remove(eventId)
        
        print("✅ Event unhidden: \(eventId) by user: \(userId)")
    }
    
    func getHiddenEvents(userId: String) async throws -> Set<String> {
        // Check cache first
        if !hiddenEventIdsCache.isEmpty {
            return hiddenEventIdsCache
        }
        
        let snapshot = try await db.collection("hiddenEvents")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let hiddenIds = Set(snapshot.documents.map { doc in
            doc.data()["eventId"] as? String ?? ""
        }.filter { !$0.isEmpty })
        
        hiddenEventIdsCache = hiddenIds
        return hiddenIds
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        blockedUsersCache.removeAll()
        hiddenEventIdsCache.removeAll()
    }
    
    func refreshCache(userId: String) async {
        async let blocked = getBlockedUsers(userId: userId)
        async let hidden = getHiddenEvents(userId: userId)
        
        do {
            blockedUsersCache = try await blocked
            hiddenEventIdsCache = try await hidden
        } catch {
            print("⚠️ Failed to refresh moderation cache: \(error)")
        }
    }
}

