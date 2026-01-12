//
//  CampusSelectionView.swift
//  Crowd
//
//  First-launch campus selection view.
//  This is shown BEFORE account creation to allow immediate app exploration.
//  Campus choice is persisted locally - no authentication required.
//

import SwiftUI
import CoreLocation

struct CampusSelectionView: View {
    @AppStorage("selectedCampusId") private var selectedCampusId: String = "UNT"
    @AppStorage("hasCompletedCampusSelection") private var hasCompletedCampusSelection: Bool = false
    
    @State private var searchText: String = ""
    @State private var isDetectingLocation: Bool = false
    @State private var detectedCampus: Campus? = nil
    @State private var showLocationError: Bool = false
    
    let onComplete: () -> Void
    
    // Available campuses (expandable for future schools)
    private let campuses: [Campus] = [
        Campus(id: "UNT", name: "University of North Texas", shortName: "UNT", location: "Denton, TX", coordinate: CLLocationCoordinate2D(latitude: 33.210081, longitude: -97.147700), isAvailable: true),
        Campus(id: "UTD", name: "UT Dallas", shortName: "UTD", location: "Richardson, TX", coordinate: CLLocationCoordinate2D(latitude: 32.9857, longitude: -96.7502), isAvailable: false),
        Campus(id: "UTA", name: "UT Arlington", shortName: "UTA", location: "Arlington, TX", coordinate: CLLocationCoordinate2D(latitude: 32.7299, longitude: -97.1131), isAvailable: false),
        Campus(id: "UT", name: "UT Austin", shortName: "UT", location: "Austin, TX", coordinate: CLLocationCoordinate2D(latitude: 30.2849, longitude: -97.7341), isAvailable: false),
        Campus(id: "UTSA", name: "UT San Antonio", shortName: "UTSA", location: "San Antonio, TX", coordinate: CLLocationCoordinate2D(latitude: 29.5826, longitude: -98.6199), isAvailable: false),
        Campus(id: "UH", name: "University of Houston", shortName: "UH", location: "Houston, TX", coordinate: CLLocationCoordinate2D(latitude: 29.7199, longitude: -95.3422), isAvailable: false),
        Campus(id: "TXST", name: "Texas State University", shortName: "TXST", location: "San Marcos, TX", coordinate: CLLocationCoordinate2D(latitude: 29.8884, longitude: -97.9384), isAvailable: false)
    ]
    
    private var filteredCampuses: [Campus] {
        if searchText.isEmpty {
            return campuses
        }
        return campuses.filter { campus in
            campus.name.localizedCaseInsensitiveContains(searchText) ||
            campus.shortName.localizedCaseInsensitiveContains(searchText) ||
            campus.location.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image("CrowdText")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 90)
                    
                    Text("Select Your Campus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("See what's happening near you")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(.top, 60)
                .padding(.bottom, 24)
                
                // Main content card
                VStack(spacing: 16) {
                    // Auto-detect button
                    Button(action: detectLocation) {
                        HStack(spacing: 12) {
                            if isDetectingLocation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                            }
                            Text(isDetectingLocation ? "Detecting..." : "Use My Location")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: 0x02853E))
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(isDetectingLocation)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.2))
                            .frame(height: 1)
                        Text("or search")
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.5))
                        Rectangle()
                            .fill(Color.black.opacity(0.2))
                            .frame(height: 1)
                    }
                    
                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.black.opacity(0.5))
                        TextField("Search schools...", text: $searchText)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.6))
                    )
                    
                    // Campus list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredCampuses) { campus in
                                CampusRowView(
                                    campus: campus,
                                    isSelected: selectedCampusId == campus.id,
                                    onSelect: {
                                        if campus.isAvailable {
                                            selectCampus(campus)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                    
                    // Continue button
                    Button(action: completeSelection) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black)
                            )
                            .foregroundColor(.white)
                    }
                    
                    // Skip option (defaults to UNT)
                    Button(action: skipSelection) {
                        Text("Skip for now")
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .alert("Location Error", isPresented: $showLocationError) {
            Button("OK") {}
        } message: {
            Text("Unable to detect your location. Please select your campus manually.")
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Actions
    
    private func detectLocation() {
        isDetectingLocation = true
        
        // Use LocationService to get current location
        Task {
            // Wait a moment for location
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            if let location = AppEnvironment.current.location.lastKnown {
                // Find nearest available campus
                let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                
                var nearestCampus: Campus? = nil
                var nearestDistance: CLLocationDistance = .infinity
                
                for campus in campuses where campus.isAvailable {
                    let campusLocation = CLLocation(latitude: campus.coordinate.latitude, longitude: campus.coordinate.longitude)
                    let distance = userLocation.distance(from: campusLocation)
                    
                    if distance < nearestDistance {
                        nearestDistance = distance
                        nearestCampus = campus
                    }
                }
                
                await MainActor.run {
                    isDetectingLocation = false
                    if let campus = nearestCampus {
                        detectedCampus = campus
                        selectCampus(campus)
                    } else {
                        // Default to UNT if no campus found
                        if let unt = campuses.first(where: { $0.id == "UNT" }) {
                            selectCampus(unt)
                        }
                    }
                }
            } else {
                await MainActor.run {
                    isDetectingLocation = false
                    showLocationError = true
                }
            }
        }
    }
    
    private func selectCampus(_ campus: Campus) {
        selectedCampusId = campus.id
        
        // Track analytics
        AnalyticsService.shared.track("campus_selected", props: [
            "campus_id": campus.id,
            "campus_name": campus.name,
            "method": detectedCampus?.id == campus.id ? "auto_detect" : "manual"
        ])
    }
    
    private func completeSelection() {
        hasCompletedCampusSelection = true
        
        // Track analytics
        AnalyticsService.shared.track("campus_selection_completed", props: [
            "campus_id": selectedCampusId
        ])
        
        onComplete()
    }
    
    private func skipSelection() {
        // Default to UNT when skipping
        selectedCampusId = "UNT"
        hasCompletedCampusSelection = true
        
        // Track analytics
        AnalyticsService.shared.track("campus_selection_skipped", props: [:])
        
        onComplete()
    }
}

// MARK: - Campus Model

struct Campus: Identifiable {
    let id: String
    let name: String
    let shortName: String
    let location: String
    let coordinate: CLLocationCoordinate2D
    let isAvailable: Bool
}

// MARK: - Campus Row View

struct CampusRowView: View {
    let campus: Campus
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Campus icon
                ZStack {
                    Circle()
                        .fill(campus.isAvailable ? Color(hex: 0x02853E).opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Text("🏫")
                        .font(.system(size: 20))
                        .grayscale(campus.isAvailable ? 0 : 1)
                }
                
                // Campus info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(campus.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(campus.isAvailable ? .black : .gray)
                        
                        if !campus.isAvailable {
                            Text("Coming Soon")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.gray)
                                )
                        }
                    }
                    
                    Text(campus.location)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected && campus.isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: 0x02853E))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected && campus.isAvailable ? Color(hex: 0x02853E).opacity(0.1) : Color.white.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && campus.isAvailable ? Color(hex: 0x02853E) : Color.clear, lineWidth: 2)
            )
        }
        .disabled(!campus.isAvailable)
    }
}

#Preview {
    CampusSelectionView {
        print("Campus selection completed")
    }
}
