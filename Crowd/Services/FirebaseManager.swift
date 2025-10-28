//
//  FirebaseManager.swift
//  Crowd
//
//  Created by Teni Owojori on 10/24/25.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth
import FirebaseAnalytics
import FirebaseMessaging

final class FirebaseManager {
    static let shared = FirebaseManager()
    
    let db: Firestore
    let functions: Functions
    let auth: Auth
    
    private init() {
        print("🔧 FirebaseManager: Starting initialization...")
        
        // CRITICAL: Configure Firebase first
        if FirebaseApp.app() == nil {
            print("🔧 FirebaseManager: Configuring Firebase...")
            FirebaseApp.configure()
            print("✅ FirebaseManager: Firebase configured")
        } else {
            print("✅ FirebaseManager: Firebase already configured")
        }
        
        // Emulators disabled - connecting to Cloud Firebase
        // Uncomment the block below to use local emulators instead
        /*
        #if DEBUG
        print("🔧 FirebaseManager: DEBUG mode - configuring emulators...")
        
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        print("   ✓ Auth emulator configured: 127.0.0.1:9099")
        
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.host = "127.0.0.1:8080"
        firestoreSettings.cacheSettings = MemoryCacheSettings()
        firestoreSettings.isSSLEnabled = false
        Firestore.firestore().settings = firestoreSettings
        print("   ✓ Firestore emulator configured: 127.0.0.1:8080")
        
        Functions.functions().useEmulator(withHost: "127.0.0.1", port: 5001)
        print("   ✓ Functions emulator configured: 127.0.0.1:5001")
        
        print("✅ Firebase emulators configured")
        #endif
        */
        
        // Create service references (will use Cloud Firebase)
        self.db = Firestore.firestore()
        self.functions = Functions.functions()
        self.auth = Auth.auth()
        
        print("✅ FirebaseManager: All services initialized")
        print("🌐 Connected to Cloud Firebase (Production)")
    }
    
    // MARK: - Authentication Helper
    
    func signInAnonymously() async throws -> String {
        print("🔧 FirebaseManager: Attempting anonymous sign in...")
        print("   - Auth instance: \(auth)")
        print("   - Current user before sign in: \(auth.currentUser?.uid ?? "nil")")
        
        do {
            let result = try await auth.signInAnonymously()
            print("✅ FirebaseManager: Anonymous sign in successful")
            print("   - User ID: \(result.user.uid)")
            return result.user.uid
        } catch {
            print("❌ FirebaseManager: Anonymous sign in failed")
            print("   - Error: \(error)")
            print("   - Error domain: \((error as NSError).domain)")
            print("   - Error code: \((error as NSError).code)")
            throw error
        }
    }
    
    func getCurrentUserId() -> String? {
        return auth.currentUser?.uid
    }
    
    // MARK: - Push Notifications Helper
    
    func getFCMToken() -> String? {
        return Messaging.messaging().fcmToken
    }
}

