//
//  ProfileView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

// MARK: - Entry
struct RootView: View {
    @State private var showProfile = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Open Profile") { showProfile = true }
                .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(viewModel: ProfileViewModel.mock)
                .modifier(Presentation75Detent())
        }
    }
}

// MARK: - 3/4 Sheet Detent
private struct Presentation75Detent: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents(Set([.fraction(0.75), .large]))
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        } else {
            content
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showInterestPicker = false
    @State private var showImagePicker = false
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isLoading {
                ProgressView("Loading profile...")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        identityBlock
                        tagsSection
                        statsRow
                        attendedEventsSection

                    }
                    .padding(16)
                }

                // Edit Mode Toggle Button
                Button(action: { 
                    if viewModel.isEditMode {
                        Task {
                            await saveChanges()
                        }
                    }
                    viewModel.toggleEditMode()
                }) {
                    Image(systemName: viewModel.isEditMode ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(viewModel.isEditMode ? Color.green : Color.accentColor)
                        .background(Circle().fill(Color(.systemBackground)).frame(width: 44, height: 44))
                }
                .padding(16)
            }
        }
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $viewModel.profileImage)
        }
        .sheet(isPresented: $showInterestPicker) {
            InterestPickerView(viewModel: viewModel)
        }
    }
    
    // MARK: - Firebase Actions
    
    private func loadProfile() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else {
            isLoading = false
            return
        }
        
        await viewModel.loadProfile(userId: userId)
        isLoading = false
    }
    
    private func saveChanges() async {
        guard let userId = FirebaseManager.shared.getCurrentUserId() else { return }
        await viewModel.saveChanges(userId: userId)
    }

    // MARK: - Identity Block (Header)
    private var identityBlock: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                if let profileImage = viewModel.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                } else {
                    AvatarView(
                        name: viewModel.displayName,
                        color: viewModel.avatarColor,
                        size: 90,
                        showOnlineStatus: viewModel.isActiveNow
                    )
                }

                if viewModel.isEditMode {
                    Button(action: { showImagePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill").font(.system(size: 10))
                            Text("Edit").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: Capsule())
                    }
                    .offset(y: 8)
                }
            }

            Text(viewModel.handle)
                .font(.system(size: 18, weight: .bold))

            // bio -> editable in edit mode, black in read mode
            if viewModel.isEditMode {
                TextEditor(text: $viewModel.bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(minHeight: 60, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.18), lineWidth: 1))
                    .submitLabel(.done)
            } else {
                Text(viewModel.bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }

            Text(viewModel.affiliation)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(title: "Hosted", value: "\(viewModel.hostedCount)")
                statCard(title: "Joined", value: "\(viewModel.joinedCount)")
                statCard(title: "Upcoming", value: "\(viewModel.upcomingEventsCount)")
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 18, weight: .semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.24), lineWidth: 1))
    }

    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interests")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.interests) { interest in
                        TagPillView(
                            interest: interest,
                            isEditMode: viewModel.isEditMode,
                            onDelete: { viewModel.removeInterest(interest) }
                        )
                    }

                    if viewModel.isEditMode {
                        AddInterestPillView { showInterestPicker = true }
                    }
                }
            }
        }
    }
    
    // MARK: - Attending Events Section
    private var attendedEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attending")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            
            let attendedEvents = AttendedEventsService.shared.getAttendedEvents()
            
            VStack(spacing: 12) {
                if attendedEvents.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray.opacity(0.6))
                        
                        Text("No events attending yet")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        
                        Text("Join events from the calendar to see them here")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(attendedEvents.prefix(5)) { event in
                            AttendedEventRow(event: event)
                        }
                        
                        if attendedEvents.count > 5 {
                            Text("+ \(attendedEvents.count - 5) more events")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.24), lineWidth: 1))
        }
    }
}

// MARK: - Attended Event Row
struct AttendedEventRow: View {
    let event: CrowdEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Event icon
            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .medium))
                )
            
            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let startsAt = event.startsAt {
                    Text(formatEventDate(startsAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                
                Text("Attended")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews
#Preview {
    RootView()
}
