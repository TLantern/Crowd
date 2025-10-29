//
//  UserStatsService.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class UserStatsService: ObservableObject {
    static let shared = UserStatsService()
    
    @Published var hostedCount: Int = 0
    @Published var joinedCount: Int = 0
    @Published var upcomingCount: Int = 0
    
    private let db = FirebaseManager.shared.db
    private var hostedListener: ListenerRegistration?
    private var joinedListener: ListenerRegistration?
    private var upcomingListener: ListenerRegistration?
    
    private init() {}
    
    func startListening(userId: String) {
        stopListening()
        
        // Listen to hosted events
        hostedListener = db.collection("userEvents")
            .whereField("hostId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error listening to hosted events: \(error)")
                        return
                    }
                    
                    self?.hostedCount = snapshot?.documents.count ?? 0
                    print("📊 Hosted events count: \(self?.hostedCount ?? 0)")
                }
            }
        
        // Listen to joined events (from attended events service)
        joinedListener = db.collection("userAttendances")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error listening to joined events: \(error)")
                        return
                    }
                    
                    self?.joinedCount = snapshot?.documents.count ?? 0
                    print("📊 Joined events count: \(self?.joinedCount ?? 0)")
                }
            }
        
        // Listen to upcoming events (future events user is attending)
        let now = Date()
        upcomingListener = db.collection("userAttendances")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error listening to upcoming events: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.upcomingCount = 0
                        return
                    }
                    
                    // Count upcoming events by checking event start times
                    var upcomingCount = 0
                    for document in documents {
                        let data = document.data()
                        if let eventId = data["eventId"] as? String {
                            // Fetch event details to check start time
                            do {
                                let eventDoc = try await self?.db.collection("userEvents").document(eventId).getDocument()
                                if let eventData = eventDoc?.data(),
                                   let startsAt = eventData["startsAt"] as? Timestamp {
                                    let eventStartTime = startsAt.dateValue()
                                    if eventStartTime > now {
                                        upcomingCount += 1
                                    }
                                }
                            } catch {
                                print("❌ Error fetching event details: \(error)")
                            }
                        }
                    }
                    
                    self?.upcomingCount = upcomingCount
                    print("📊 Upcoming events count: \(upcomingCount)")
                }
            }
    }
    
    func stopListening() {
        hostedListener?.remove()
        joinedListener?.remove()
        upcomingListener?.remove()
        hostedListener = nil
        joinedListener = nil
        upcomingListener = nil
    }
    
    // Alternative approach: fetch counts once
    func fetchStats(userId: String) async {
        do {
            // Fetch hosted count
            let hostedSnapshot = try await db.collection("userEvents")
                .whereField("hostId", isEqualTo: userId)
                .getDocuments()
            hostedCount = hostedSnapshot.documents.count
            
            // Fetch joined count
            let joinedSnapshot = try await db.collection("userAttendances")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            joinedCount = joinedSnapshot.documents.count
            
            // Fetch upcoming count
            let now = Date()
            var upcomingCount = 0
            for document in joinedSnapshot.documents {
                let data = document.data()
                if let eventId = data["eventId"] as? String {
                    do {
                        let eventDoc = try await db.collection("userEvents").document(eventId).getDocument()
                        if let eventData = eventDoc.data(),
                           let startsAt = eventData["startsAt"] as? Timestamp {
                            let eventStartTime = startsAt.dateValue()
                            if eventStartTime > now {
                                upcomingCount += 1
                            }
                        }
                    } catch {
                        print("❌ Error fetching event details: \(error)")
                    }
                }
            }
            self.upcomingCount = upcomingCount
            
            print("📊 Stats fetched - Hosted: \(hostedCount), Joined: \(joinedCount), Upcoming: \(upcomingCount)")
            
        } catch {
            print("❌ Error fetching user stats: \(error)")
        }
    }
}
