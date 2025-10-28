//
//  CLLocationCoordinate2D+Geohash.swift
//  Crowd
//
//  Created by AI Assistant
//

import CoreLocation

extension CLLocationCoordinate2D {
    /// Generates a geohash for this coordinate
    /// - Parameter precision: Length of the geohash string (default 6 = ~600m precision)
    /// - Returns: Geohash string
    func geohash(precision: Int = 6) -> String {
        let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        var lat = (latitude + 90.0, 0.0, 180.0)  // (value, min, max)
        var lon = (longitude + 180.0, 0.0, 360.0)
        
        var hash = ""
        var isEven = true
        var bits = 0
        var charIndex = 0
        
        while hash.count < precision {
            if isEven {
                // Process longitude
                let mid = (lon.1 + lon.2) / 2
                if lon.0 >= mid {
                    charIndex |= (1 << (4 - bits))
                    lon.1 = mid
                } else {
                    lon.2 = mid
                }
            } else {
                // Process latitude
                let mid = (lat.1 + lat.2) / 2
                if lat.0 >= mid {
                    charIndex |= (1 << (4 - bits))
                    lat.1 = mid
                } else {
                    lat.2 = mid
                }
            }
            
            isEven = !isEven
            bits += 1
            
            if bits == 5 {
                let index = base32.index(base32.startIndex, offsetBy: charIndex)
                hash.append(base32[index])
                bits = 0
                charIndex = 0
            }
        }
        
        return hash
    }
}

