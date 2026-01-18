//
//  EventRepository.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation

protocol EventRepository {
    func fetchEvents(in region: CampusRegion) async throws -> [CrowdEvent]
    func create(event: CrowdEvent) async throws
    func join(eventId: String, userId: String) async throws
    func leave(eventId: String, userId: String) async throws
    func deleteEvent(eventId: String) async throws
    func boostSignal(eventId: String, delta: Int) async throws
    
    // Optional methods with default implementations
    func markPartyGoing(partyId: String, userId: String) async throws
    func unmarkPartyGoing(partyId: String, userId: String) async throws
    func getPartyGoingCount(partyId: String) async throws -> Int
    func isUserGoingToParty(partyId: String, userId: String) async throws -> Bool
    
    func markSchoolEventGoing(eventId: String, userId: String) async throws
    func unmarkSchoolEventGoing(eventId: String, userId: String) async throws
    func getSchoolEventGoingCount(eventId: String) async throws -> Int
    func isUserGoingToSchoolEvent(eventId: String, userId: String) async throws -> Bool
}

// Default implementations for optional methods
extension EventRepository {
    func markPartyGoing(partyId: String, userId: String) async throws {
        // Default: no-op
    }
    
    func unmarkPartyGoing(partyId: String, userId: String) async throws {
        // Default: no-op
    }
    
    func getPartyGoingCount(partyId: String) async throws -> Int {
        return 0
    }
    
    func isUserGoingToParty(partyId: String, userId: String) async throws -> Bool {
        return false
    }
    
    func markSchoolEventGoing(eventId: String, userId: String) async throws {
        // Default: no-op
    }
    
    func unmarkSchoolEventGoing(eventId: String, userId: String) async throws {
        // Default: no-op
    }
    
    func getSchoolEventGoingCount(eventId: String) async throws -> Int {
        return 0
    }
    
    func isUserGoingToSchoolEvent(eventId: String, userId: String) async throws -> Bool {
        return false
    }
}
