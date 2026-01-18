//
//  LocationPinView.swift
//  Crowd
//
//  Custom annotation view for location pins with distance display
//

import SwiftUI

struct LocationPinView: View {
    let name: String
    let distance: Double?
    
    var body: some View {
        VStack(spacing: 4) {
            // Distance label (above pin)
            if let distance = distance {
                Text(formatDistance(distance))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
            
            // Pin icon
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f|m", meters)
        } else {
            return String(format: "%.1f|km", meters / 1000)
        }
    }
}
