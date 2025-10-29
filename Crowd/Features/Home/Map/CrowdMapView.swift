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
    @Binding var selectedEvent: CrowdEvent?
    @Binding var showEventDetail: Bool
    
    @State private var cameraPosition: MapCameraPosition
    @State private var expandedClusterId: String?
    @State private var currentCameraDistance: Double = 1200
    
    init(events: [CrowdEvent], camera: MKCoordinateRegion, selectedEvent: Binding<CrowdEvent?>, showEventDetail: Binding<Bool>) {
        self.events = events
        self._selectedEvent = selectedEvent
        self._showEventDetail = showEventDetail
        self._cameraPosition = State(initialValue: .region(camera))
    }
    
    // Cluster events before displaying
    private var clusters: [EventCluster] {
        EventClusteringService.clusterEvents(events)
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(clusters) { cluster in
                Annotation("", coordinate: cluster.centerCoordinate) {
                    ClusterAnnotationView(
                        cluster: cluster,
                        isExpanded: expandedClusterId == cluster.id,
                        cameraDistance: currentCameraDistance,
                        onTap: {
                            handleClusterTap(cluster)
                        },
                        onEventTap: { event in
                            handleEventTap(event)
                        }
                    )
                }
            }
            // Optional: CrowdHeatmapOverlay(dots: ...)
        }
        .onMapCameraChange { context in
            cameraPosition = .camera(context.camera)
            currentCameraDistance = context.camera.distance
        }
        .onTapGesture {
            // Collapse expanded cluster when tapping on map
            if expandedClusterId != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    expandedClusterId = nil
                }
            }
        }
    }
    
    private func handleClusterTap(_ cluster: EventCluster) {
        if cluster.isSingleEvent {
            // Single event - show detail directly
            if let event = cluster.events.first {
                selectedEvent = event
                showEventDetail = true
            }
        } else {
            // Multi-event cluster - toggle expansion
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                if expandedClusterId == cluster.id {
                    expandedClusterId = nil
                } else {
                    expandedClusterId = cluster.id
                }
            }
        }
    }
    
    private func handleEventTap(_ event: CrowdEvent) {
        selectedEvent = event
        showEventDetail = true
    }
}
