//
//  HostEventSheet.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import CoreLocation
import MapKit

enum TimeMode: String, CaseIterable, Identifiable {
    case now = "Now"
    case planAhead = "Plan Ahead"
    
    var id: String { rawValue }
}

struct PredefinedLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

let untLocations: [PredefinedLocation] = [
    PredefinedLocation(name: "University Union", coordinate: CLLocationCoordinate2D(latitude: 33.2098926, longitude: -97.1514762)),
    PredefinedLocation(name: "Willis Library", coordinate: CLLocationCoordinate2D(latitude: 33.210113, longitude: -97.148993)),
    PredefinedLocation(name: "Business Leadership Building", coordinate: CLLocationCoordinate2D(latitude: 33.2088910, longitude: -97.1476490)),
    PredefinedLocation(name: "Sage Hall", coordinate: CLLocationCoordinate2D(latitude: 33.210293, longitude: -97.151120)),
    PredefinedLocation(name: "DATCU Stadium", coordinate: CLLocationCoordinate2D(latitude: 33.197700, longitude: -97.151600)),
    PredefinedLocation(name: "Discovery Park", coordinate: CLLocationCoordinate2D(latitude: 33.248300, longitude: -97.152700)),
    PredefinedLocation(name: "The Syndicate", coordinate: CLLocationCoordinate2D(latitude: 33.209850, longitude: -97.151470)),
    PredefinedLocation(name: "Kerr Hall", coordinate: CLLocationCoordinate2D(latitude: 33.211200, longitude: -97.152300)),
    PredefinedLocation(name: "Joe Greene Hall", coordinate: CLLocationCoordinate2D(latitude: 33.211850, longitude: -97.153600)),
    PredefinedLocation(name: "Denton Square", coordinate: CLLocationCoordinate2D(latitude: 33.214400, longitude: -97.133100)),
    PredefinedLocation(name: "Clark Hall", coordinate: CLLocationCoordinate2D(latitude: 33.211900, longitude: -97.153900)),
    PredefinedLocation(name: "Rec Center", coordinate: CLLocationCoordinate2D(latitude: 33.209300, longitude: -97.152400)),
    PredefinedLocation(name: "UNT Music Building", coordinate: CLLocationCoordinate2D(latitude: 33.209000, longitude: -97.151100)),
    PredefinedLocation(name: "Art Building", coordinate: CLLocationCoordinate2D(latitude: 33.210200, longitude: -97.150600))
]

