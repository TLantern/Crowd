//
//  UserProfile.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI

struct UserProfile: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var auraPoints: Int
    var avatarColorHex: String
    var profileImageURL: String?
    
    // Computed property (not encoded/decoded)
    var avatarColor: Color {
        Color(hexString: avatarColorHex)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case auraPoints
        case avatarColorHex
        case profileImageURL
    }

    static let anonymous = UserProfile(
        id: "anon", 
        displayName: "Guest", 
        auraPoints: 0,
        avatarColorHex: "#808080",
        profileImageURL: nil
    )
}
