//
//  UserProfile.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation

struct UserProfile: Codable, Equatable {
    var id: String
    var displayName: String
    var auraPoints: Int

    static let anonymous = UserProfile(id: "anon", displayName: "Guest", auraPoints: 0)
}
