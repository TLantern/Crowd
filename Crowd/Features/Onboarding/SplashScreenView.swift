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
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 30) {
                Spacer()
                
                // Logo and Typewriter Text
                VStack(spacing: 24) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                    
                    // Typewriter "Crowd" in different languages (replaces CrowdText image)
                    CrowdTypewriterView()
                        .frame(height: 50)
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

// MARK: - Crowd Typewriter View (cycles through languages)

struct CrowdTypewriterView: View {
    @State private var currentIndex: Int = 0
    @State private var displayedText: String = ""
    @State private var isTyping: Bool = false
    @State private var textOpacity: Double = 1.0
    @State private var textScale: CGFloat = 1.0
    
    // "Crowd" in different languages with colors
    private let translations: [(text: String, color: Color)] = [
        ("Crowd", Color(hex: 0x02853E)),       // English - Crowd green (FIRST - BOLD)
        ("Multitud", Color(hex: 0xFF6B35)),    // Spanish - Orange
        ("Foule", Color(hex: 0x4ECDC4)),       // French - Teal
        ("人群", Color(hex: 0xE91E63)),         // Chinese - Pink
        ("群衆", Color(hex: 0x9C27B0)),         // Japanese - Purple
        ("군중", Color(hex: 0x00BCD4)),         // Korean - Cyan
        ("Толпа", Color(hex: 0xFF5722)),       // Russian - Deep Orange
        ("Menge", Color(hex: 0x8BC34A)),       // German - Light Green
        ("Folla", Color(hex: 0xFFEB3B)),       // Italian - Yellow
        ("حشد", Color(hex: 0x3F51B5)),          // Arabic - Indigo
        ("Multidão", Color(hex: 0xF44336)),    // Portuguese - Red
        ("भीड़", Color(hex: 0x009688)),          // Hindi - Teal
        ("Kalabalık", Color(hex: 0xFF9800)),   // Turkish - Amber
        ("Đám đông", Color(hex: 0x673AB7)),    // Vietnamese - Deep Purple
        ("Tłum", Color(hex: 0x2196F3)),        // Polish - Blue
    ]
    
    private var currentTranslation: (text: String, color: Color) {
        translations[currentIndex % translations.count]
    }
    
    // First one (English) is extra bold
    private var isFirstLanguage: Bool {
        currentIndex % translations.count == 0
    }
    
    var body: some View {
        Text(displayedText)
            .font(.system(
                size: isFirstLanguage ? 42 : 38,
                weight: isFirstLanguage ? .black : .bold,
                design: .rounded
            ))
            .foregroundColor(currentTranslation.color)
            .shadow(color: currentTranslation.color.opacity(0.4), radius: 6, x: 0, y: 3)
            .opacity(textOpacity)
            .scaleEffect(textScale)
            .onAppear {
                startTyping()
            }
    }
    
    private func startTyping() {
        displayedText = ""
        textOpacity = 1.0
        textScale = 1.0
        isTyping = true
        
        typeNextCharacter(index: 0)
    }
    
    private func typeNextCharacter(index: Int) {
        let text = currentTranslation.text
        
        guard index < text.count else {
            // Typing complete - wait then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                // Fade out with scale
                withAnimation(.easeOut(duration: 0.3)) {
                    textOpacity = 0
                    textScale = 0.9
                }
                
                // Move to next language
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    currentIndex += 1
                    startTyping()
                }
            }
            return
        }
        
        let charIndex = text.index(text.startIndex, offsetBy: index)
        
        // Typing speed
        let delay = isFirstLanguage ? 0.08 : 0.06
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.05)) {
                displayedText += String(text[charIndex])
            }
            typeNextCharacter(index: index + 1)
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash complete")
    }
}
