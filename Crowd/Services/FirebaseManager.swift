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

final class FirebaseManager {
    static let shared = FirebaseManager()
    
    let db: Firestore
    let functions: Functions
    let auth: Auth
    
    private init() {
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        self.db = Firestore.firestore()
        self.functions = Functions.functions()
        self.auth = Auth.auth()
        
        // Connect to emulators for local development
        #if DEBUG
        connectToEmulators()
        #endif
    }
    
    private func connectToEmulators() {
        // Firestore emulator
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        db.settings = settings
        
        // Functions emulator
        functions.useEmulator(withHost: "localhost", port: 5001)
        
        // Auth emulator
        auth.useEmulator(withHost: "localhost", port: 9099)
        
        print("✅ Firebase connected to local emulators")
        print("   - Firestore: localhost:8080")
        print("   - Functions: localhost:5001")
        print("   - Auth: localhost:9099")
    }
    
    // MARK: - Authentication Helper
    
    func signInAnonymously() async throws -> String {
        let result = try await auth.signInAnonymously()
        return result.user.uid
    }
    
    func getCurrentUserId() -> String? {
        return auth.currentUser?.uid
    }
}

