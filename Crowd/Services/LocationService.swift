//
//  LocationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import CoreLocation
import Combine
import FirebaseFirestore

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
        
        // Set initial mock location at Bruce Hall for testing - always visible in DEBUG
        #if DEBUG
        lastKnown = CLLocationCoordinate2D(latitude: 33.2087, longitude: -97.1524)
        print("📍 DEBUG: Mock user location set at Bruce Hall (33.2087, -97.1524)")
        #endif
    }

    func requestSoftAuth() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
        print("📍 Requesting Always authorization for background location")
    }
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
        print("📍 Started location updates")
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        print("📍 Stopped location updates")
    }
    
    func ensureLocationAvailable() async -> CLLocationCoordinate2D? {
        // If we already have a location, return it
        if let location = lastKnown {
            print("📍 LocationService: Using existing location: \(location.latitude), \(location.longitude)")
            return location
        }
        
        // Request authorization if not determined
        if authorizationStatus == .notDetermined {
            print("📍 LocationService: Requesting location authorization")
            requestSoftAuth()
            
            // Wait a bit for authorization to be granted
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Start updating location if authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            print("📍 LocationService: Starting location updates to get current location")
            startUpdatingLocation()
            
            // Wait for location update (max 5 seconds)
            for _ in 0..<50 {
                if let location = lastKnown {
                    print("📍 LocationService: Got location after waiting: \(location.latitude), \(location.longitude)")
                    return location
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        // Fallback to debug location
        #if DEBUG
        let fallbackLocation = CLLocationCoordinate2D(latitude: 33.2087, longitude: -97.1524)
        print("📍 LocationService: Using fallback location at Bruce Hall: \(fallbackLocation.latitude), \(fallbackLocation.longitude)")
        lastKnown = fallbackLocation
        return fallbackLocation
        #else
        print("❌ LocationService: No location available and not in debug mode")
        return nil
        #endif
    }
    
    // MARK: - Firestore Location Sync
    
    func saveLocationToProfile(userId: String, coordinate: CLLocationCoordinate2D) async {
        print("💾 LocationService: Saving location to Firestore for user \(userId)")
        
        let geohash = coordinate.geohash(precision: 6)
        let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            try await FirebaseManager.shared.db
                .collection("users")
                .document(userId)
                .setData([
                    "location": geoPoint,
                    "geohash": geohash,
                    "lastLocationUpdate": Timestamp(date: Date())
                ], merge: true)
            print("✅ LocationService: Location saved to Firestore")
            print("   - Lat: \(coordinate.latitude), Lon: \(coordinate.longitude)")
            print("   - Geohash: \(geohash)")
        } catch {
            print("❌ LocationService: Failed to save location - \(error.localizedDescription)")
        }
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
            print("✅ Location authorized, starting updates")
            startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ Location access denied, stopping updates")
            stopUpdatingLocation()
            // Use fallback location when denied
            #if DEBUG
            lastKnown = CLLocationCoordinate2D(latitude: 33.2087, longitude: -97.1524)
            print("📍 Using fallback location at Bruce Hall due to denied access")
            #endif
        case .notDetermined:
            print("📍 Location authorization not determined, requesting...")
            requestSoftAuth()
        @unknown default:
            break
        }
    }
}
