//
//  HostEventSheet.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import CoreLocation
import MapKit
import ComponentsKit
import UIKit

enum TimeMode: String, CaseIterable, Identifiable {
    case now = "Now"
    case planAhead = "Plan Ahead"
    
    var id: String { rawValue }
}

struct PredefinedLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let searchOverride: String? // Optional Apple Maps search query override
}

let untLocations: [PredefinedLocation] = [
    PredefinedLocation(name: "University Union", coordinate: CLLocationCoordinate2D(latitude: 33.2098926, longitude: -97.1514762), searchOverride: nil),
    PredefinedLocation(name: "University Union – Main Floor", coordinate: CLLocationCoordinate2D(latitude: 33.2098926, longitude: -97.1514762), searchOverride: nil),
    PredefinedLocation(name: "Union Main Floor", coordinate: CLLocationCoordinate2D(latitude: 33.2106138, longitude: -97.1473253), searchOverride: nil),
    PredefinedLocation(name: "Willis Library", coordinate: CLLocationCoordinate2D(latitude: 33.210113, longitude: -97.1489542), searchOverride: nil),
    PredefinedLocation(name: "Business Leadership Building", coordinate: CLLocationCoordinate2D(latitude: 33.2088579, longitude: -97.147729), searchOverride: nil),
    PredefinedLocation(name: "Sage Hall", coordinate: CLLocationCoordinate2D(latitude: 33.212014, longitude: -97.1467232), searchOverride: nil),
    PredefinedLocation(name: "DATCU Stadium", coordinate: CLLocationCoordinate2D(latitude: 33.2039355, longitude: -97.1592403), searchOverride: nil),
    PredefinedLocation(name: "Discovery Park", coordinate: CLLocationCoordinate2D(latitude: 33.25331, longitude: -97.1544), searchOverride: nil),
    PredefinedLocation(name: "The Syndicate", coordinate: CLLocationCoordinate2D(latitude: 33.2107832, longitude: -97.1477704), searchOverride: nil),
    PredefinedLocation(name: "Kerr Hall", coordinate: CLLocationCoordinate2D(latitude: 33.20771, longitude: -97.14754), searchOverride: nil),
    PredefinedLocation(name: "Joe Greene Hall", coordinate: CLLocationCoordinate2D(latitude: 33.2069554, longitude: -97.1462809), searchOverride: nil),
    PredefinedLocation(name: "Denton Square", coordinate: CLLocationCoordinate2D(latitude: 33.2150434, longitude: -97.1330684), searchOverride: nil),
    // PredefinedLocation(name: "Clark Hall", coordinate: CLLocationCoordinate2D(latitude: 33.20779, longitude: -97.15143), searchOverride: "Clark Hall"),
    PredefinedLocation(name: "Pohl Recreation Center", coordinate: CLLocationCoordinate2D(latitude: 33.21207, longitude: -97.15404), searchOverride: nil),
    PredefinedLocation(name: "Eagle Landing Dining Hall", coordinate: CLLocationCoordinate2D(latitude: 33.208596, longitude: -97.146741), searchOverride: nil),
    PredefinedLocation(name: "UNT Music Building", coordinate: CLLocationCoordinate2D(latitude: 33.2106644, longitude: -97.1501177), searchOverride: nil),
    PredefinedLocation(name: "Art Building", coordinate: CLLocationCoordinate2D(latitude: 33.2131446, longitude: -97.1454504), searchOverride: nil),
    PredefinedLocation(name: "Chestnut Hall", coordinate: CLLocationCoordinate2D(latitude: 33.21222, longitude: -97.15255), searchOverride: nil),
    PredefinedLocation(name: "Super PIT (UNT Coliseum)", coordinate: CLLocationCoordinate2D(latitude: 33.208611, longitude: -97.154167), searchOverride: nil),
    // PredefinedLocation(name: "Fry Street", coordinate: CLLocationCoordinate2D(latitude: 33.21455, longitude: -97.13347), searchOverride: "Avenue A")
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
    @State private var selectedLocationId: String? = "Current Location"
    @State private var category: EventCategory = .other
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
    
    // Confetti celebration
    @State private var showConfetti = false

    init(defaultRegion: CampusRegion, initialTitle: String? = nil, onCreate: @escaping (CrowdEvent) -> Void) {
        self.defaultRegion = defaultRegion
        self.onCreate = onCreate
        _coord = State(initialValue: defaultRegion.spec.center)
        if let initialTitle = initialTitle {
            _title = State(initialValue: initialTitle)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hostCard
                    titleCard
                    locationCard
                    timeAndTypeCard
                    descriptionCard
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Start a Crowd")
            .navigationBarTitleDisplayMode(.inline)
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
                    selectedLocationId = nil // No dropdown selection, will show "Current Location" text
                } else if !locationName.isEmpty {
                    selectedLocationId = locationName
                } else {
                    selectedLocationId = nil // No dropdown selection, will show "Current Location" text
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
            .onChange(of: locationName) { oldValue, newValue in
                print("📝 locationName changed from '\(oldValue)' to '\(newValue)'")
                print("📝 Current coord: lat=\(coord.latitude), lon=\(coord.longitude)")
                // Sync dropdown selection
                if !newValue.isEmpty && newValue != "Current Location" {
                    selectedLocationId = newValue
                } else if newValue.isEmpty {
                    selectedLocationId = nil // Show "Current Location" text below
                }
                generateDescription()
            }
        }
        .overlay(
            Group {
                if showConfetti {
                    ConfettiOverlay()
                        .allowsHitTesting(false)
                }
            }
        )
    }
    
    // MARK: - Location Initialization
    
    private func initializeLocation() {
        print("🏁 initializeLocation() called")
        // Request location permissions and start updating
        appEnv.location.requestSoftAuth()
        
        // Try to use current location from LocationService
        if let currentLocation = appEnv.location.lastKnown {
            coord = currentLocation
            print("🏁 Set coord to GPS location: lat=\(currentLocation.latitude), lon=\(currentLocation.longitude)")
            reverseGeocodeLocation(currentLocation)
        } else {
            // Fallback: use default region center with "Current Location" as default
            coord = defaultRegion.spec.center
            locationName = "" // Leave empty to show "Current Location" placeholder
            print("🏁 No GPS, set coord to region center: lat=\(coord.latitude), lon=\(coord.longitude)")
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
        // Move reverse geocoding to background queue
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
        
        // Wait 500ms before regenerating (increased debounce for better performance)
        typewriterTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    generateDescription()
                }
            }
        }
    }
    
    private func animateTypewriter() async {
        let characters = Array(aiDescription)
        // Batch updates: update every 3 characters instead of every character for better performance
        let batchSize = 3
        var currentIndex = 0
        
        while currentIndex < characters.count && !Task.isCancelled {
            let endIndex = min(currentIndex + batchSize, characters.count)
            let text = String(characters[0..<endIndex])
            
            await MainActor.run {
                displayedDescription = text
            }
            
            currentIndex = endIndex
            
            // Slightly faster batch updates (30-50ms per batch)
            let delay = UInt64.random(in: 30_000_000...50_000_000)
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
        
        // Debug: Print coordinate BEFORE creating event
        print("🔍 BEFORE createEvent - coord: lat=\(coord.latitude), lon=\(coord.longitude)")
        print("🔍 BEFORE createEvent - locationName: '\(locationName)'")
        print("🔍 BEFORE createEvent - sessionUser: \(appState.sessionUser?.displayName ?? "nil"), id: \(appState.sessionUser?.id ?? "nil")")
        
        // Generate tags from category (ensures emoji is preserved)
        let tags = [category.defaultTag]
        
        let event = CrowdEvent.newDraft(
            at: coord,
            title: title.isEmpty ? "Crowd" : title,
            hostId: appState.sessionUser?.id ?? "anon",
            hostName: appState.sessionUser?.displayName ?? "Guest",
            category: category.rawValue,
            description: displayedDescription,
            startsAt: finalStartsAt,
            endsAt: finalEndsAt,
            tags: tags
        )
        
        // Debug: Print event details
        print("🎯 Creating event '\(event.title)' at location: \(locationName)")
        print("🎯 Event coordinates: lat=\(event.latitude), lon=\(event.longitude)")
        print("🎯 Event tags: \(event.tags), category: \(event.category ?? "nil")")
        print("🎯 Expected (The Syndicate): lat=33.209850, lon=-97.151470")
        
        // Trigger celebration effects immediately
        showConfetti = true
        
        // Strong haptic representing people screaming and yelling
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        // Additional strong impact haptic for extra intensity
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactGenerator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactGenerator.impactOccurred()
        }
        
        // Second impact for layered effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactGenerator.impactOccurred(intensity: 0.8)
        }
        
        // Hide confetti after short duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showConfetti = false
        }
        
        // Call onCreate callback
        onCreate(event)
        
        // Dismiss after a short delay to allow confetti to show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    // MARK: - Card Sections
    
    private var cardModel: CardVM {
        CardVM {
            $0.cornerRadius = .medium
            $0.shadow = .medium
            $0.backgroundColor = .background
            $0.borderWidth = .medium
        }
    }
    
    private var hostCard: some View {
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Host")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    if let user = appState.sessionUser {
                        let _ = print("🔍 HostEventSheet - sessionUser: \(user.displayName), id: \(user.id), isAnonymous: \(user.id == "anon")")
                        Group {
                            if let profileImageURL = user.profileImageURL, !profileImageURL.isEmpty {
                                AsyncImage(url: URL(string: profileImageURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    AvatarView(
                                        name: user.displayName,
                                        color: user.avatarColor,
                                        size: 50
                                    )
                                }
                            } else {
                                AvatarView(
                                    name: user.displayName,
                                    color: user.avatarColor,
                                    size: 50
                                )
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if let handle = user.handle, !handle.isEmpty {
                                Text(handle)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let campus = user.campus, !campus.isEmpty {
                                Text(campus)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    } else {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                            
                            Text("Loading...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var titleCard: some View {
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Title")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                TextField("What's the vibe?", text: $title)
                    .font(.system(size: 18, weight: .medium))
            }
        }
    }
    
    private var locationCard: some View {
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a location 📍")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Menu {
                    Button {
                        selectedLocationId = nil
                        locationName = ""
                        useCurrentLocation()
                    } label: {
                        Text("📍 Current Location")
                    }
                    
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
                    HStack {
                        // Placeholder/selected location text
                        if locationName.isEmpty || selectedLocationId == nil {
                            Text("📍 Current Location")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        } else if let locationId = selectedLocationId, let selectedLocation = untLocations.first(where: { $0.name == locationId }) {
                            Text(selectedLocation.name)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        } else if !locationName.isEmpty {
                            Text(locationName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x02853E))
                    }
                }
            }
        }
    }
    
    private func searchLocationOnAppleMaps(locationName: String) async -> CLLocationCoordinate2D? {
        let searchRequest = MKLocalSearch.Request()
        let query = locationName.contains("DATCU") || locationName.contains("Stadium") || locationName.contains("Square")
            ? "\(locationName), Denton, TX"
            : "\(locationName), UNT, Denton, TX 76203"
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.210081, longitude: -97.147700),
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else {
                return nil
            }
            return mapItem.placemark.coordinate
        } catch {
            return nil
        }
    }
    
    private var timeAndTypeCard: some View {
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $timeMode) {
                        ForEach(TimeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Type")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $category) {
                        ForEach(EventCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(Color(hex: 0x02853E))
                }
                
                if timeMode == .planAhead {
                    DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                } else {
                    Text("Starting immediately")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var descriptionCard: some View {
        SUCard(model: cardModel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Crowd is generating a description...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $displayedDescription)
                    .frame(minHeight: 80)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Location Picker View

struct LocationPickerView: View {
    @Binding var locationName: String
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var searchText: String
    var onUseCurrentLocation: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    
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
    
    // MARK: - Apple Maps Geocoding
    
    private func searchLocationOnAppleMaps(locationName: String) async -> CLLocationCoordinate2D? {
        print("🔍 Searching Apple Maps for: \(locationName)")
        
        let searchRequest = MKLocalSearch.Request()
        // More specific query with "UNT" prefix for campus buildings
        let query = locationName.contains("DATCU") || locationName.contains("Stadium") || locationName.contains("Square")
            ? "\(locationName), Denton, TX"
            : "\(locationName), UNT, Denton, TX 76203"
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.210081, longitude: -97.147700),
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else {
                print("❌ No results for: \(locationName)")
                return nil
            }
            
            let coordinate = mapItem.placemark.coordinate
            print("✅ Found: \(mapItem.name ?? "Unknown") at lat=\(coordinate.latitude), lon=\(coordinate.longitude)")
            return coordinate
        } catch {
            print("❌ Search error: \(error.localizedDescription)")
            return nil
        }
    }
    
    var body: some View {
        List {
            // Predefined UNT Locations
            ForEach(filteredLocations) { location in
                Button {
                    Task {
                        isSearching = true
                        locationName = location.name
                        
                        // Search Apple Maps for accurate coordinates (with optional override)
                        let query = location.searchOverride ?? location.name
                        if let coord = await searchLocationOnAppleMaps(locationName: query) {
                            coordinate = coord
                        } else {
                            // Fallback to hardcoded if search fails
                            coordinate = location.coordinate
                        }
                        
                        isSearching = false
                        searchText = ""
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(location.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if isSearching {
                            ProgressView()
                        } else if locationName == location.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .disabled(isSearching)
            }
            
            // Custom location option
            if !searchText.isEmpty && !filteredLocations.contains(where: { $0.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame }) {
                Button {
                    Task {
                        isSearching = true
                        let customName = searchText
                        locationName = customName
                        
                        if let coord = await searchLocationOnAppleMaps(locationName: customName) {
                            coordinate = coord
                        } else {
                            print("⚠️ Could not find coordinates for custom location")
                            // Keep existing coordinate (current location or region center)
                        }
                        
                        isSearching = false
                        searchText = ""
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Use \"\(searchText)\"")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isSearching {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSearching)
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

// MARK: - Confetti Overlay
struct ConfettiOverlay: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<30, id: \.self) { index in
                    ConfettiPiece()
                        .offset(
                            x: animate ? CGFloat.random(in: -geometry.size.width/2...geometry.size.width/2) : 0,
                            y: animate ? -geometry.size.height/2 - CGFloat.random(in: 100...300) : 0
                        )
                        .opacity(animate ? 0 : 1)
                        .scaleEffect(animate ? CGFloat.random(in: 0.5...1.2) : 0.1)
                        .rotationEffect(.degrees(animate ? Double.random(in: 0...360) : 0))
                        .animation(
                            .easeOut(duration: Double.random(in: 1.5...3.5))
                            .delay(Double.random(in: 0...0.8)),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.1)) {
                animate = true
            }
        }
    }
}

struct ConfettiPiece: View {
    let colors = [Color.red, Color.blue, Color.green, Color.yellow, Color.pink, Color.purple, Color.orange, Color.cyan, Color.mint, Color.indigo]
    let shapes = ["circle", "square", "triangle", "star"]
    @State private var shape: String
    
    init() {
        self.shape = shapes.randomElement() ?? "circle"
    }
    
    var body: some View {
        Group {
            switch shape {
            case "circle":
                Circle()
                    .fill(colors.randomElement() ?? .blue)
            case "square":
                Rectangle()
                    .fill(colors.randomElement() ?? .blue)
            case "triangle":
                Triangle()
                    .fill(colors.randomElement() ?? .blue)
            case "star":
                Star()
                    .fill(colors.randomElement() ?? .blue)
            default:
                Circle()
                    .fill(colors.randomElement() ?? .blue)
            }
        }
        .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
    }
}

// MARK: - Custom Shapes
struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}