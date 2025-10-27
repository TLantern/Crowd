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
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = manager.authorizationStatus
        
        // Set initial fallback location (UNT Union) until GPS is available
        #if DEBUG
        lastKnown = CLLocationCoordinate2D(latitude: 33.2099, longitude: -97.1515)
        print("📍 Using fallback location for testing")
        #endif
    }

    func requestSoftAuth() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
        print("📍 Started location updates")
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        print("📍 Stopped location updates")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if location is recent and accurate
        if location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 {
            lastKnown = location.coordinate
            print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 Location authorization changed: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ Location access denied")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
