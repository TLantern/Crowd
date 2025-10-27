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
    var handle: String?
    var bio: String?
    var campus: String?
    var interests: [String]
    var auraPoints: Int
    var avatarColorHex: String
    var profileImageURL: String?
    var hostedCount: Int
    var joinedCount: Int
    var friendsCount: Int
    var lastActive: Date?
    var createdAt: Date
    
    // Computed property (not encoded/decoded)
    var avatarColor: Color {
        Color(hexString: avatarColorHex)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case handle
        case bio
        case campus
        case interests
        case auraPoints
        case avatarColorHex
        case profileImageURL
        case hostedCount
        case joinedCount
        case friendsCount
        case lastActive
        case createdAt
    }

    static let anonymous = UserProfile(
        id: "anon", 
        displayName: "Guest",
        handle: nil,
        bio: nil,
        campus: nil,
        interests: [],
        auraPoints: 0,
        avatarColorHex: "#808080",
        profileImageURL: nil,
        hostedCount: 0,
        joinedCount: 0,
        friendsCount: 0,
        lastActive: nil,
        createdAt: Date()
    )
}
