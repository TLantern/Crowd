//
//  CampusRegion.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import MapKit

/// Logical groupings of the UNT campus for the map.
enum CampusRegion: String, CaseIterable, Identifiable {
    case mainCampus = "Main Campus"
    case dentonSquare = "Denton Square"
    case dorms = "Dorms"
    case athletics = "Athletics"
    case sororitiesFrats = "Sororities/Frats"
    case fryStreet = "Fry Street"

    var id: String { rawValue }

    /// Configuration for how the map behaves in this region.
    var spec: RegionSpec {
        switch self {
        case .mainCampus:
            RegionSpec(center: .init(latitude: 33.21152524929094, longitude: -97.14740710640605),
                       distance: 800,
                       heading: 0,
                       pitch: 90,
                       minZoom: 80,
                       maxZoom: 2000)
        case .dentonSquare:
            RegionSpec(center: .init(latitude: 33.215019065876064, longitude: -97.13367931121785),
                       distance: 1200,
                       heading: 0,
                       pitch: 0,
                       minZoom: 120,
                       maxZoom: 3000)
        case .dorms:
            RegionSpec(center: .init(latitude: 33.20801444332677, longitude: -97.14869547061329),
                       distance: 1200,
                       heading: 0,
                       pitch: 0,
                       minZoom: 120,
                       maxZoom: 3000)
        case .athletics:
            RegionSpec(center: .init(latitude: 33.20966163808522, longitude: -97.15312219148802),
                       distance: 1200,
                       heading: 0,
                       pitch: 0,
                       minZoom: 120,
                       maxZoom: 3000)
        case .sororitiesFrats:
            RegionSpec(center: .init(latitude: 33.20874975594727, longitude: -97.14290223812876),
                       distance: 1200,
                       heading: 0,
                       pitch: 0,
                       minZoom: 120,
                       maxZoom: 3000)
        case .fryStreet:
            RegionSpec(center: .init(latitude: 33.21407, longitude: -97.14607),
                       distance: 1200,
                       heading: 0,
                       pitch: 0,
                       minZoom: 120,
                       maxZoom: 3000)
        }
    }
}
