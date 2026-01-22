//
//  OnboardingView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            let safeAreaInsets = geo.safeAreaInsets
            let availableHeight = geo.size.height - safeAreaInsets.top - safeAreaInsets.bottom
            
            ZStack {
                // Background
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Logo text - responsive sizing for iPad
                    Image("CrowdText")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width * 0.25, 250), height: min(geo.size.height * 0.12, 140))
                        .padding(.bottom, 12)

                    // People + fire graphic - responsive sizing for iPad
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width * 0.4, 380), height: min(geo.size.height * 0.28, 320))
                        .padding(.bottom, 48)

                    Spacer(minLength: 0)

                    // Main glass card - pinned to bottom - responsive sizing
                    VStack(spacing: 16) {
                        Text("Welcome to Crowd")
                            .font(.system(size: min(geo.size.width * 0.04, 28), weight: .semibold, design: .rounded))
                            .foregroundColor(.black)

                        Button(action: onContinue) {
                            HStack(spacing: 8) {
                                Text("Jump In")
                                    .font(.system(size: min(geo.size.width * 0.025, 24), weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: 0x02853E))
                            )
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 4)
                        }

                        Text("By clicking continue, you agree to our Terms of Service and Privacy Policy.")
                            .font(.system(size: min(geo.size.width * 0.014, 14)))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.2), radius: 24, y: 10)
                    )
                    .padding(.horizontal, min(geo.size.width * 0.08, 40))
                    .padding(.bottom, max(34, safeAreaInsets.bottom + 34))
                }
                .frame(height: availableHeight)
                .padding(.top, safeAreaInsets.top)
            }
        }
    }
}

#Preview {
    OnboardingView {
        print("Continue tapped")
    }
    .frame(width: 768, height: 1024) // iPad preview size
}

