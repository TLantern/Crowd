//
//  FirebaseEventRepository.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import Foundation
import CoreLocation

/// Backend API Event Repository - connects to our Node.js backend
actor BackendEventRepository: EventRepository {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://localhost:3000/api") {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }
    
    func fetchEvents(in region: CampusRegion) async throws -> [CrowdEvent] {
        let spec = await region.spec
        let center = spec.center
        
        guard let url = URL(string: "\(baseURL)/events?latitude=\(center.latitude)&longitude=\(center.longitude)&radius=600") else {
            throw CrowdError.networkError("Invalid URL")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CrowdError.networkError("Failed to fetch events")
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<[CrowdEvent]>.self, from: data)
        
        guard apiResponse.success else {
            throw CrowdError.networkError("API returned error")
        }
        
        return apiResponse.data
    }
    
    func create(event: CrowdEvent) async throws {
        guard let url = URL(string: "\(baseURL)/events") else {
            throw CrowdError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let eventData = try JSONEncoder().encode(event)
        request.httpBody = eventData
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw CrowdError.networkError("Failed to create event")
        }
    }
    
    func join(eventId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/events/\(eventId)/join") else {
            throw CrowdError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let joinData = ["userId": userId]
        let data = try JSONSerialization.data(withJSONObject: joinData)
        request.httpBody = data
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CrowdError.networkError("Failed to join event")
        }
    }
    
    func boostSignal(eventId: String, delta: Int) async throws {
        guard let url = URL(string: "\(baseURL)/events/\(eventId)/boost") else {
            throw CrowdError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let boostData = ["userId": "anon", "delta": delta] as [String : Any]
        let data = try JSONSerialization.data(withJSONObject: boostData)
        request.httpBody = data
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CrowdError.networkError("Failed to boost signal")
        }
    }
}

// MARK: - API Response Models

private struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let error: String?
}

// MARK: - WebSocket Service for Real-time Updates

import SocketIO

class BackendSocketService: ObservableObject {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    @Published var isConnected = false
    @Published var events: [CrowdEvent] = []
    
    init(baseURL: String = "http://localhost:3000") {
        setupSocket(baseURL: baseURL)
    }
    
    private func setupSocket(baseURL: String) {
        guard let url = URL(string: baseURL) else { return }
        
        manager = SocketManager(socketURL: url, config: [.log(true), .compress])
        socket = manager?.defaultSocket
        
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = true
            }
            print("✅ Connected to backend")
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
            print("❌ Disconnected from backend")
        }
        
        socket?.on("event_updated") { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.handleEventUpdate(data)
            }
        }
        
        socket?.on("new_event") { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.handleNewEvent(data)
            }
        }
        
        socket?.on("points_earned") { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.handlePointsEarned(data)
            }
        }
        
        socket?.connect()
    }
    
    func authenticate(userId: String) {
        socket?.emit("authenticate", ["userId": userId])
    }
    
    func joinEvent(eventId: String, userId: String, location: CLLocationCoordinate2D? = nil) {
        var data: [String: Any] = ["eventId": eventId, "userId": userId]
        if let location = location {
            data["location"] = ["latitude": location.latitude, "longitude": location.longitude]
        }
        socket?.emit("join_event", data)
    }
    
    func leaveEvent(eventId: String, userId: String) {
        socket?.emit("leave_event", ["eventId": eventId, "userId": userId])
    }
    
    func boostSignal(eventId: String, userId: String, delta: Int) {
        socket?.emit("boost_signal", ["eventId": eventId, "userId": userId, "delta": delta])
    }
    
    func updateLocation(userId: String, latitude: Double, longitude: Double) {
        socket?.emit("location_update", ["userId": userId, "latitude": latitude, "longitude": longitude])
    }
    
    private func handleEventUpdate(_ data: [Any]) {
        guard let eventData = data.first as? [String: Any],
              let eventId = eventData["eventId"] as? String else { return }
        
        // Update local events array
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            if let attendeeCount = eventData["attendeeCount"] as? Int {
                events[index].attendeeCount = attendeeCount
            }
            if let signalStrength = eventData["signalStrength"] as? Int {
                events[index].signalStrength = signalStrength
            }
        }
    }
    
    private func handleNewEvent(_ data: [Any]) {
        guard let eventData = data.first as? [String: Any] else { return }
        
        // Add new event to local array
        // Note: You'll need to decode the event data properly
        print("New event received: \(eventData)")
    }
    
    private func handlePointsEarned(_ data: [Any]) {
        guard let pointsData = data.first as? [String: Any] else { return }
        
        // Handle points earned notification
        print("Points earned: \(pointsData)")
    }
    
    deinit {
        socket?.disconnect()
    }
}

// MARK: - Update AppEnvironment to use Backend

extension AppEnvironment {
    static let current: AppEnvironment = {
        let config = Config.build()
        return AppEnvironment(
            config: config,
            eventRepo: BackendEventRepository(),  // Use backend instead of mock
            analytics: AnalyticsService(),
            presence: PresenceService(),
            location: LocationService(),
            notifications: NotificationService(),
            shareLink: ShareLinkService()
        )
    }()
}
