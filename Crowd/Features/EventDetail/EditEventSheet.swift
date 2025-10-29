//
//  EditEventSheet.swift
//  Crowd
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct EditEventSheet: View {
    let event: CrowdEvent
    var onSave: (CrowdEvent) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var appEnv
    @EnvironmentObject var appState: AppState
    
    // Event details - pre-populated from existing event
    @State private var title: String
    @State private var coord: CLLocationCoordinate2D
    @State private var locationName: String
    @State private var category: EventCategory
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var eventDescription: String
    
    // Location picker
    @State private var searchText: String = ""
    
    // UI state
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(event: CrowdEvent, onSave: @escaping (CrowdEvent) -> Void) {
        self.event = event
        self.onSave = onSave
        
        // Pre-populate fields with existing event data
        _title = State(initialValue: event.title)
        _coord = State(initialValue: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude))
        _locationName = State(initialValue: "") // Will be geocoded or set from event
        _category = State(initialValue: EventCategory(rawValue: event.category ?? EventCategory.other.rawValue) ?? .other)
        _startDate = State(initialValue: event.startsAt ?? Date())
        _endDate = State(initialValue: event.endsAt ?? Date().addingTimeInterval(3600))
        _eventDescription = State(initialValue: event.description ?? "")
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
            .navigationTitle("Edit Crowd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        ProgressView("Saving changes...")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Save Event
    
    private func saveEvent() {
        isSaving = true
        
        Task {
            do {
                // Prepare updates dictionary
                var updates: [String: Any] = [
                    "title": title.isEmpty ? "Crowd" : title,
                    "latitude": coord.latitude,
                    "longitude": coord.longitude,
                    "category": category.rawValue,
                    "description": eventDescription,
                    "startsAt": startDate.timeIntervalSince1970,
                    "endsAt": endDate.timeIntervalSince1970
                ]
                
                print("🔍 Updating event with updates: \(updates)")
                
                // Call repository to update event
                try await appEnv.eventRepo.updateEvent(eventId: event.id, updates: updates)
                
                print("✅ Event updated successfully!")
                
                // Create updated event object for callback
                var updatedEvent = event
                updatedEvent.title = title
                updatedEvent.latitude = coord.latitude
                updatedEvent.longitude = coord.longitude
                updatedEvent.category = category.rawValue
                updatedEvent.description = eventDescription
                updatedEvent.startsAt = startDate
                updatedEvent.endsAt = endDate
                
                await MainActor.run {
                    isSaving = false
                    onSave(updatedEvent)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to update event: \(error.localizedDescription)"
                    showError = true
                }
                print("❌ Error updating event: \(error)")
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var hostSection: some View {
        Section("Host") {
            HStack(spacing: 12) {
                if let user = appState.sessionUser {
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
        Section("Location 📍") {
            NavigationLink {
                EditLocationPickerView(
                    locationName: $locationName,
                    coordinate: $coord,
                    searchText: $searchText
                )
            } label: {
                HStack {
                    Text(locationName.isEmpty ? "Event Location" : locationName)
                        .foregroundStyle(locationName.isEmpty ? .secondary : .primary)
                    Spacer()
                }
            }
        }
    }
    
    private var timeAndTypeSection: some View {
        Section {
            HStack(spacing: 16) {
                // Category
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
            
            DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
            DatePicker("End Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
        }
    }
    
    private var descriptionSection: some View {
        Section("Description") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $eventDescription)
                    .frame(minHeight: 80)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Edit Location Picker View

struct EditLocationPickerView: View {
    @Binding var locationName: String
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var searchText: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    
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
        PredefinedLocation(name: "Super PIT (UNT Coliseum)", coordinate: CLLocationCoordinate2D(latitude: 33.208611, longitude: -97.154167))
    ]
    
    var filteredLocations: [PredefinedLocation] {
        if searchText.isEmpty {
            return untLocations
        } else {
            return untLocations.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func searchLocationOnAppleMaps(locationName: String) async -> CLLocationCoordinate2D? {
        print("🔍 Searching Apple Maps for: \(locationName)")
        
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
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search locations")
    }
}

#Preview {
    EditEventSheet(
        event: CrowdEvent(
            id: "test",
            title: "Test Event",
            hostId: "host1",
            hostName: "Test Host",
            latitude: 33.210,
            longitude: -97.150,
            radiusMeters: 100,
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            createdAt: Date(),
            signalStrength: 5,
            attendeeCount: 10,
            tags: ["test"],
            category: EventCategory.other.rawValue,
            description: "Test description"
        )
    ) { _ in
        print("Event saved")
    }
    .environmentObject(AppState())
}

