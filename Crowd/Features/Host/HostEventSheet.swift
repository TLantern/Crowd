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
    PredefinedLocation(name: "Willis Library", coordinate: CLLocationCoordinate2D(latitude: 33.210113, longitude: -97.1489542)),
    PredefinedLocation(name: "Business Leadership Building", coordinate: CLLocationCoordinate2D(latitude: 33.2088579, longitude: -97.147729)),
    PredefinedLocation(name: "Sage Hall", coordinate: CLLocationCoordinate2D(latitude: 33.212014, longitude: -97.1467232)),
    PredefinedLocation(name: "DATCU Stadium", coordinate: CLLocationCoordinate2D(latitude: 33.2039355, longitude: -97.1592403)),
    PredefinedLocation(name: "Discovery Park", coordinate: CLLocationCoordinate2D(latitude: 33.25331, longitude: -97.1544)),
    PredefinedLocation(name: "The Syndicate", coordinate: CLLocationCoordinate2D(latitude: 33.2107832, longitude: -97.1477704)),
    PredefinedLocation(name: "Kerr Hall", coordinate: CLLocationCoordinate2D(latitude: 33.20771, longitude: -97.14754)),
    PredefinedLocation(name: "Joe Greene Hall", coordinate: CLLocationCoordinate2D(latitude: 33.2069554, longitude: -97.1462809)),
    PredefinedLocation(name: "Denton Square", coordinate: CLLocationCoordinate2D(latitude: 33.2150434, longitude: -97.1330684)),
    PredefinedLocation(name: "Clark Hall", coordinate: CLLocationCoordinate2D(latitude: 33.20779, longitude: -97.15143)),
    PredefinedLocation(name: "Pohl Recreation Center", coordinate: CLLocationCoordinate2D(latitude: 33.21207, longitude: -97.15404)),
    PredefinedLocation(name: "UNT Music Building", coordinate: CLLocationCoordinate2D(latitude: 33.2106644, longitude: -97.1501177)),
    PredefinedLocation(name: "Art Building", coordinate: CLLocationCoordinate2D(latitude: 33.2131446, longitude: -97.1454504)),
    PredefinedLocation(name: "Chestnut Hall", coordinate: CLLocationCoordinate2D(latitude: 33.21222, longitude: -97.15255)),
    PredefinedLocation(name: "Super PIT (UNT Coliseum)", coordinate: CLLocationCoordinate2D(latitude: 33.208611, longitude: -97.154167))
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

    init(defaultRegion: CampusRegion, onCreate: @escaping (CrowdEvent) -> Void) {
        self.defaultRegion = defaultRegion
        self.onCreate = onCreate
        _coord = State(initialValue: defaultRegion.spec.center)
    }

    var body: some View {
        NavigationStack {
            Form {
                hostSection
                titleSection
                locationSection
                timeAndTypeSection
                descriptionSection
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
            .onChange(of: locationName) { oldValue, newValue in
                print("📝 locationName changed from '\(oldValue)' to '\(newValue)'")
                print("📝 Current coord: lat=\(coord.latitude), lon=\(coord.longitude)")
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
        
        // Debug: Print coordinate BEFORE creating event
        print("🔍 BEFORE createEvent - coord: lat=\(coord.latitude), lon=\(coord.longitude)")
        print("🔍 BEFORE createEvent - locationName: '\(locationName)'")
        print("🔍 BEFORE createEvent - sessionUser: \(appState.sessionUser?.displayName ?? "nil"), id: \(appState.sessionUser?.id ?? "nil")")
        
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
        
        // Debug: Print event details
        print("🎯 Creating event '\(event.title)' at location: \(locationName)")
        print("🎯 Event coordinates: lat=\(event.latitude), lon=\(event.longitude)")
        print("🎯 Expected (The Syndicate): lat=33.209850, lon=-97.151470")
        
        // Trigger celebration effects
        showConfetti = true
        Haptics.success() // Light vibration
        
        // Call onCreate callback
        onCreate(event)
        
        // Dismiss after a short delay to allow confetti to show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    // MARK: - Form Sections
    
    private var hostSection: some View {
        Section("Host") {
            HStack(spacing: 12) {
                if let user = appState.sessionUser {
                    // Debug logging
                    let _ = print("🔍 HostEventSheet - sessionUser: \(user.displayName), id: \(user.id), isAnonymous: \(user.id == "anon")")
                    // Profile image or avatar
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
                    // Fallback for when user is not loaded
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
            .padding(.vertical, 4)
        }
    }
    
    private var titleSection: some View {
        Section("Title") {
            TextField("What's the vibe?", text: $title)
                .font(.system(size: 18, weight: .medium))
        }
    }
    
    private var locationSection: some View {
        Section("Choose a location 📍") {
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
    }
    
    private var timeAndTypeSection: some View {
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
                    Text("Event Type")
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
    }
    
    private var descriptionSection: some View {
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
                        
                        // Search Apple Maps for accurate coordinates
                        if let coord = await searchLocationOnAppleMaps(locationName: location.name) {
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
                ForEach(0..<60, id: \.self) { index in
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