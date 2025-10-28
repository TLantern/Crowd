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
        ZStack {
            // Background
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 60)

                // Logo text
                Image("CrowdText")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 120)

                // People + fire graphic
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 170)
                    .padding(.bottom, 40)

                Spacer()

                // Main glass card
                VStack(spacing: 16) {
                    Text("Welcome to Crowd")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)

                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Text("Jump In")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
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
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    OnboardingView {
        print("Continue tapped")
    }
}


