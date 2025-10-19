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
    case westSide   = "West Side"
    case dorms      = "Dorms"
    case frats      = "Frats"
    case frats2     = "Frat pt.2"
    case fryStreet  = "Fry Street"

    var id: String { rawValue }

    /// Configuration for how the map behaves in this region.
    var spec: RegionSpec {
        switch self {
        case .mainCampus:
            RegionSpec(center: .init(latitude: 33.210081, longitude: -97.147700),
                       distance: 1200)
        case .westSide:
            RegionSpec(center: .init(latitude: 33.209292, longitude: -97.152317),
                       distance: 1200)
        case .dorms:
            RegionSpec(center: .init(latitude: 33.208213, longitude: -97.148523),
                       distance: 1200)
        case .frats:
            RegionSpec(center: .init(latitude: 33.207490, longitude: -97.143432),
                       distance: 800)
        case .frats2:
            RegionSpec(center: .init(latitude: 33.209873, longitude: -97.142215),
                       distance: 800)
        case .fryStreet:
            RegionSpec(center: .init(latitude: 33.214088, longitude: -97.145887),
                       distance: 500)
        }
    }
}
