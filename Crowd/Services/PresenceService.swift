//
//  PresenceService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation

actor PresenceService {
    func heartbeat(userId: String, at coordinate: CLLocationCoordinate2D) async { /* send */ }
    func density(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async -> Int { 0 }
}
