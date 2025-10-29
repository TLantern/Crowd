//
//  AttendedEventsService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import Foundation
import SwiftUI
import Combine

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
        
        // Remove events that have ended more than 1 hour ago
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        
        attendedEvents.removeAll { event in
            guard let endsAt = event.endsAt else {
                // If no end time, check if event started more than 4 hours ago
                guard let startsAt = event.startsAt else { return false }
                let fourHoursAgo = Calendar.current.date(byAdding: .hour, value: -4, to: now) ?? now
                return startsAt < fourHoursAgo
            }
            return endsAt < oneHourAgo
        }
        
        let removedCount = originalCount - attendedEvents.count
        if removedCount > 0 {
            print("🧹 Cleaned up \(removedCount) expired events from attended list")
            saveAttendedEvents()
        }
    }
}
