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

struct HostEventSheet: View {
    let defaultRegion: CampusRegion
    var onCreate: (CrowdEvent) -> Void

    @Environment(\.dismiss) private var dismiss
<<<<<<< Updated upstream
    @Environment(\.appEnvironment) private var appEnv
=======
>>>>>>> Stashed changes
    @EnvironmentObject var appState: AppState
    
    // Event details
    @State private var title: String = ""
    @State private var coord: CLLocationCoordinate2D
<<<<<<< Updated upstream
    @State private var locationName: String = ""
=======
>>>>>>> Stashed changes
    @State private var category: EventCategory = .hangout
    @State private var timeMode: TimeMode = .now
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later
    
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
<<<<<<< Updated upstream
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
                
                // 2. When & Type (Second)
=======
                // 1. Title Field
                Section {
                    TextField("What's the vibe?", text: $title)
                        .font(.system(size: 18, weight: .medium))
                }
                
                // 2. Host Name (read-only)
                Section {
                    HStack {
                        Text("Host:")
                            .foregroundStyle(.secondary)
                        Text(appState.sessionUser?.displayName ?? "Guest")
                            .foregroundStyle(.gray)
                    }
                }
                
                // 3. Time & Event Type Row (horizontal)
>>>>>>> Stashed changes
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
                
<<<<<<< Updated upstream
                // 3. Location (Third)
                Section("Location") {
                    LocationSearchField(
                        locationName: $locationName,
                        coordinate: $coord,
                        onUseCurrentLocation: useCurrentLocation
                    )
                }
                
                // 4. Title (Fourth)
                Section("Title") {
                    TextField("What's the vibe?", text: $title)
                        .font(.system(size: 18, weight: .medium))
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
=======
                // 4. AI-Generated Description (with typewriter effect)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $displayedDescription)
                            .frame(minHeight: 80)
                            .font(.system(size: 15))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("AI-Generated (editable)")
                }
                
                // 5. Location
                Section("Location") {
                    Text("Lat: \(coord.latitude, specifier: "%.6f")  Lng: \(coord.longitude, specifier: "%.6f")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    // TODO: add "Use current location" with LocationService
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
                initializeLocation()
=======
                generateDescription()
>>>>>>> Stashed changes
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
            // Fallback: use default region and set a generic name
            coord = defaultRegion.spec.center
            locationName = "Current Location"
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
    
    // MARK: - AI Description Generation
    
    private func generateDescription() {
        // Cancel any existing typewriter animation
        typewriterTask?.cancel()
        
        // Generate the description text
        let locationName = "Main Campus" // TODO: Get actual location name
        let timeText: String
        
        if timeMode == .now {
            timeText = "Starting now"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            timeText = "Starting \(formatter.string(from: startDate))"
        }
        
        let vibeText = title.isEmpty ? "Join the crowd" : title
        
        // Format with emojis and bullet points
        aiDescription = """
        📍 \(locationName)
        ⏰ \(timeText)
        \(category.emoji) \(vibeText)
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
