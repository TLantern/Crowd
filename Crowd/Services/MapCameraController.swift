//
//  MapCameraController.swift
//  Crowd
//

import MapKit
import _MapKit_SwiftUI

/// UI-only helper that builds a MapCameraPosition from a pure RegionSpec.
/// We avoid MapCamera here to dodge SDK/availability headaches.
enum MapCameraController {
    @MainActor
    static func position(from spec: RegionSpec) -> MapCameraPosition {
        let region = MKCoordinateRegion(
            center: spec.center,
            latitudinalMeters: spec.distance,
            longitudinalMeters: spec.distance
        )
        return .region(region)
    }
}
