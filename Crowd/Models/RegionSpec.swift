//
//  RegionSpec.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation

/// Pure data describing a region's camera + zoom behavior.
/// No UI/MapKit types here so it's safe across actors.
struct RegionSpec: Sendable {
    let center: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let minZoom: CLLocationDistance
    let maxZoom: CLLocationDistance
    let heading: CLLocationDirection
    let pitch: Double

    init(center: CLLocationCoordinate2D,
         distance: CLLocationDistance,
         heading: CLLocationDirection = 0,
         pitch: Double = 0,
         minZoom: CLLocationDistance = 120,
         maxZoom: CLLocationDistance = 3000) {
        self.center = center
        self.distance = distance
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.heading = heading
        self.pitch = pitch
    }
}
