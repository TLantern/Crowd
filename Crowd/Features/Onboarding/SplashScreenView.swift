//
//  SplashScreenView.swift
//  Crowd
//
//  Initial splash screen showing Crowd logo with "Join the Crowd" button.
//  Features typewriter animation showing "Crowd" in different languages.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var buttonOpacity: Double = 0
    @State private var isTransitioning: Bool = false
    @State private var contentOpacity: Double = 1.0
    @State private var showTypewriter: Bool = false
    
    let onComplete: () -> Void
    
    // "Crowd" in different languages
    private let crowdTranslations: [(text: String, language: String)] = [
        ("Crowd", "English"),
        ("Multitud", "Spanish"),
        ("Foule", "French"),
        ("人群", "Chinese"),
        ("群衆", "Japanese"),
        ("군중", "Korean"),
        ("Толпа", "Russian"),
        ("Menge", "German"),
        ("Folla", "Italian"),
        ("حشد", "Arabic"),
        ("Multidão", "Portuguese"),
        ("भीड़", "Hindi"),
        ("Kalabalık", "Turkish"),
        ("Đám đông", "Vietnamese"),
        ("Tłum", "Polish")
    ]
    
    var body: some View {
        ZStack {
            // Background
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Typewriter text scattered across screen
            if showTypewriter {
                TypewriterOverlay(translations: crowdTranslations)
                    .opacity(contentOpacity)
            }
            
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
            // Start typewriter animation immediately
            showTypewriter = true
            
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

// MARK: - Typewriter Overlay

struct TypewriterOverlay: View {
    let translations: [(text: String, language: String)]
    
    // Positions for text (scattered around the screen avoiding center)
    private let positions: [(x: CGFloat, y: CGFloat)] = [
        (0.15, 0.08),  // top left
        (0.85, 0.12),  // top right
        (0.10, 0.25),  // left upper
        (0.90, 0.22),  // right upper
        (0.20, 0.75),  // left lower
        (0.80, 0.78),  // right lower
        (0.12, 0.88),  // bottom left
        (0.88, 0.85),  // bottom right
        (0.50, 0.05),  // top center
        (0.25, 0.42),  // mid left
        (0.75, 0.45),  // mid right
        (0.15, 0.58),  // left mid-lower
        (0.85, 0.55),  // right mid-lower
        (0.50, 0.92),  // bottom center
        (0.30, 0.15),  // upper left area
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<min(translations.count, positions.count), id: \.self) { index in
                    TypewriterText(
                        text: translations[index].text,
                        delay: Double(index) * 0.25,
                        colorIndex: index
                    )
                    .position(
                        x: geometry.size.width * positions[index].x,
                        y: geometry.size.height * positions[index].y
                    )
                }
            }
        }
    }
}

// MARK: - Typewriter Text

struct TypewriterText: View {
    let text: String
    let delay: Double
    let colorIndex: Int
    
    @State private var displayedText: String = ""
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var isTyping: Bool = false
    
    // Vibrant colors for pop effect
    private let colors: [Color] = [
        Color(hex: 0x02853E),      // Crowd green
        Color(hex: 0xFF6B35),      // Orange
        Color(hex: 0x4ECDC4),      // Teal
        Color(hex: 0xFFE66D),      // Yellow
        Color(hex: 0xFF6B6B),      // Coral
        Color(hex: 0x95E1D3),      // Mint
        Color(hex: 0xDDA0DD),      // Plum
        Color(hex: 0x98D8C8),      // Sea green
    ]
    
    private var textColor: Color {
        colors[colorIndex % colors.count]
    }
    
    var body: some View {
        Text(displayedText)
            .font(.system(size: CGFloat.random(in: 18...28), weight: .black))
            .foregroundColor(textColor)
            .shadow(color: textColor.opacity(0.5), radius: 4, x: 0, y: 2)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                startTypewriter()
            }
    }
    
    private func startTypewriter() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Pop in animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                opacity = 1.0
                scale = 1.0
            }
            
            isTyping = true
            typeNextCharacter(index: 0)
        }
    }
    
    private func typeNextCharacter(index: Int) {
        guard index < text.count else {
            // Typing complete - pop out after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                    scale = 1.2
                }
                // Restart after fade
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    displayedText = ""
                    scale = 0.8
                    startTypewriter()
                }
            }
            return
        }
        
        let charIndex = text.index(text.startIndex, offsetBy: index)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            displayedText += String(text[charIndex])
            typeNextCharacter(index: index + 1)
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash complete")
    }
}
