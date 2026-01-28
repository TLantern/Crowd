//
//  SplashScreenView.swift
//  Crowd
//
//  Initial splash screen showing Crowd logo with "Join the Crowd" button.
//  Features typewriter animation showing "Crowd" in different languages.
//  English "Crowd" appears every other word for emphasis.
//  iPad compatible with responsive sizing.
//

import SwiftUI
import UIKit

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var isTransitioning: Bool = false
    @State private var contentOpacity: Double = 1.0
    
    let onComplete: () -> Void
    
    private var isIPad: Bool {
        let result = UIDevice.current.userInterfaceIdiom == .pad
        print("🎯 [SplashScreenView] isIPad check: \(result), idiom: \(UIDevice.current.userInterfaceIdiom.rawValue)")
        return result
    }
    
    var body: some View {
        if isIPad {
            iPadView
        } else {
            iPhoneView
        }
    }
    
    // MARK: - iPhone View (Simple Layout)
    
    private var iPhoneView: some View {
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
                VStack(spacing: 16) {
                    FlickeringLogoView()
                        .frame(width: 250, height: 250)
                    
                    CrowdTypewriterView(baseFontSize: 72)
                        .frame(height: 80)
                }
                .scaleEffect(logoScale)
                
                Spacer()
                
                // Join the Crowd button
                Button(action: {
                    isTransitioning = true
                    withAnimation(.easeInOut(duration: 0.5)) {
                        contentOpacity = 0
                    }
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
                .disabled(isTransitioning)
                
                Spacer()
                    .frame(height: 60)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - iPad View (Responsive Layout)
    
    private var iPadView: some View {
        GeometryReader { geometry in
            let screenBounds = UIScreen.main.bounds
            let safeW = max(1, geometry.size.width)
            let safeH = max(1, geometry.size.height)
            let fullScreenH = screenBounds.height
            let _ = print("📐 [SplashScreenView] GeometryReader size: \(geometry.size.width)x\(geometry.size.height), safeArea: \(geometry.safeAreaInsets)")
            let _ = print("📐 [SplashScreenView] Calculated safeW=\(safeW), safeH=\(safeH), fullScreenH=\(fullScreenH)")
            ZStack {
                // Background
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .onAppear {
                        print("🖼️ [SplashScreenView] Background image appeared")
                    }
                
                // Logo and typewriter – upper portion
                VStack(spacing: safeH * 0.02) {
                    Spacer()
                        .frame(height: safeH * 0.08)
                    
                    VStack(spacing: safeH * 0.02) {
                        FlickeringLogoView()
                            .frame(
                                width: min(safeW * 0.35, 350),
                                height: min(safeW * 0.35, 350)
                            )
                        
                        CrowdTypewriterView(
                            baseFontSize: min(safeW * 0.08, 72)
                        )
                        .frame(height: min(safeW * 0.1, 90))
                    }
                    .scaleEffect(logoScale)
                    
                    Spacer(minLength: 0)
                }
                .opacity(contentOpacity)
                
                // Join the Crowd – centered on screen
                VStack {
                    Spacer()
                    Button(action: {
                        print("📱 [SplashScreenView] Join the Crowd tapped")
                        isTransitioning = true
                        withAnimation(.easeInOut(duration: 0.5)) {
                            contentOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onComplete()
                        }
                    }) {
                        let fontSize = isIPad ? min(safeW * 0.04, 32) : min(safeW * 0.04, 24)
                        let maxWidth = max(280, min(safeW * 0.5, 480))
                        let verticalPadding = isIPad ? 18 : min(safeH * 0.025, 20)
                        let _ = print("🔘 [SplashScreenView] Button config - isIPad: \(isIPad), fontSize: \(fontSize), maxWidth: \(maxWidth), verticalPadding: \(verticalPadding)")
                        
                        Text("Join the Crowd")
                            .font(.system(
                                size: fontSize,
                                weight: .bold
                            ))
                            .foregroundColor(.white)
                            .frame(maxWidth: maxWidth)
                            .frame(minHeight: 56)
                            .padding(.vertical, verticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: 0x02853E))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, isIPad ? 56 : 40)
                    .disabled(isTransitioning)
                    .background(GeometryReader { buttonGeometry in
                        Color.clear.onAppear {
                            let globalFrame = buttonGeometry.frame(in: .global)
                            let screenBounds = UIScreen.main.bounds
                            let scale = UIScreen.main.scale
                            print("🔘 [SplashScreenView] Button geometry - size: \(buttonGeometry.size)")
                            print("🔘 [SplashScreenView] Button global frame: \(globalFrame)")
                            print("🔘 [SplashScreenView] Screen bounds: \(screenBounds), scale: \(scale)")
                            print("🔘 [SplashScreenView] Button visible check - Y: \(globalFrame.minY), screen height: \(screenBounds.height), button bottom: \(globalFrame.maxY)")
                            print("🔘 [SplashScreenView] Button visibility: minY(\(globalFrame.minY)) < screenHeight(\(screenBounds.height)) = \(globalFrame.minY < screenBounds.height), maxY(\(globalFrame.maxY)) < screenHeight = \(globalFrame.maxY < screenBounds.height)")
                        }
                    })
                    Spacer()
                }
                .background(Color.clear)
                .onAppear {
                    print("🟢 [SplashScreenView] Button VStack appeared - isIPad: \(isIPad), isTransitioning: \(isTransitioning)")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
                .background(GeometryReader { vStackGeometry in
                    Color.clear.onAppear {
                        print("📦 [SplashScreenView] Button VStack geometry - size: \(vStackGeometry.size), frame: \(vStackGeometry.frame(in: .global))")
                    }
                })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GeometryReader { zStackGeometry in
                Color.clear.onAppear {
                    let screenBounds = UIScreen.main.bounds
                    print("📦 [SplashScreenView] ZStack geometry - size: \(zStackGeometry.size), frame: \(zStackGeometry.frame(in: .global)), safeArea: \(zStackGeometry.safeAreaInsets)")
                    print("📦 [SplashScreenView] Screen bounds comparison - ZStack height: \(zStackGeometry.size.height), Screen height: \(screenBounds.height)")
                }
            })
        }
        .background(GeometryReader { mainGeometry in
            Color.clear.onAppear {
                print("📦 [SplashScreenView] Main GeometryReader - size: \(mainGeometry.size), frame: \(mainGeometry.frame(in: .global)), safeArea: \(mainGeometry.safeAreaInsets)")
            }
        })
        .onAppear {
            let bounds = UIScreen.main.bounds
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            let safeAreaInsets = window?.safeAreaInsets ?? .zero
            
            print("📱 [SplashScreenView] onAppear START")
            print("📱 [SplashScreenView]   UIScreen.bounds=\(bounds.size.width)x\(bounds.size.height)")
            print("📱 [SplashScreenView]   idiom=\(UIDevice.current.userInterfaceIdiom.rawValue) (\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"))")
            print("📱 [SplashScreenView]   window safeAreaInsets=\(safeAreaInsets)")
            print("📱 [SplashScreenView]   isIPad=\(isIPad)")
            print("📱 [SplashScreenView]   contentOpacity=\(contentOpacity)")
            print("📱 [SplashScreenView]   isTransitioning=\(isTransitioning)")
            
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Flickering Logo View (flame animation effect)

struct FlickeringLogoView: View {
    @State private var flickerOffsetX: CGFloat = 0
    @State private var flickerOffsetY: CGFloat = 0
    @State private var flickerRotation: Double = 0
    @State private var glowOpacity: Double = 0.5
    @State private var glowRadius: CGFloat = 20
    
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .offset(x: flickerOffsetX, y: flickerOffsetY)
            .rotationEffect(.degrees(flickerRotation))
            .shadow(color: Color.orange.opacity(glowOpacity), radius: glowRadius, x: 0, y: 0)
            .shadow(color: Color.yellow.opacity(glowOpacity * 0.5), radius: glowRadius * 1.5, x: 0, y: 0)
            .onAppear {
                startFlickering()
                startGlowPulsing()
            }
    }
    
    private func startFlickering() {
        // Continuous flame flicker effect
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                // Random small offsets to simulate flame movement
                flickerOffsetX = CGFloat.random(in: -1.5...1.5)
                flickerOffsetY = CGFloat.random(in: -1.0...1.0)
                flickerRotation = Double.random(in: -0.8...0.8)
            }
        }
    }
    
    private func startGlowPulsing() {
        // Pulsing glow effect - larger for bigger logo
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
            glowRadius = 35
        }
    }
}

