//
//  AccountDeletionService.swift
//  Crowd
//
//  Service for handling complete account deletion per App Store requirements.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

extension Notification.Name {
    static let accountDeleted = Notification.Name("accountDeleted")
}

final class AccountDeletionService {
    static let shared = AccountDeletionService()
    
    private let db: Firestore
    private let functions: Functions
    
    private init() {
        self.db = FirebaseManager.shared.db
        self.functions = FirebaseManager.shared.functions
    }
    
    /// Permanently deletes a user account and all associated data
    /// This is a complete deletion, not deactivation, per App Store guidelines
    func deleteAccount(userId: String) async throws {
        print("🗑️ Starting account deletion for user: \(userId)")
        
        // Try server-side deletion first (more robust)
        do {
            let callable = functions.httpsCallable("deleteUserAccount")
            _ = try await callable.call()
            print("✅ Account deleted via Cloud Function")
            return
        } catch {
            print("⚠️ Cloud Function deletion failed, falling back to client-side: \(error.localizedDescription)")
            // Fall back to client-side deletion
        }
        
        // 1. Delete all events created by the user
        try await deleteUserEvents(userId: userId)
        
        // 2. Delete all signals (event attendance records)
        try await deleteUserSignals(userId: userId)
        
        // 3. Delete all user attendances
        try await deleteUserAttendances(userId: userId)
        
        // 4. Delete all chat messages from the user
        try await deleteUserChatMessages(userId: userId)
        
        // 5. Delete hidden events records
        try await deleteHiddenEvents(userId: userId)
        
        // 6. Delete any flagged content reports by this user
        try await deleteFlagReports(userId: userId)
        
        // 7. Delete the user profile document
        try await deleteUserProfile(userId: userId)
        
        // 8. Delete Firebase Auth account
        try await deleteFirebaseAuthAccount()
        
        print("✅ Account deletion complete for user: \(userId)")
    }
    
    // MARK: - Private Deletion Methods
    
    private func deleteUserEvents(userId: String) async throws {
        // Delete from events collection
        let eventsSnapshot = try await db.collection("events")
            .whereField("hostId", isEqualTo: userId)
            .getDocuments()
        
        for doc in eventsSnapshot.documents {
            let eventId = doc.documentID
            
            // Delete related chat messages for this event
            await deleteEventChat(eventId: eventId)
            
            // Delete related signals
            let signalsSnapshot = try await db.collection("signals")
                .whereField("eventId", isEqualTo: eventId)
                .getDocuments()
            
            for signalDoc in signalsSnapshot.documents {
                try await signalDoc.reference.delete()
            }
            
            // Delete the event
            try await doc.reference.delete()
        }
        
        // Delete from userEvents collection
        let userEventsSnapshot = try await db.collection("userEvents")
            .whereField("hostId", isEqualTo: userId)
            .getDocuments()
        
        for doc in userEventsSnapshot.documents {
            let eventId = doc.documentID
            
            // Delete related chat messages
            await deleteEventChat(eventId: eventId)
            
            // Delete related signals
            let signalsSnapshot = try await db.collection("signals")
                .whereField("eventId", isEqualTo: eventId)
                .getDocuments()
            
            for signalDoc in signalsSnapshot.documents {
                try await signalDoc.reference.delete()
            }
            
            try await doc.reference.delete()
        }
        
        print("   ✓ Deleted user's events")
    }
    
    private func deleteUserSignals(userId: String) async throws {
        let snapshot = try await db.collection("signals")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in snapshot.documents {
            // Decrement attendee count on the event
            if let eventId = doc.data()["eventId"] as? String {
                let eventRef = db.collection("events").document(eventId)
                try? await eventRef.updateData([
                    "attendeeCount": FieldValue.increment(Int64(-1))
                ])
                
                let userEventRef = db.collection("userEvents").document(eventId)
                try? await userEventRef.updateData([
                    "attendeeCount": FieldValue.increment(Int64(-1))
                ])
            }
            
            try await doc.reference.delete()
        }
        
        print("   ✓ Deleted user's signals")
    }
    
    private func deleteUserAttendances(userId: String) async throws {
        let snapshot = try await db.collection("userAttendances")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
        
        print("   ✓ Deleted user's attendances")
    }
    
    private func deleteUserChatMessages(userId: String) async throws {
        // Get all eventChats and delete messages from this user
        let chatsSnapshot = try await db.collection("eventChats").getDocuments()
        
        for chatDoc in chatsSnapshot.documents {
            let messagesSnapshot = try await chatDoc.reference.collection("messages")
                .whereField("senderId", isEqualTo: userId)
                .getDocuments()
            
            for messageDoc in messagesSnapshot.documents {
                try await messageDoc.reference.delete()
            }
        }
        
        // Also check anchor chats
        let anchorChatsSnapshot = try await db.collection("anchorChats").getDocuments()
        
        for chatDoc in anchorChatsSnapshot.documents {
            let messagesSnapshot = try await chatDoc.reference.collection("messages")
                .whereField("senderId", isEqualTo: userId)
                .getDocuments()
            
            for messageDoc in messagesSnapshot.documents {
                try await messageDoc.reference.delete()
            }
        }
        
        print("   ✓ Deleted user's chat messages")
    }
    
    private func deleteHiddenEvents(userId: String) async throws {
        let snapshot = try await db.collection("hiddenEvents")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
        
        print("   ✓ Deleted user's hidden events records")
    }
    
    private func deleteFlagReports(userId: String) async throws {
        // Delete reports made by this user
        let eventFlagsSnapshot = try await db.collection("flaggedEvents")
            .whereField("reportedBy", isEqualTo: userId)
            .getDocuments()
        
        for doc in eventFlagsSnapshot.documents {
            try await doc.reference.delete()
        }
        
        let userFlagsSnapshot = try await db.collection("flaggedUsers")
            .whereField("reportedBy", isEqualTo: userId)
            .getDocuments()
        
        for doc in userFlagsSnapshot.documents {
            try await doc.reference.delete()
        }
        
        print("   ✓ Deleted user's flag reports")
    }
    
    private func deleteEventChat(eventId: String) async {
        do {
            let messagesRef = db.collection("eventChats").document(eventId).collection("messages")
            
            while true {
                let messagesSnap = try await messagesRef.limit(to: 500).getDocuments()
                if messagesSnap.documents.isEmpty { break }
                
                for doc in messagesSnap.documents {
                    try await doc.reference.delete()
                }
                
                if messagesSnap.documents.count < 500 { break }
            }
            
            try await db.collection("eventChats").document(eventId).delete()
        } catch {
            print("   ⚠️ Failed to delete event chat: \(error.localizedDescription)")
        }
    }
    
    private func deleteUserProfile(userId: String) async throws {
        try await db.collection("users").document(userId).delete()
        print("   ✓ Deleted user profile")
    }
    
    private func deleteFirebaseAuthAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            print("   ⚠️ No Firebase Auth user to delete")
            return
        }
        
        try await user.delete()
        print("   ✓ Deleted Firebase Auth account")
    }
}

