//
//  SparkCrowdCard.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import CoreLocation
import MapKit
import ComponentsKit

struct SparkCrowdCard: View {
    @Environment(\.appEnvironment) private var appEnv
    @EnvironmentObject var appState: AppState
    
    @State private var title: String = ""
    @State private var locationName: String = ""
    @State private var selectedLocationId: String?
    @State private var coord: CLLocationCoordinate2D
    @State private var showIgniteAnimation = false
    @State private var popScale: CGFloat = 1.0
    @State private var vibrationTimer: Timer?
    @State private var igniteShakeProgress: CGFloat = 0
    
    let defaultRegion: CampusRegion
    var onIgnite: (String, CLLocationCoordinate2D, String?) -> Void
    var onClose: () -> Void
    
    init(
        defaultRegion: CampusRegion,
        onIgnite: @escaping (String, CLLocationCoordinate2D, String?) -> Void,
        onClose: @escaping () -> Void = {}
    ) {
        self.defaultRegion = defaultRegion
        self.onIgnite = onIgnite
        self.onClose = onClose
        _coord = State(initialValue: defaultRegion.spec.center)
    }
    
    private var cardModel: CardVM {
        CardVM {
            $0.cornerRadius = .medium
            $0.shadow = .medium
            $0.backgroundColor = .background
            $0.borderWidth = .medium
        }
    }
    
    var body: some View {
        ZStack {
            // Card content
            VStack(spacing: 24) {
                // Header - centered title
                Text("Spark a crowd")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                
                // Title input with better styling
                VStack(alignment: .leading, spacing: 8) {
                    TextField("What's going down?", text: $title)
                        .font(.system(size: 17, weight: .medium))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemGray6).opacity(0.8))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    title.isEmpty ? Color.clear : Color(hex: 0xff8a00).opacity(0.3),
                                    lineWidth: 2
                                )
                        )
                }
                
                // Location dropdown with icon
                Menu {
                    Button {
                        selectedLocationId = nil
                        locationName = ""
                        useCurrentLocation()
                    } label: {
                        Label("Current Location", systemImage: "location.fill")
                    }
                    
                    Divider()
                    
                    ForEach(untLocations, id: \.name) { location in
                        Button {
                            selectedLocationId = location.name
                            locationName = location.name
                            coord = location.coordinate
                            Task {
                                let query = location.searchOverride ?? location.name
                                if let coord = await searchLocationOnAppleMaps(locationName: query) {
                                    self.coord = coord
                                }
                            }
                        } label: {
                            Text(location.name)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: 0xff8a00))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if locationName.isEmpty || selectedLocationId == nil {
                                Text("Current Location")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            } else {
                                Text(locationName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6).opacity(0.8))
                    )
                }
                
                // Ignite button with gradient
                Button {
                    startIgniteSequence()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Ignite")
                            .font(.system(size: 19, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Group {
                            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray4))
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: showIgniteAnimation
                                            ? [Color(hex: 0xff8a00), Color(hex: 0xff2d00)]
                                            : [Color(hex: 0xff8a00), Color(hex: 0xff6b00)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color(hex: 0xff8a00).opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                        }
                    )
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showIgniteAnimation)
                .modifier(HorizontalShakeEffect(amount: 10, shakesPerUnit: 8, animatableData: igniteShakeProgress))
                .scaleEffect((title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.98 : 1.0) * popScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: title.isEmpty)
            }
            .padding(28)
        }
        .onAppear {
            initializeLocation()
        }
        .onDisappear {
            vibrationTimer?.invalidate()
            vibrationTimer = nil
        }
    }
    
    private func startIgniteSequence() {
        Haptics.light()
        showIgniteAnimation = true
        popScale = 1.0
        igniteShakeProgress = 0
        
        // Start vibration timer
        startVibrationTimer()
        
        withAnimation(.linear(duration: 2.0)) {
            igniteShakeProgress = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            handleAnimationCompletion()
        }
    }
    
    private func startVibrationTimer() {
        vibrationTimer?.invalidate()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        
        var elapsedTime: TimeInterval = 0
        let interval: TimeInterval = 0.1 // Vibrate every 100ms for smoother progression
        let maxDuration: TimeInterval = 2.0
        
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            elapsedTime += interval
            
            // Calculate intensity: starts at 0.3, increases to 1.0
            let progress = min(elapsedTime / maxDuration, 1.0)
            let intensity = 0.3 + (progress * 0.7)
            
            generator.impactOccurred(intensity: CGFloat(intensity))
            
            // Stop after max duration
            if elapsedTime >= maxDuration {
                timer.invalidate()
            }
        }
    }
    
    private func handleAnimationCompletion() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        
        // Pop effect
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            popScale = 1.15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                popScale = 0.9
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.2)) {
                    popScale = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onIgnite(title, coord, locationName.isEmpty ? nil : locationName)
                    onClose()
                }
            }
        }
    }
    
    private func initializeLocation() {
        appEnv.location.requestSoftAuth()
        
        if let currentLocation = appEnv.location.lastKnown {
            coord = currentLocation
            reverseGeocodeLocation(currentLocation)
        } else {
            coord = defaultRegion.spec.center
            locationName = ""
        }
    }
    
    private func useCurrentLocation() {
        appEnv.location.requestSoftAuth()
        
        if let currentLocation = appEnv.location.lastKnown {
            coord = currentLocation
            reverseGeocodeLocation(currentLocation)
        } else {
            locationName = "Getting location..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let currentLocation = appEnv.location.lastKnown {
                    coord = currentLocation
                    reverseGeocodeLocation(currentLocation)
                } else {
                    locationName = "Location unavailable"
                }
            }
        }
    }
    
    private func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D) {
        Task.detached(priority: .userInitiated) {
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = "\(coordinate.latitude),\(coordinate.longitude)"
            searchRequest.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 100,
                longitudinalMeters: 100
            )
            
            let search = MKLocalSearch(request: searchRequest)
            search.start { response, error in
                Task { @MainActor in
                    guard let response = response,
                          let mapItem = response.mapItems.first else {
                        return
                    }
                    locationName = mapItem.name ?? ""
                }
            }
        }
    }
    
    private func searchLocationOnAppleMaps(locationName: String) async -> CLLocationCoordinate2D? {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = locationName
        searchRequest.region = MKCoordinateRegion(
            center: defaultRegion.spec.center,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }
}

private struct HorizontalShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 8
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translationX = amount * sin(animatableData * .pi * 2 * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translationX, y: 0))
    }
}
