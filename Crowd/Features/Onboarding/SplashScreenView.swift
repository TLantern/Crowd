//
//  SplashScreenView.swift
//  Crowd
//
//  Initial splash screen showing Crowd logo with "Join the Crowd" button.
//  User must tap the button to proceed (no auto-advance).
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var buttonOpacity: Double = 0
    @State private var isTransitioning: Bool = false
    @State private var contentOpacity: Double = 1.0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 40) {
                Spacer()
                
                // Logo
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                    
                    Image("CrowdText")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 60)
                }
                .scaleEffect(logoScale)
                
                Spacer()
                
                // Join the Crowd button
                Button(action: {
                    // Fade out and transition
                    isTransitioning = true
                    withAnimation(.easeInOut(duration: 0.5)) {
                        contentOpacity = 0
                    }
                    
                    // Complete after fade animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }) {
                    Text("Join the Crowd")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: 0x02853E))
                        )
                }
                .padding(.horizontal, 40)
                .opacity(buttonOpacity)
                .disabled(isTransitioning)
                
                Spacer()
                    .frame(height: 60)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            // Animate logo in
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
            }
            
            // Fade in button after logo animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    buttonOpacity = 1.0
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    SplashScreenView {
        print("Splash complete")
    }
}
