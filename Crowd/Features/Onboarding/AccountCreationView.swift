//
//  AccountCreationView.swift
//  Crowd
//
//  Required account creation during onboarding.
//  User must enter a name and select at least one interest to continue.
//

import SwiftUI

struct AccountCreationView: View {
    @State private var displayName: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var selectedProfileImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @FocusState private var isNameFocused: Bool
    
    let onComplete: (String, [Interest], UIImage?) -> Void
    
    // Minimum interests required to continue
    private let minimumInterests = 1
    
    // Check if form is valid
    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedInterests.count >= minimumInterests
    }
    
    var body: some View {
        ZStack {
            // Background - tap to dismiss keyboard
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    isNameFocused = false
                }
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with profile image picker
                    headerView
                    
                    // Name input
                    nameInputView
                    
                    // Interests selection
                    interestsSelectionView
                    
                    // Continue button
                    continueButton
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            AnalyticsService.shared.trackScreenView("account_creation")
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $selectedProfileImage)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Profile image picker
            Button(action: {
                showImagePicker = true
            }) {
                ZStack {
                    if let image = selectedProfileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(hex: 0x02853E).opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: 0x02853E))
                    }
                    
                    // Camera badge
                    Circle()
                        .fill(Color(hex: 0x02853E))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                        .offset(x: 35, y: 35)
                }
            }
            
            Text("Tap to add photo")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Create Your Profile")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Tell us a bit about yourself")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Name Input View
    
    private var nameInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What should we call you?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            TextField("Enter your name", text: $displayName)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isNameFocused ? Color(hex: 0x02853E) : Color.white.opacity(0.2), lineWidth: 2)
                        )
                )
                .focused($isNameFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit {
                    // Dismiss keyboard when pressing return
                    isNameFocused = false
                }
            
            if !displayName.isEmpty {
                Text("Hey \(displayName)! 👋")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: 0x02853E))
            }
        }
    }
    
    // MARK: - Interests Selection View
    
    private var interestsSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("What are you into?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(selectedInterests.count) selected")
                    .font(.system(size: 14))
                    .foregroundColor(selectedInterests.count >= minimumInterests ? Color(hex: 0x02853E) : .white.opacity(0.5))
            }
            
            Text("Select at least \(minimumInterests) interest to continue")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            // Interests grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Interest.allInterests) { interest in
                    OnboardingInterestChip(
                        emoji: interest.emoji,
                        name: interest.name,
                        isSelected: selectedInterests.contains(interest.id),
                        onTap: {
                            toggleInterest(interest)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: {
            // Get selected interest objects
            let interests = Interest.allInterests.filter { selectedInterests.contains($0.id) }
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            AnalyticsService.shared.track("account_created", props: [
                "name_length": name.count,
                "interests_count": interests.count,
                "has_profile_image": selectedProfileImage != nil
            ])
            
            onComplete(name, interests, selectedProfileImage)
        }) {
            HStack {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isFormValid ? Color(hex: 0x02853E) : Color.gray.opacity(0.5))
            )
        }
        .disabled(!isFormValid)
    }
    
    // MARK: - Helpers
    
    private func toggleInterest(_ interest: Interest) {
        if selectedInterests.contains(interest.id) {
            selectedInterests.remove(interest.id)
        } else {
            selectedInterests.insert(interest.id)
        }
    }
}

// MARK: - Onboarding Interest Chip (renamed to avoid conflict with existing InterestChip)

struct OnboardingInterestChip: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 16))
                
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: 0x02853E) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: 0x02853E) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    AccountCreationView { name, interests, profileImage in
        print("Name: \(name), Interests: \(interests.count), Image: \(profileImage != nil)")
    }
}
