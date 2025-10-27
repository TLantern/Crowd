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
    @State private var cameraPosition: MapCameraPosition
    
    init(events: [CrowdEvent], camera: MKCoordinateRegion) {
        self.events = events
        self._cameraPosition = State(initialValue: .region(camera))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(events) { event in
                Annotation(event.title, coordinate: event.coordinates) {
                    EventAnnotationView(event: event)
                }
            }
            // Optional: CrowdHeatmapOverlay(dots: ...)
        }
        .onMapCameraChange { context in
            cameraPosition = .camera(context.camera)
        }
    }
}
