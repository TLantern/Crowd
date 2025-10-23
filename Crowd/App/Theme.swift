//
//  Theme.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

enum Theme {
    static let glassBlur: CGFloat = 20
    static let cornerXL: CGFloat = 24
    static let shadow = Color.black.opacity(0.25)
    
    static let gradientPrimary = LinearGradient(
        colors: [Color.purple, Color.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
