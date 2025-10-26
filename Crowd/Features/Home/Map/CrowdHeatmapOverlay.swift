//
//  CrowdHeatmapOverlay.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit

struct HeatmapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let intensity: Double // 0.0 to 1.0
}

struct CrowdHeatmapOverlay: View {
    let events: [CrowdEvent]
    let mapRegion: MKCoordinateRegion
    
    var heatmapPoints: [HeatmapPoint] {
        events.map { event in
            // Calculate intensity based on attendance
            let normalizedIntensity = min(Double(event.attendeeCount) / 40.0, 1.0)
            return HeatmapPoint(
                coordinate: event.coordinates,
                intensity: max(0.4, normalizedIntensity)
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw heat blobs for each event
                for point in heatmapPoints {
                    // Convert coordinate to screen position
                    if let screenPoint = coordinateToPoint(point.coordinate, in: geometry, region: mapRegion, size: size) {
                        drawHeatBlob(
                            at: screenPoint,
                            intensity: point.intensity,
                            in: &context,
                            size: size
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
    
    private func drawHeatBlob(at point: CGPoint, intensity: Double, in context: inout GraphicsContext, size: CGSize) {
        // Smaller, more localized radius for distinct hotspots
        let radius: CGFloat = 60 * intensity
        
        // More focused gradient with sharper falloff
        let colors: [Color] = [
            Color(red: 1.0, green: 0.0, blue: 0.0).opacity(intensity * 0.85),      // Deep red center
            Color(red: 1.0, green: 0.4, blue: 0.0).opacity(intensity * 0.65),      // Red-orange
            Color(red: 1.0, green: 0.7, blue: 0.0).opacity(intensity * 0.4),       // Orange
            Color(red: 1.0, green: 0.9, blue: 0.0).opacity(intensity * 0.2),       // Yellow-orange
            Color(red: 1.0, green: 1.0, blue: 0.4).opacity(intensity * 0.08),      // Light yellow
            Color.clear
        ]
        
        let gradient = Gradient(colors: colors)
        
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        
        // Draw tighter radial gradient for individual hotspots
        context.fill(
            Circle().path(in: rect),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: radius
            )
        )
    }
    
    private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, in geometry: GeometryProxy, region: MKCoordinateRegion, size: CGSize) -> CGPoint? {
        // Calculate normalized position within the map region
        let latSpan = region.span.latitudeDelta
        let lonSpan = region.span.longitudeDelta
        
        // Calculate offset from region center (-0.5 to 0.5)
        let latOffset = (coordinate.latitude - region.center.latitude) / latSpan
        let lonOffset = (coordinate.longitude - region.center.longitude) / lonSpan
        
        // Convert to screen coordinates (center at 0.5, 0.5)
        let x = size.width * (0.5 + lonOffset)
        let y = size.height * (0.5 - latOffset) // Inverted Y axis for map coordinates
        
        // Allow some overflow for edge rendering
        guard x >= -200 && x <= size.width + 200 && y >= -200 && y <= size.height + 200 else {
            return nil
        }
        
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    CrowdHeatmapOverlay(
        events: [
            CrowdEvent(
                id: "1",
                title: "Basketball",
                hostId: "h1",
                hostName: "Host 1",
                latitude: 33.2105,
                longitude: -97.1520,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 4,
                attendeeCount: 45,
                tags: [],
                category: "sports"
            ),
            CrowdEvent(
                id: "2",
                title: "Party",
                hostId: "h2",
                hostName: "Host 2",
                latitude: 33.2108,
                longitude: -97.1522,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 5,
                attendeeCount: 60,
                tags: [],
                category: "party"
            ),
            CrowdEvent(
                id: "3",
                title: "Study",
                hostId: "h3",
                hostName: "Host 3",
                latitude: 33.2110,
                longitude: -97.1518,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 3,
                attendeeCount: 15,
                tags: [],
                category: "study"
            )
        ],
        mapRegion: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.2105, longitude: -97.1520),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )
    .frame(width: 400, height: 400)
    .background(Color.gray.opacity(0.3))
}
