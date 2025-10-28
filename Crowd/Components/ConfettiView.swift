//
//  ConfettiView.swift
//  Crowd
//
//  Created by AI Assistant on 10/28/25.
//

import SwiftUI

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece, animate: animate)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
                withAnimation(.easeOut(duration: 0.6)) {
                    animate = true
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        let shapes: [ConfettiShape] = [.circle, .square, .triangle]
        
        confettiPieces = (0..<100).map { _ in
            ConfettiPiece(
                x: Double.random(in: 0...size.width),
                y: -50,
                color: colors.randomElement() ?? .blue,
                shape: shapes.randomElement() ?? .circle,
                rotation: Double.random(in: 0...360),
                size: CGFloat.random(in: 8...16)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let color: Color
    let shape: ConfettiShape
    let rotation: Double
    let size: CGFloat
}

enum ConfettiShape {
    case circle, square, triangle
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let animate: Bool
    
    var body: some View {
        shapeView
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size)
            .rotationEffect(.degrees(animate ? piece.rotation + 720 : piece.rotation))
            .position(
                x: piece.x + (animate ? Double.random(in: -100...100) : 0),
                y: animate ? UIScreen.main.bounds.height + 50 : piece.y
            )
            .animation(
                .easeOut(duration: Double.random(in: 1.5...2.5))
                .delay(Double.random(in: 0...0.3)),
                value: animate
            )
    }
    
    @ViewBuilder
    private var shapeView: some Shape {
        switch piece.shape {
        case .circle:
            Circle()
        case .square:
            Rectangle()
        case .triangle:
            Triangle()
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Modifier

struct ConfettiModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isPresented {
                        ConfettiView()
                            .onAppear {
                                // Auto-dismiss after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    isPresented = false
                                }
                            }
                    }
                }
            )
    }
}

extension View {
    func confetti(isPresented: Binding<Bool>) -> some View {
        modifier(ConfettiModifier(isPresented: isPresented))
    }
}

