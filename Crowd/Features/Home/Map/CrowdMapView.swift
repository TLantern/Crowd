//
//  CrowdMapView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit

struct CrowdMapView: View {
    var events: [CrowdEvent]
    var camera: MKCoordinateRegion

    var body: some View {
        Map(position: .constant(.region(camera))) {
            ForEach(events) { event in
                Annotation(event.title, coordinate: event.coordinates) {
                    EventAnnotationView(event: event)
                }
            }
            // Optional: CrowdHeatmapOverlay(dots: ...)
        }
    }
}
