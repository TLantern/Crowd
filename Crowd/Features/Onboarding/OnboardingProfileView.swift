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
                        VStack(spacing: 16) {
                            Text("Almost done ✨")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)

                            Text("How should friends see you?")
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.7))

                            Image("ProfilePic")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)

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
                                    Text(selectedCampus)
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

