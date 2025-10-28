//
//  CalenderView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/23/25.
//

import SwiftUI
import CoreLocation

struct CalenderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var upcoming: [CrowdEvent] = []
    @State private var selectedIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)
                            .padding(.top, 16)

                        ForEach(upcoming) { event in
                            Button {
                                if selectedIds.contains(event.id) { selectedIds.remove(event.id) }
                                else { selectedIds.insert(event.id) }
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIds.contains(event.id) ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Image(systemName: "calendar")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(.primary)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if let when = event.startsAt {
                                            Text(when, style: .date)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: selectedIds.contains(event.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedIds.contains(event.id) ? Color.accentColor : .secondary)
                                }
                                .padding(12)
                                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }

                // Save FAB
                Button {
                    let selected = upcoming.filter { selectedIds.contains($0.id) }
                    appState.attendingEvents.append(contentsOf: selected.filter { ev in !appState.attendingEvents.contains(ev) })
                    selectedIds.removeAll()
                } label: {
                    ZStack {
                        Circle().fill(Color(hex: 0x02853E))
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear { seedMockEvents() }
        }
    }

    private func seedMockEvents() {
        guard upcoming.isEmpty else { return }
        let now = Date()
        let coords = CLLocationCoordinate2D(latitude: 33.210081, longitude: -97.147700)
        upcoming = [
            CrowdEvent.newDraft(at: coords, title: "Study Jam @ Willis", startsAt: now.addingTimeInterval(3600), endsAt: now.addingTimeInterval(7200), tags: ["study"]).withId("mock-1"),
            CrowdEvent.newDraft(at: coords, title: "Hoops Night", startsAt: now.addingTimeInterval(10800), endsAt: now.addingTimeInterval(14400), tags: ["sports"]).withId("mock-2"),
            CrowdEvent.newDraft(at: coords, title: "Open Mic", startsAt: now.addingTimeInterval(21600), endsAt: now.addingTimeInterval(25200), tags: ["music"]).withId("mock-3")
        ]
    }
}

#Preview {
    CalenderView()
}
