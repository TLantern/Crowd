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
    
    @State private var cameraPosition: MapCameraPosition
    @State private var expandedClusterId: String?
    @State private var currentCameraDistance: Double = 1200
    
    // MARK: - Dropdown List State
    @State private var selectedCluster: EventCluster?
    @State private var showClusterCard: Bool = false
    @State private var clusterScreenPosition: CGPoint = .zero
    
    init(events: [CrowdEvent], camera: MKCoordinateRegion, selectedEvent: Binding<CrowdEvent?>) {
        self.events = events
        self._selectedEvent = selectedEvent
        self._cameraPosition = State(initialValue: .region(camera))
    }
    
    // Cluster events before displaying
    private var clusters: [EventCluster] {
        EventClusteringService.clusterEvents(events)
    }

    var body: some View {
        GeometryReader { fullGeometry in
            ZStack {
                // MARK: - Map Layer
                Map(position: $cameraPosition) {
                    ForEach(clusters) { cluster in
                        Annotation("", coordinate: cluster.centerCoordinate) {
                            ClusterAnnotationView(
                                cluster: cluster,
                                isExpanded: expandedClusterId == cluster.id,
                                cameraDistance: currentCameraDistance,
                                onTap: {
                                    // Calculate screen position of the tapped cluster
                                    calculateClusterScreenPosition(
                                        cluster: cluster,
                                        in: fullGeometry
                                    )
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
                .environment(\.colorScheme, .dark)
            .onMapCameraChange { context in
                cameraPosition = .camera(context.camera)
                currentCameraDistance = context.camera.distance
            }
            .onTapGesture {
                // Dismiss floating card or collapse expanded cluster when tapping on map
                if showClusterCard {
                    dismissClusterCard()
                } else if expandedClusterId != nil {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        expandedClusterId = nil
                    }
                }
            }
            
            // MARK: - Dropdown List Overlay (Anchored to Pin)
            if let cluster = selectedCluster, showClusterCard {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissClusterCard()
                    }
                    .zIndex(999)
                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: clusterScreenPosition.y + 60) // Position below pin
                    
                    ClusterEventFloatingCard(
                        cluster: cluster,
                        onSelect: { event in
                            // Haptic feedback for selection
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            // Handle event selection
                            handleEventTap(event)
                            dismissClusterCard()
                        },
                        onDismiss: {
                            dismissClusterCard()
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .zIndex(1000)
                .allowsHitTesting(true)
            }
            }
        }
    }
    
    private func calculateClusterScreenPosition(cluster: EventCluster, in geometry: GeometryProxy) {
        // Estimate the screen position based on screen center
        // Since we can't directly get map coordinate conversion in SwiftUI MapKit,
        // we'll position it in the center horizontally and offset vertically
        clusterScreenPosition = CGPoint(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2 - 100
        )
    }
    
    private func handleClusterTap(_ cluster: EventCluster) {
        print("🎯 Cluster tapped - Event count: \(cluster.eventCount), IsSingle: \(cluster.isSingleEvent)")
        
        if cluster.isSingleEvent {
            // Single event - show detail directly
            if let event = cluster.events.first {
                print("   → Opening single event detail: \(event.title)")
                selectedEvent = event
            }
        } else {
            // Multi-event cluster - show floating card
            print("   → Showing floating card for \(cluster.eventCount) events")
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedCluster = cluster
                showClusterCard = true
                // Clear any expanded state
                expandedClusterId = nil
            }
            print("   → showClusterCard: \(showClusterCard), selectedCluster events: \(cluster.events.count)")
        }
    }
    
    private func dismissClusterCard() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showClusterCard = false
            selectedCluster = nil
        }
    }
    
    private func handleEventTap(_ event: CrowdEvent) {
        selectedEvent = event
    }
}

