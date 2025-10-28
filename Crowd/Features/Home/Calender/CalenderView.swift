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
    @StateObject private var campusEventsVM = CampusEventsViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var selectedInterests: Set<Interest> = []
    
    // Filtered events based on selected interests
    var filteredEvents: [CrowdEvent] {
        print("🔍 CalenderView: Filtering events - Total: \(campusEventsVM.crowdEvents.count), Selected interests: \(selectedInterests.count)")
        
        if selectedInterests.isEmpty {
            print("🔍 CalenderView: No interests selected, returning all \(campusEventsVM.crowdEvents.count) events")
            return campusEventsVM.crowdEvents
        }
        
        let filtered = campusEventsVM.crowdEvents.filter { event in
            // Check if any of the event's tags match any selected interest
            let eventTags = Set(event.tags.map { $0.lowercased() })
            let selectedInterestNames = Set(selectedInterests.map { $0.name.lowercased() })
            
            let matches = !eventTags.isDisjoint(with: selectedInterestNames)
            print("🔍 CalenderView: Event '\(event.title)' - Tags: \(event.tags), Matches: \(matches)")
            return matches
        }
        
        print("🔍 CalenderView: Filtered to \(filtered.count) events")
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upcoming Events")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("Live campus events from Instagram & official sources")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        InterestFilterDropdown(selectedInterests: $selectedInterests)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Events List
                if filteredEvents.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.5))
                        
                        Text(selectedInterests.isEmpty ? "No upcoming events" : "No events match your interests")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text(selectedInterests.isEmpty ? "Check back later for new campus events" : "Try selecting different interests or clear the filter")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredEvents) { event in
                                EventCardView(event: event)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
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
            .onAppear {
                campusEventsVM.start()
                // Refresh attended events to clean up expired ones
                AttendedEventsService.shared.refreshAttendedEvents()
                // Add sample campus events for testing
                addSampleCampusEvents()
            }
            .onDisappear {
                campusEventsVM.stop()
            }
        }
    }
    
    private func addSampleCampusEvents() {
        Task {
            do {
                let functions = FirebaseManager.shared.functions
                let result = try await functions.httpsCallable("addSampleCampusEvents").call()
                print("✅ Sample campus events added: \(result.data)")
            } catch {
                print("❌ Failed to add sample campus events: \(error)")
            }
        }
    }
}

struct EventCardView: View {
    let event: CrowdEvent
    @State private var isAttending = false
    @State private var isExpanded = false
    @State private var showEventURL = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    if let description = event.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let startsAt = event.startsAt {
                        Text(formatEventTime(startsAt))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let category = event.category {
                        Text(category.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            
            // Event URL section (shown when expanded)
            if isExpanded && showEventURL {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        Text("Event Link")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Button("Open") {
                            // Open event URL
                            if let url = URL(string: "https://example.com/event/\(event.id)") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                    }
                }
            }
            
            // Tags
            if !event.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(event.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // Attending button
            HStack {
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAttending.toggle()
                        if isAttending {
                            // Add to attended events
                            AttendedEventsService.shared.addAttendedEvent(event)
                        } else {
                            // Remove from attended events
                            AttendedEventsService.shared.removeAttendedEvent(event.id)
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isAttending ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(isAttending ? "Attending" : "I'm Attending")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isAttending ? .white : .accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isAttending ? Color.accentColor : Color.accentColor.opacity(0.1))
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
                if isExpanded {
                    showEventURL = true
                }
            }
        }
        .onAppear {
            // Check if user is already attending this event
            isAttending = AttendedEventsService.shared.isAttendingEvent(event.id)
        }
        .onChange(of: AttendedEventsService.shared.attendedEvents) { _, _ in
            // Update state when attended events list changes
            isAttending = AttendedEventsService.shared.isAttendingEvent(event.id)
        }
    }
    
    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    CalenderView()
}
