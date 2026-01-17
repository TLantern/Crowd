//
//  VisibilityInfoSheet.swift
//  Crowd
//
//  Info sheet explaining visibility feature - shown only on first use
//

import SwiftUI

struct VisibilityInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image("Ghost")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    }
                    .padding(.top, 20)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Visibility Mode")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("See and be seen on the map")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(
                            icon: "eye.fill",
                            iconColor: .cyan,
                            title: "See Other Users",
                            description: "View other visible users on the map and tap to see their profiles"
                        )
                        
                        FeatureRow(
                            icon: "location.fill",
                            iconColor: .green,
                            title: "Share Your Location",
                            description: "Your approximate location becomes visible to others on the map"
                        )
                        
                        FeatureRow(
                            icon: "clock.fill",
                            iconColor: .orange,
                            title: "Auto-Expires in 6 Hours",
                            description: "Visibility automatically turns off after 6 hours for your privacy"
                        )
                        
                        FeatureRow(
                            icon: "hand.raised.fill",
                            iconColor: .purple,
                            title: "Toggle Anytime",
                            description: "Turn visibility on or off whenever you want"
                        )
                    }
                    .padding(.horizontal, 4)
                    
                    // Privacy note
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        
                        Text("Your exact location is never shared. Only your general area is visible to others.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Continue button
                    Button(action: {
                        dismiss()
                        onContinue()
                    }) {
                        Text("Turn On Visibility")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    .padding(.top, 8)
                    
                    // Cancel button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
            }
        }
        .presentationDetents([.height(680), .large])
        .presentationDragIndicator(.hidden)
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VisibilityInfoSheet(onContinue: {
        print("Continue tapped")
    })
}
