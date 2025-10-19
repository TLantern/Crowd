//
//   MKCoordinateRegion+Ext.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import MapKit

extension MKCoordinateRegion {
    static func meters(center: CLLocationCoordinate2D, _ meters: CLLocationDistance) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, latitudinalMeters: meters, longitudinalMeters: meters)
    }
}
