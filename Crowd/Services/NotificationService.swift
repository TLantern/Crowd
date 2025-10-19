//
//  NotificationService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import UserNotifications

final class NotificationService {
    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
}
