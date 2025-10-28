//
//  EventRepository.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore

protocol EventRepository {
    func fetchEvents(in region: CampusRegion) async throws -> [CrowdEvent]
    func create(event: CrowdEvent) async throws
    func join(eventId: String, userId: String) async throws
    func deleteEvent(eventId: String) async throws
    func boostSignal(eventId: String, delta: Int) async throws
    func listenToEvents(in region: CampusRegion, onChange: @escaping ([CrowdEvent]) -> Void) -> ListenerRegistration
}
