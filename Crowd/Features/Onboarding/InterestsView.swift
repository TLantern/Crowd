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
    
    let interests: [(emoji: String, title: String)] = [
        ("🎮", "Gaming"),
        ("🏀", "Basketball"),
        ("⚽", "Soccer"),
        ("🎾", "Tennis"),
        ("🏈", "Football"),
        ("🧘", "Wellness"),
        ("🎧", "Music"),
        ("🎤", "Singing"),
        ("🎸", "Guitar"),
        ("🥁", "Band Life"),
        ("💃", "Dance"),
        ("🎭", "Theatre"),
        ("🎨", "Art & Design"),
        ("📸", "Photography"),
        ("🎥", "Filmmaking"),
        ("🖥️", "Coding"),
        ("🤖", "AI & Tech"),
        ("🧬", "Science"),
        ("📚", "Study Sessions"),
        ("☕", "Coffee Runs"),
        ("🍕", "Foodie"),
        ("🍔", "Late-Night Eats"),
        ("🏋️", "Gym Life"),
        ("🏃", "Running"),
        ("🧗", "Adventure"),
        ("🚴", "Biking"),
        ("✈️", "Travel"),
        ("🏖️", "Beach Days"),
        ("🏕️", "Camping"),
        ("🏡", "Chill Spots"),
        ("🎉", "Parties"),
        ("🎮", "Esports"),
        ("💻", "Startups"),
        ("💡", "Entrepreneurship"),
        ("🧑‍💼", "Business"),
        ("💸", "Investing"),
        ("💬", "Public Speaking"),
        ("🎙️", "Podcasts"),
        ("📰", "Campus News"),
        ("📱", "Social Media"),
        ("🕹️", "Retro Games"),
        ("🧑‍🍳", "Cooking"),
        ("🐾", "Pets"),
        ("🪩", "Nightlife"),
        ("💞", "Dating & Friends"),
        ("🪶", "Writing"),
        ("✏️", "Graphic Design"),
        ("🌍", "Culture"),
        ("♻️", "Sustainability"),
        ("🔥", "Campus Events")
    ]
    
    // Split interests into pages of 9
    var interestPages: [[(emoji: String, title: String)]] {
        stride(from: 0, to: interests.count, by: 9).map {
            Array(interests[$0..<min($0 + 9, interests.count)])
        }
    }
    
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
                            
                            // Carousel of interest chips
                            TabView {
                                ForEach(0..<interestPages.count, id: \.self) { pageIndex in
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        ForEach(interestPages[pageIndex], id: \.title) { interest in
                                            InterestChip(
                                                emoji: interest.emoji,
                                                name: interest.title,
                                                isSelected: selectedInterests.contains(interest.title)
                                            ) {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    if selectedInterests.contains(interest.title) {
                                                        selectedInterests.remove(interest.title)
                                                    } else {
                                                        selectedInterests.insert(interest.title)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .indexViewStyle(.page(backgroundDisplayMode: .always))
                            .frame(height: 300)
                            
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
    
    // MARK: - Auto Rotation
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPage = (currentPage + 1) % interestPages.count
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
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 28))
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.8 : 0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
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

