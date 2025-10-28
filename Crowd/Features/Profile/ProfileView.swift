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
    @State private var showShareSheet = false
    @State private var showInterestPicker = false
    @State private var showImagePicker = false
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isLoading {
                ProgressView("Loading profile...")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        identityBlock
                        tagsSection
                        statsRow
                        gallerySection
                        attendingSection

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
                        .scaledToFill()
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

            // last seen -> black text
            Text(viewModel.activeStatusText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

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

            AuraBadgeView(points: viewModel.points, rank: viewModel.auraRank)

            Text(viewModel.affiliation)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard(title: "Hosted", value: "\(viewModel.hostedCount)")
                statCard(title: "Joined", value: "\(viewModel.joinedCount)")
                statCard(title: "Friends", value: "\(viewModel.friendsCount)")
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

    // Removed interaction bar (Invite/QR/DM/Add Friend/Test)

    // MARK: - Gallery Section
    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hosted Events")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                ForEach(viewModel.gallery) { event in
                    Button(action: { print("Event tapped: \(event.title)") }) {
                        eventCard(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    

    private func eventCard(_ event: CrowdEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.2))
                .frame(height: 110)
                .overlay(
                    VStack {
                        Image(systemName: iconForEvent(event))
                            .font(.system(size: 32))
                            .foregroundStyle(.primary)
                        Text("\(event.attendeeCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if let tag = event.tags.first {
                    Text(tag)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.24), lineWidth: 1))
    }

    private func iconForEvent(_ event: CrowdEvent) -> String {
        guard let tag = event.tags.first else { return "star.fill" }
        switch tag.lowercased() {
        case "study": return "book.fill"
        case "sports": return "basketball.fill"
        case "social": return "cup.and.saucer.fill"
        case "music": return "music.note"
        case "tech": return "laptopcomputer"
        case "art": return "paintpalette.fill"
        default: return "star.fill"
        }
    }

    // MARK: - Suggested Connections
    // Removed suggested connections

    // MARK: - Attending Section
    @EnvironmentObject private var appState: AppState
    private var attendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attending")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if appState.attendingEvents.isEmpty {
                Text("No upcoming events saved")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(appState.attendingEvents) { event in
                        eventCard(event)
                    }
                }
            }
        }
    }
}

// MARK: - Previews
#Preview {
    RootView()
}
