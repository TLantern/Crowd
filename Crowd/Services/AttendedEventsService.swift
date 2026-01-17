//
//  AttendedEventsService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

final class AttendedEventsService: ObservableObject {
    static let shared = AttendedEventsService()
    
    @Published private(set) var attendedEvents: [CrowdEvent] = []
    
    private let userDefaults = UserDefaults.standard
    private let attendedEventsKey = "attended_events"
    
    private init() {
        loadAttendedEvents()
        cleanupExpiredEvents()
    }
    
    // MARK: - Public Methods
    
    func addAttendedEvent(_ event: CrowdEvent) {
        guard !isAttendingEvent(event.id) else {
            print("⚠️ Event already in attended list: \(event.title) (id: \(event.id))")
            return
        }
        
        attendedEvents.append(event)
        saveAttendedEvents()
        
        // Update user profile joined count
        updateUserJoinedCount()
        
        print("✅ Added event to attended: \(event.title) (id: \(event.id))")
        print("📊 Total attended events: \(attendedEvents.count)")
    }
    
    func removeAttendedEvent(_ eventId: String) {
        attendedEvents.removeAll { $0.id == eventId }
        saveAttendedEvents()
        
        // Update user profile joined count
        updateUserJoinedCount()
        
        print("✅ Removed event from attended: \(eventId)")
    }
    
    func isAttendingEvent(_ eventId: String) -> Bool {
        return attendedEvents.contains { $0.id == eventId }
    }
    
    func getAttendedEvents() -> [CrowdEvent] {
        return attendedEvents
    }
    
    func refreshAttendedEvents() {
        cleanupExpiredEvents()
    }
    
    // MARK: - Private Methods
    
    private func loadAttendedEvents() {
        guard let data = userDefaults.data(forKey: attendedEventsKey),
              let events = try? JSONDecoder().decode([CrowdEvent].self, from: data) else {
            attendedEvents = []
            return
        }
        attendedEvents = events
    }
    
    private func saveAttendedEvents() {
        guard let data = try? JSONEncoder().encode(attendedEvents) else { return }
        userDefaults.set(data, forKey: attendedEventsKey)
    }
    
    private func updateUserJoinedCount() {
        // This would typically update the user's profile in Firebase
        // For now, we'll just log the count
        print("📊 User has attended \(attendedEvents.count) events")
    }
    
    private func cleanupExpiredEvents() {
        let now = Date()
        let originalCount = attendedEvents.count
        
        // Remove events that have ended (check if event time was more than 4 hours ago)
        let expiredEventIds = attendedEvents.filter { event in
            guard let time = event.time else { return false }
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time < fourHoursAgo
        }.map { $0.id }
        
        // Remove expired events from local storage
        attendedEvents.removeAll { event in
            guard let time = event.time else { return false }
            let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
            return time < fourHoursAgo
        }
        
        let removedCount = originalCount - attendedEvents.count
        if removedCount > 0 {
            print("🧹 Cleaned up \(removedCount) expired events from attended list")
            saveAttendedEvents()
            
            // Remove signals and attendances from Firestore for expired events
            Task {
                await removeUsersFromExpiredEvents(eventIds: expiredEventIds)
            }
        }
    }
    
    private func removeUsersFromExpiredEvents(eventIds: [String]) async {
        guard !eventIds.isEmpty else { return }
        
        let db = FirebaseManager.shared.db
        
        for eventId in eventIds {
            do {
                // Delete signals for this event
                let signalsSnapshot = try await db.collection("signals")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                if !signalsSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    signalsSnapshot.documents.forEach { doc in
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                    print("✅ Removed \(signalsSnapshot.documents.count) signal(s) for expired event \(eventId)")
                }
                
                // Delete attendances for this event
                let attendancesSnapshot = try await db.collection("userAttendances")
                    .whereField("eventId", isEqualTo: eventId)
                    .getDocuments()
                
                if !attendancesSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    attendancesSnapshot.documents.forEach { doc in
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                    print("✅ Removed \(attendancesSnapshot.documents.count) attendance(s) for expired event \(eventId)")
                }
            } catch {
                print("❌ Failed to remove users from expired event \(eventId): \(error)")
            }
        }
    }
}
