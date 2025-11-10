//
//  AppRatingService.swift
//  Crowd
//
//  Created on 10/27/25.
//

import Foundation
import StoreKit
import UIKit

@MainActor
final class AppRatingService {
    static let shared = AppRatingService()
    
    private let userDefaults = UserDefaults.standard
    private let hasRequestedRatingKey = "has_requested_app_rating"
    
    private init() {}
    
    /// Request app rating if this is the user's first event join or creation
    func requestRatingIfNeeded(isFirstEvent: Bool) {
        // Only show rating prompt once
        guard !hasRequestedRating() else {
            print("📱 App rating already requested, skipping")
            return
        }
        
        // Only show for first event
        guard isFirstEvent else {
            return
        }
        
        // Mark as requested before showing (to prevent multiple prompts)
        markAsRequested()
        
        // Small delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                print("⭐ Requested app rating for first event")
            }
        }
    }
    
    private func hasRequestedRating() -> Bool {
        return userDefaults.bool(forKey: hasRequestedRatingKey)
    }
    
    private func markAsRequested() {
        userDefaults.set(true, forKey: hasRequestedRatingKey)
    }
}

