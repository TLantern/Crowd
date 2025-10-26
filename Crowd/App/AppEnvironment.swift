//
//  AppEnvironment.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import SwiftUI

struct AppEnvironment {
    let config: Config
    let eventRepo: EventRepository
    let analytics: AnalyticsService
    let presence: PresenceService
    let location: LocationService
    let notifications: NotificationService
    let shareLink: ShareLinkService

    static let current: AppEnvironment = {
        let config = Config.build()
        return AppEnvironment(
            config: config,
            eventRepo: FirebaseEventRepository(),  // Connected to local emulators
            analytics: AnalyticsService(),
            presence: PresenceService(),
            location: LocationService(),
            notifications: NotificationService(),
            shareLink: ShareLinkService()
        )
    }()
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .current
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
