//
//  LocationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published private(set) var lastKnown: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        // Mock location for testing - UNT Union
        lastKnown = CLLocationCoordinate2D(latitude: 33.2099, longitude: -97.1515)
    }

    func requestSoftAuth() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Commented out for now - using mock location
        // lastKnown = locations.last?.coordinate
        // if let coord = lastKnown {
        //     print("📍 Location updated: \(coord.latitude), \(coord.longitude)")
        // }
    }
}
