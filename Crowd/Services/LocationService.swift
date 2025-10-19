//
//  LocationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var lastKnown: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestSoftAuth() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnown = locations.last?.coordinate
    }
}
