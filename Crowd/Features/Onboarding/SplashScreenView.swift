//
//  SplashScreenView.swift
//  Crowd
//
//  Initial splash screen showing Crowd logo before fading to onboarding.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var showLogo = true
    @State private var logoOpacity: Double = 1.0
    @State private var logoScale: CGFloat = 0.8
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
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
            .opacity(logoOpacity)
        }
        .onAppear {
            // Animate logo in
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
            }
            
            // After 2 seconds, fade out and transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    logoOpacity = 0
                }
                
                // Complete after fade animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
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
