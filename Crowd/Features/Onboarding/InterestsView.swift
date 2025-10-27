//
//  InterestsView.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI

struct InterestsView: View {
    @State private var selectedInterests: Set<String> = []
    
    let onNext: ([String]) -> Void
    
    let interests: [(emoji: String, name: String)] = [
        ("🎮", "Gaming"),
        ("🎵", "Music"),
        ("🏀", "Sports"),
        ("🍕", "Food"),
        ("🎥", "Movies"),
        ("💻", "Tech"),
        ("🎨", "Art"),
        ("🌍", "Travel"),
        ("🧘", "Chill")
    ]
    
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
                            Text("What's your scene?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Pick what you're into 👇")
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.7))
                            
                            // Interest chips grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(interests, id: \.name) { interest in
                                    InterestChip(
                                        emoji: interest.emoji,
                                        name: interest.name,
                                        isSelected: selectedInterests.contains(interest.name)
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedInterests.contains(interest.name) {
                                                selectedInterests.remove(interest.name)
                                            } else {
                                                selectedInterests.insert(interest.name)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            Button {
                                onNext(Array(selectedInterests))
                            } label: {
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
                            .disabled(selectedInterests.isEmpty)
                            .opacity(selectedInterests.isEmpty ? 0.5 : 1.0)
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

// MARK: - Interest Chip Component
struct InterestChip: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.8 : 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(isSelected ? 0.4 : 0.0), lineWidth: 2)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

#Preview {
    InterestsView { interests in
        print("Selected interests: \(interests)")
    }
}

