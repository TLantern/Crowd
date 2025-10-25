//
//  AppState.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import Combine
import MapKit

@MainActor
final class AppState: ObservableObject {
    @Published var sessionUser: UserProfile? = .anonymous
    @Published var selectedRegion: CampusRegion = .mainCampus
    @Published var camera: MapCameraPosition = .automatic
    @Published var unreadRewardNotice: Bool = false

    func bootstrap() async {
        // Authenticate anonymously with Firebase
        do {
            let userId = try await FirebaseManager.shared.signInAnonymously()
            print("✅ Authenticated with Firebase: \(userId)")
        } catch {
            print("⚠️ Firebase auth failed: \(error.localizedDescription)")
        }
        // preload regions, request location (soft), warm caches
    }
}
