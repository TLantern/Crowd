//
//  OnboardingProfileView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct OnboardingProfileView: View {
    @State private var username: String = ""
    @State private var selectedCampus: String = "UNT"
    
    let onNext: () -> Void
    
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
                        VStack(spacing: 28) {
                            Text("Almost done ✨")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)

                            Text("How should friends see you?")
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.7))

                            Image("ProfilePlaceholder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 94, height: 94)

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
                                Button {
                                    // Disabled - coming soon
                                } label: {
                                    HStack {
                                        Text("UTD")
                                        Spacer()
                                        Text("Coming Soon")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .disabled(true)
                                .opacity(0.5)
                                .blur(radius: 1.5)
                                
                                Button {
                                    // Disabled - coming soon
                                } label: {
                                    HStack {
                                        Text("UTSA")
                                        Spacer()
                                        Text("Coming Soon")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .disabled(true)
                                .opacity(0.5)
                                .blur(radius: 1.5)
                            } label: {
                                HStack(spacing: 12) {
                                    Spacer()
                                    Image("UNTlogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                    Text(selectedCampus)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                    Spacer()
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.6))
                                )
                            }
                            .menuOrder(.fixed)

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