// MARK: - Crowd Typewriter View (cycles through languages)

struct CrowdTypewriterView: View {
    @State private var currentIndex: Int = 0
    @State private var displayedText: String = ""
    @State private var isTyping: Bool = false
    @State private var textOpacity: Double = 1.0
    @State private var textScale: CGFloat = 1.0
    
    let baseFontSize: CGFloat
    
    // "Crowd" in different languages with colors
    // Pattern: English appears EVERY OTHER word for emphasis
    private let translations: [(text: String, color: Color, isEnglish: Bool)] = [
        ("Crowd", Color(hex: 0x02853E), true),        // English - Crowd green
        ("Multitud", Color(hex: 0xFF6B35), false),    // Spanish - Orange
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Foule", Color(hex: 0x4ECDC4), false),       // French - Teal
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("人群", Color(hex: 0xE91E63), false),         // Chinese - Pink
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Ìjọ", Color(hex: 0xFFD700), false),         // Yoruba - Gold
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("群衆", Color(hex: 0x9C27B0), false),         // Japanese - Purple
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("군중", Color(hex: 0x00BCD4), false),         // Korean - Cyan
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Толпа", Color(hex: 0xFF5722), false),       // Russian - Deep Orange
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Menge", Color(hex: 0x8BC34A), false),       // German - Light Green
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Folla", Color(hex: 0xFFEB3B), false),       // Italian - Yellow
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("حشد", Color(hex: 0x3F51B5), false),          // Arabic - Indigo
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Multidão", Color(hex: 0xF44336), false),    // Portuguese - Red
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("भीड़", Color(hex: 0x009688), false),          // Hindi - Teal
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Kalabalık", Color(hex: 0xFF9800), false),   // Turkish - Amber
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Đám đông", Color(hex: 0x673AB7), false),    // Vietnamese - Deep Purple
        ("Crowd", Color(hex: 0x02853E), true),        // English
        ("Tłum", Color(hex: 0x2196F3), false),        // Polish - Blue
    ]
    
    private var currentTranslation: (text: String, color: Color, isEnglish: Bool) {
        translations[currentIndex % translations.count]
    }
    
    private var englishFontSize: CGFloat {
        baseFontSize
    }
    
    private var otherFontSize: CGFloat {
        baseFontSize * 0.9
    }
    
    var body: some View {
        Text(displayedText)
            .font(.system(
                size: currentTranslation.isEnglish ? englishFontSize : otherFontSize,
                weight: currentTranslation.isEnglish ? .black : .bold,
                design: .rounded
            ))
            .foregroundColor(currentTranslation.color)
            .shadow(color: currentTranslation.color.opacity(0.4), radius: 8, x: 0, y: 4)
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
            // Typing complete - wait longer (2.0 seconds) then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
        
        // Slower typing speed: 0.15 for English, 0.12 for others
        let delay = currentTranslation.isEnglish ? 0.15 : 0.12
        
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
    .frame(width: 768, height: 1024) // iPad preview size
}
