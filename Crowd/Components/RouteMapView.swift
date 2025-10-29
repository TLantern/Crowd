//
//  RouteMapView.swift
//  Crowd
//
//  Lightweight MKMapView wrapper that draws a live route
//  from the user's location to a destination and shows
//  the moving user location dot.
//

import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {
    let destination: CLLocationCoordinate2D
    let userCoordinate: CLLocationCoordinate2D?
    var transportType: MKDirectionsTransportType = .walking

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .includingAll
        map.isRotateEnabled = true
        map.isPitchEnabled = true

        // Add destination annotation
        let pin = MKPointAnnotation()
        pin.coordinate = destination
        map.addAnnotation(pin)

        // Initial camera fit
        context.coordinator.fitCamera(map: map)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Keep a single annotation for destination (update if changed)
        if let annotation = map.annotations.first(where: { !($0 is MKUserLocation) }) as? MKPointAnnotation {
            if annotation.coordinate.latitude != destination.latitude || annotation.coordinate.longitude != destination.longitude {
                annotation.coordinate = destination
            }
        }

        // Recalculate route when userCoordinate changes significantly
        context.coordinator.updateRouteIfNeeded(map: map,
                                               userCoordinate: userCoordinate,
                                               destination: destination,
                                               transportType: transportType)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var lastRoutedOrigin: CLLocationCoordinate2D?
        private var lastRouteAt: Date = .distantPast

        // Thresholds
        private let minDistanceMeters: CLLocationDistance = 10 // 10m move triggers reroute
        private let minIntervalSeconds: TimeInterval = 5        // min 5s between reroutes

        func updateRouteIfNeeded(map: MKMapView,
                                 userCoordinate: CLLocationCoordinate2D?,
                                 destination: CLLocationCoordinate2D,
                                 transportType: MKDirectionsTransportType) {
            guard let origin = userCoordinate else {
                // Center on destination if no user location yet
                fitCamera(map: map, origin: nil, destination: destination)
                return
            }

            let now = Date()
            let movedEnough: Bool
            if let last = lastRoutedOrigin {
                let a = CLLocation(latitude: last.latitude, longitude: last.longitude)
                let b = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                movedEnough = a.distance(from: b) >= minDistanceMeters
            } else {
                movedEnough = true
            }

            guard movedEnough || now.timeIntervalSince(lastRouteAt) >= minIntervalSeconds else { return }

            lastRoutedOrigin = origin
            lastRouteAt = now

            route(map: map, from: origin, to: destination, transportType: transportType)
        }

        private func route(map: MKMapView,
                           from origin: CLLocationCoordinate2D,
                           to destination: CLLocationCoordinate2D,
                           transportType: MKDirectionsTransportType) {
            // Remove existing polylines
            let overlays = map.overlays
            if !overlays.isEmpty { map.removeOverlays(overlays) }

            let req = MKDirections.Request()
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            req.transportType = transportType
            req.requestsAlternateRoutes = false

            MKDirections(request: req).calculate { [weak self] response, error in
                guard let self = self else { return }
                if let route = response?.routes.first {
                    map.addOverlay(route.polyline)
                    self.fitCamera(map: map, origin: origin, destination: destination)
                } else {
                    // Fallback: fit to both points even without a route
                    self.fitCamera(map: map, origin: origin, destination: destination)
                }
            }
        }

        func fitCamera(map: MKMapView,
                       origin: CLLocationCoordinate2D? = nil,
                       destination: CLLocationCoordinate2D? = nil) {
            var rect: MKMapRect?

            func add(_ coord: CLLocationCoordinate2D) {
                let point = MKMapPoint(coord)
                let small = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
                rect = rect?.union(small) ?? small
            }

            if let o = origin { add(o) }
            if let d = destination { add(d) }

            if let r = rect {
                let padded = map.mapRectThatFits(r, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40))
                map.setVisibleMapRect(padded, animated: true)
            } else if let user = map.userLocation.location?.coordinate {
                map.setCenter(user, animated: false)
            }
        }

        // MARK: MKMapViewDelegate
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}


