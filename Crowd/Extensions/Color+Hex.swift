//
//  Color+Hex.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI

extension Color {
    /// Initialize a Color from a 0xRRGGBB (or 0xAARRGGBB) integer.
    init(hex: UInt32) {
        let a, r, g, b: Double
        if hex > 0xFFFFFF {
            a = Double((hex & 0xFF00_0000) >> 24) / 255.0
            r = Double((hex & 0x00FF_0000) >> 16) / 255.0
            g = Double((hex & 0x0000_FF00) >> 8)  / 255.0
            b = Double( hex & 0x0000_00FF)       / 255.0
        } else {
            a = 1.0
            r = Double((hex & 0x00FF_0000) >> 16) / 255.0
            g = Double((hex & 0x0000_FF00) >> 8)  / 255.0
            b = Double( hex & 0x0000_00FF)       / 255.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
