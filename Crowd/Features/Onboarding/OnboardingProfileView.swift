//
//  OnboardingProfileView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct OnboardingProfileView: View {
    @Binding var username: String
    @Binding var selectedCampus: String
    
    let onNext: () -> Void
    
    init(username: Binding<String> = .constant(""), selectedCampus: Binding<String> = .constant("UNT"), onNext: @escaping () -> Void) {
        self._username = username
        self._selectedCampus = selectedCampus
        self.onNext = onNext
        
        // Set default if empty
        if self.selectedCampus.isEmpty {
            self.selectedCampus = "UNT"
        }
    }
    
    var body: some View {
        ZStack {
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 24, y: 8)
                    .overlay(
                        VStack(spacing: 16) {
                            Text("Almost done ✨")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)

                            Text("How should friends see you?")
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.7))

                            // Profile Image Section
                            ZStack {
                                Button(action: {
                                    // TODO: Implement profile image picker
                                    print("Profile image tapped - open image picker")
                                }) {
                                    Image("ProfilePlaceholder")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 170, height: 100)
                                        .clipShape(Circle())
                                }
                                
                                // Camera button overlay - positioned to overlap the corner
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            // TODO: Implement camera/image picker
                                            print("Camera button tapped - open image picker")
                                        }) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    Circle()
                                                        .fill(Color.black.opacity(0.8))
                                                )
                                        }
                                    }
                                    .offset(x: -8, y: -8) // Overlap the corner
                                }
                            }

                            TextField("Ex. Scrappy", text: $username)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.6))
                                )
                                .foregroundColor(.black)

                            Text("Use your real name or keep it mysterious 👀 your choice.")
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black.opacity(0.7))

                            Menu {
                                Button("UNT") { selectedCampus = "UNT" }
                                Button("SMU") { selectedCampus = "SMU" }
                            } label: {
                                HStack {
                                    Text(selectedCampus.isEmpty ? "Campus" : selectedCampus)
                                        .foregroundColor(selectedCampus.isEmpty ? .black.opacity(0.5) : .black)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.6))
                                )
                            }

                            Button(action: onNext) {
                                Text("Next →")
                                    .font(.system(size: 18, weight: .medium))
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.white)
                                    )
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(24)
                    )
                    .padding(.horizontal, 24)
                    .frame(maxHeight: 600)
                
                Spacer()
            }
        }
    }
}

#Preview {
    OnboardingProfileView {
        print("Next tapped")
    }
}

