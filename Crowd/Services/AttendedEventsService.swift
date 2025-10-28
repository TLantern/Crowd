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
    }
    
    // MARK: - Public Methods
    
    func addAttendedEvent(_ event: CrowdEvent) {
        guard !isAttendingEvent(event.id) else { return }
        
        attendedEvents.append(event)
        saveAttendedEvents()
        
        // Update user profile joined count
        updateUserJoinedCount()
        
        print("✅ Added event to attended: \(event.title)")
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
}