struct HostEventSheet: View {
    let defaultRegion: CampusRegion
    var onCreate: (CrowdEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var appEnv
    @EnvironmentObject var appState: AppState
    
    // Event details
    @State private var title: String = ""
    @State private var coord: CLLocationCoordinate2D
    @State private var locationName: String = ""
    @State private var category: EventCategory = .hangout
    @State private var timeMode: TimeMode = .now
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later
    
    // Location picker
    @State private var searchText: String = ""
    @State private var firestoreLocations: [PredefinedLocation] = []
    
    // AI description with typewriter effect
    @State private var aiDescription: String = ""
    @State private var displayedDescription: String = ""
    @State private var typewriterTask: Task<Void, Never>?

    init(defaultRegion: CampusRegion, onCreate: @escaping (CrowdEvent) -> Void) {
        self.defaultRegion = defaultRegion
        self.onCreate = onCreate
        _coord = State(initialValue: defaultRegion.spec.center)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. Host (First)
                Section("Host") {
                    HStack(spacing: 12) {
                        if let user = appState.sessionUser {
                            if let imageURL = user.profileImageURL, !imageURL.isEmpty {
                                // TODO: Load image from URL when Firebase Storage is integrated
                                AvatarView(
                                    name: user.displayName,
                                    color: user.avatarColor,
                                    size: 50
                                )
                            } else {
                                AvatarView(
                                    name: user.displayName,
                                    color: user.avatarColor,
                                    size: 50
                                )
                            }
                            Text(user.displayName)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 2. Title (Second)
                Section("Title") {
                    TextField("What's the vibe?", text: $title)
                        .font(.system(size: 18, weight: .medium))
                }
                
                // 3. Location (Third)
                Section("Location 📍") {
                    NavigationLink {
                        LocationPickerView(
                            locationName: $locationName,
                            coordinate: $coord,
                            searchText: $searchText,
                            onUseCurrentLocation: useCurrentLocation
                        )
                    } label: {
                        HStack {
                            Text(locationName.isEmpty ? "Current Location" : locationName)
                                .foregroundStyle(locationName.isEmpty ? .secondary : .primary)
                            Spacer()
                        }
                    }
                }
                
                // 4. When & Type (Fourth)
                Section {
                    HStack(spacing: 16) {
                        // Left: Time Mode
                        VStack(alignment: .leading, spacing: 4) {
                            Text("When")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $timeMode) {
                                ForEach(TimeMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right: Category
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Type")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $category) {
                                ForEach(EventCategory.allCases) { cat in
                                    Text(cat.displayName).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Show date pickers if planning ahead
                    if timeMode == .planAhead {
                        DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("Starting immediately")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 5. Description (Last - conditional generation)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $displayedDescription)
                            .frame(minHeight: 80)
                            .font(.system(size: 15))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Crowd is generating a description...")
                }
            }
            .navigationTitle("Start a Crowd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                // Only initialize location if user hasn't selected one yet
                if locationName.isEmpty {
                    initializeLocation()
                }
            }
            .onChange(of: title) { _, _ in
                debouncedGenerateDescription()
            }
            .onChange(of: category) { _, _ in
                generateDescription()
            }
            .onChange(of: timeMode) { _, _ in
                generateDescription()
            }
            .onChange(of: startDate) { _, _ in
                if timeMode == .planAhead {
                    generateDescription()
                }
            }
            .onChange(of: locationName) { _, _ in
                generateDescription()
            }
        }
    }
    
    // MARK: - Location Initialization
    
    private func initializeLocation() {
        // Request location permissions and start updating
        appEnv.location.requestSoftAuth()
        
        // Try to use current location from LocationService
        if let currentLocation = appEnv.location.lastKnown {
            coord = currentLocation
            reverseGeocodeLocation(currentLocation)
        } else {
            // Fallback: use default region center with "Current Location" as default
            coord = defaultRegion.spec.center
            locationName = "" // Leave empty to show "Current Location" placeholder
        }
    }
    
    private func useCurrentLocation() {
        // Ensure location service is active
        appEnv.location.requestSoftAuth()
        
        // Use current location if available
        if let currentLocation = appEnv.location.lastKnown {
            coord = currentLocation
            reverseGeocodeLocation(currentLocation)
        } else {
            // Show a placeholder while waiting for location
            locationName = "Getting location..."
            
            // Try again after a short delay to give LocationService time to update
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
        // Create MKLocalSearch request to reverse geocode the coordinate
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "\(coordinate.latitude),\(coordinate.longitude)"
        searchRequest.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 100,
            longitudinalMeters: 100
        )
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response,
                  let item = response.mapItems.first,
                  let placemark = item.placemark as MKPlacemark? else {
                locationName = "Current Location"
                return
            }
            
            // Build location name from placemark
            if let name = placemark.name {
                locationName = name
            } else if let thoroughfare = placemark.thoroughfare {
                locationName = thoroughfare
            } else if let locality = placemark.locality {
                locationName = locality
            } else {
                locationName = "Current Location"
            }
        }
    }
    
    // MARK: - Description Generation
    
    private func generateDescription() {
        // Only generate if title is not empty
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            displayedDescription = ""
            return
        }
        
        // Cancel any existing typewriter animation
        typewriterTask?.cancel()
        
        // Generate the description text
        let location = locationName.isEmpty ? "Current Location" : locationName
        let timeText: String
        
        if timeMode == .now {
            timeText = "Starting now"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timeText = "Starting \(formatter.string(from: startDate))"
        }
        
        // Format with emojis and bullet points
        aiDescription = """
        📍 \(location)
        ⏰ \(timeText)
        \(category.emoji) \(title)
        """
        
        // Start typewriter effect
        displayedDescription = ""
        typewriterTask = Task {
            await animateTypewriter()
        }
    }
    
    private func debouncedGenerateDescription() {
        // Cancel previous task
        typewriterTask?.cancel()
        
        // Wait 500ms before regenerating
        typewriterTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    generateDescription()
                }
            }
        }
    }
    
    private func animateTypewriter() async {
        let characters = Array(aiDescription)
        for (index, _) in characters.enumerated() {
            if Task.isCancelled { break }
            
            await MainActor.run {
                displayedDescription = String(characters[0...index])
            }
            
            // Randomize typing speed slightly for more natural feel
            let delay = UInt64.random(in: 20_000_000...40_000_000) // 20-40ms
            try? await Task.sleep(nanoseconds: delay)
        }
    }
    
    // MARK: - Create Event
    
    private func createEvent() {
        let finalStartsAt: Date?
        let finalEndsAt: Date?
        
        if timeMode == .now {
            finalStartsAt = Date()
            finalEndsAt = Date().addingTimeInterval(7200) // 2 hours default
        } else {
            finalStartsAt = startDate
            finalEndsAt = endDate
        }
        
        let event = CrowdEvent.newDraft(
            at: coord,
            title: title.isEmpty ? "Crowd" : title,
            hostId: appState.sessionUser?.id ?? "anon",
            hostName: appState.sessionUser?.displayName ?? "Guest",
            category: category.rawValue,
            description: displayedDescription,
            startsAt: finalStartsAt,
            endsAt: finalEndsAt
        )
        
        onCreate(event)
        dismiss()
    }
}

// MARK: - Location Picker View

struct LocationPickerView: View {
    @Binding var locationName: String
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var searchText: String
    var onUseCurrentLocation: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var allLocations: [PredefinedLocation] {
        // Combine UNT locations with any Firestore locations in the future
        untLocations
    }
    
    var filteredLocations: [PredefinedLocation] {
        if searchText.isEmpty {
            return allLocations
        } else {
            return allLocations.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            // Predefined UNT Locations
            ForEach(filteredLocations) { location in
                Button {
                    locationName = location.name
                    coordinate = location.coordinate
                    searchText = ""
                    dismiss()
                } label: {
                    HStack {
                        Text(location.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if locationName == location.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            
            // Custom location option
            if !searchText.isEmpty && !filteredLocations.contains(where: { $0.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame }) {
                Button {
                    locationName = searchText
                    // Keep current coordinate or use a default
                    searchText = ""
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Use \"\(searchText)\"")
                            .foregroundStyle(.primary)
                    }
                }
            }
            
            // Use Current Location option
            Section {
                Button {
                    onUseCurrentLocation()
                    searchText = ""
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        Text("Use Current Location")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search locations")
    }
}
