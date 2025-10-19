//
//  HostEventSheet.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import CoreLocation

struct HostEventSheet: View {
    let defaultRegion: CampusRegion
    var onCreate: (CrowdEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var coord: CLLocationCoordinate2D

    init(defaultRegion: CampusRegion, onCreate: @escaping (CrowdEvent) -> Void) {
        self.defaultRegion = defaultRegion
        self.onCreate = onCreate
        _coord = State(initialValue: defaultRegion.spec.center) // seed from region
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("What’s the vibe? (short)", text: $title)
                }
                Section("Location") {
                    Text("Lat: \(coord.latitude, specifier: "%.6f")  Lng: \(coord.longitude, specifier: "%.6f")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    // TODO: add “Use current location” with LocationService
                }
            }
            .navigationTitle("Start a Crowd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let event = CrowdEvent.newDraft(at: coord, title: title.isEmpty ? "Crowd" : title)
                        onCreate(event)
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
