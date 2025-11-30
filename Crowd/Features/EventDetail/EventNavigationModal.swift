//
//  EventNavigationModal.swift
//  Crowd
//
//  Created by Teni Owojori on 10/27/25.
//

import SwiftUI
import CoreLocation
// import MapKit
import CoreMotion
import Combine
import FirebaseFirestore
import UIKit
import PhotosUI

// MARK: - Motion Manager for device heading
@MainActor
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var heading: Double = 0
    
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: .main
        ) { [weak self] motion, _ in
            guard let motion = motion else { return }
            
            let rawHeadingDeg = atan2(
                motion.magneticField.field.y,
                motion.magneticField.field.x
            ) * 180 / .pi
            
            let adjustedHeading = (rawHeadingDeg + 360)
                .truncatingRemainder(dividingBy: 360)
            
            self?.heading = adjustedHeading
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Event Navigation Modal
struct EventNavigationModal: View {
    let event: CrowdEvent
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var locationService = AppEnvironment.current.location
    @StateObject private var motionManager = MotionManager()
    
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var deviceHeading: Double = 0
    @State private var distanceToEvent: Double = 0
    @State private var bearingToEvent: Double = 0
    @State private var compassRotation: Double = 0
    @State private var locationUpdateTimer: Timer?
    
    @State private var currentUserId: String = "unknown"
    @State private var currentUserName: String = "Guest"
    @StateObject private var chatService = EventChatService.shared
    @State private var messageText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var selectedImageData: Data? = nil
    @State private var liveAttendeeCount: Int = 0
    @State private var eventListener: ListenerRegistration?
    @State private var selectedTab: TabSelection = .chat
    @State private var isSendingMessage = false
    @State private var showOnboarding = false
    @State private var onboardingStep: OnboardingStep = .chat
    
    enum TabSelection {
        case map
        case chat
    }
    
    enum OnboardingStep {
        case chat
        case map
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Full UNT green background
                Color(hex: 0x02853E)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar - compressed
                    VStack(spacing: 0) {
                        // Title row
                        ZStack {
                            MarqueeTitle(text: "\(eventEmoji) \(event.title)")
                                .padding(.horizontal, 5)
                        }
                        .frame(height: 32)
                        .padding(.bottom, 4)
                        
                        // Tab switcher row
                        HStack(spacing: 8) {
                            // Back button (left)
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 4)
                            
                            Spacer()
                            
                            // Tabs (center)
                            HStack(spacing: 0) {
                                TabButton(
                                    title: "Chat 💬",
                                    isSelected: selectedTab == .chat,
                                    action: { selectedTab = .chat }
                                )
                                
                                TabButton(
                                    title: "Map 📍",
                                    isSelected: selectedTab == .map,
                                    action: { selectedTab = .map }
                                )
                            }
                            .frame(height: 36)
                            .frame(width: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .padding(.top, 8)
                    .background(Color(hex: 0x02853E))
                    
                    // Full screen tab content
                    Group {
                        if selectedTab == .map {
                            MapTabView(
                                event: event,
                                userLocation: userLocation
                            )
                        } else {
                            ChatTabView(
                                eventId: event.id,
                                attendeeCount: liveAttendeeCount,
                                chatService: chatService,
                                messageText: $messageText,
                                selectedImage: $selectedImage,
                                selectedImageData: $selectedImageData,
                                sendMessage: sendMessage,
                                isSendingMessage: $isSendingMessage
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                }
                .navigationBarHidden(true)
                
                // Onboarding overlay
                if showOnboarding {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismissOnboarding()
                            }
                        
                        if onboardingStep == .chat {
                            EventNavigationOnboardingCard(
                                title: "Welcome to Chat 💬",
                                description: "Chat with people before they arrive at your crowd, or before you head to theirs.",
                                buttonText: "Next",
                                onAction: {
                                    onboardingStep = .map
                                    selectedTab = .map
                                }
                            )
                        } else {
                            EventNavigationOnboardingCard(
                                title: "Welcome to Map 📍",
                                description: "Use the map to see directions and navigate to the crowd.",
                                buttonText: "Got it!",
                                onAction: {
                                    dismissOnboarding()
                                }
                            )
                        }
                    }
                }
            }
        }
        // MARK: lifecycle / listeners
        .onAppear {
            // Check if onboarding should be shown
            if TutorialManager.shared.shouldShowEventNavigationOnboarding() {
                showOnboarding = true
                onboardingStep = .chat
            }
            
            // Track screen view
            AnalyticsService.shared.trackScreenView("event_navigation")
            
            // Initialize live attendee count
            liveAttendeeCount = event.attendeeCount
            
            // Start listening to event document for real-time attendee count
            startEventListener()
            
            // ensure user auth
            Task {
                var userId: String?
                
                if let existingUserId = FirebaseManager.shared.getCurrentUserId() {
                    userId = existingUserId
                    await MainActor.run {
                        currentUserId = existingUserId
                    }
                    // Fetch user profile for display name
                    do {
                        let profile = try await UserProfileService.shared.fetchProfile(userId: existingUserId)
                        await MainActor.run {
                            currentUserName = profile.displayName
                        }
                    } catch {
                        print("⚠️ EventNavigationModal: Failed to fetch profile: \(error)")
                    }
                } else {
                    do {
                        let newUserId = try await FirebaseManager.shared.signInAnonymously()
                        userId = newUserId
                        await MainActor.run {
                            currentUserId = newUserId
                        }
                        print("✅ EventNavigationModal: User signed in anonymously: \(newUserId)")
                    } catch {
                        print("❌ EventNavigationModal: Failed to sign in anonymously: \(error)")
                    }
                }
                
                // Start chat listening after userId is set
                if let finalUserId = userId {
                    await MainActor.run {
                        chatService.startListening(eventId: event.id, currentUserId: finalUserId)
                        // Mark messages as read when opening chat
                        ChatNotificationService.shared.markAsRead(eventId: event.id)
                    }
                }
            }
            
            startLocationUpdates()
            startMotionUpdates()
        }
        .onDisappear {
            stopLocationUpdates()
            stopMotionUpdates()
            chatService.stopListening()
            eventListener?.remove()
            eventListener = nil
        }
        .onChange(of: selectedTab) { _, newTab in
            // Mark messages as read when switching to chat tab
            if newTab == .chat {
                ChatNotificationService.shared.markAsRead(eventId: event.id)
            }
        }
        .onChange(of: chatService.messages.count) { _, _ in
            // Update last seen timestamp when new messages arrive (if on chat tab)
            if selectedTab == .chat, let lastMessage = chatService.messages.last {
                ChatNotificationService.shared.updateLastSeen(eventId: event.id, timestamp: lastMessage.timestamp)
            }
        }
        .onReceive(motionManager.$heading) { newHeading in
            deviceHeading = newHeading
        }
        .onAppear {
            if let loc = userLocation {
                updateDistanceAndBearing(
                    to: event.coordinates,
                    from: loc
                )
            }
        }
        .onChange(of: deviceHeading) { _, _ in
            updateCompassRotation()
        }
        .onChange(of: bearingToEvent) { _, _ in
            updateCompassRotation()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    // Swipe from left edge to right (standard iOS back gesture)
                    if value.translation.width > 100 && abs(value.translation.height) < 100 {
                        dismiss()
                    }
                }
        )
    } // ← THIS closes body
    
    // -------------------------
    // Everything below here is NOW outside `body`.
    // Compiler stops whining.
    // -------------------------
    
    // MARK: - Computed Props
    
    private var directionText: String {
        let direction = Int(bearingToEvent)
        switch direction {
        case 0..<22, 338...360: return "North"
        case 22..<67: return "Northeast"
        case 67..<112: return "East"
        case 112..<157: return "Southeast"
        case 157..<202: return "South"
        case 202..<247: return "Southwest"
        case 247..<292: return "West"
        case 292..<338: return "Northwest"
        default: return "Unknown"
        }
    }
    
    private var eventEmoji: String {
        TagEmoji.emoji(for: event.tags, fallbackCategory: event.category)
    }
    
    // MARK: - Location
    
    private func startLocationUpdates() {
        locationService.requestSoftAuth()
        locationService.startUpdatingLocation()
        
        // seed with last known
        if let currentLocation = locationService.lastKnown {
            userLocation = currentLocation
            updateDistanceAndBearing(
                to: event.coordinates,
                from: currentLocation
            )
        }
        
        // poll for new location every second
        locationUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { _ in
            if let newLocation = locationService.lastKnown {
                
                let oldLat = userLocation?.latitude ?? 0
                let oldLon = userLocation?.longitude ?? 0
                
                let movedEnough =
                    abs(newLocation.latitude - oldLat) > 0.0001 ||
                    abs(newLocation.longitude - oldLon) > 0.0001
                
                if userLocation == nil || movedEnough {
                    userLocation = newLocation
                    updateDistanceAndBearing(
                        to: event.coordinates,
                        from: newLocation
                    )
                }
            }
        }
    }
    
    private func stopLocationUpdates() {
        locationService.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    // MARK: - Motion
    
    private func startMotionUpdates() {
        motionManager.startUpdates()
    }
    
    private func stopMotionUpdates() {
        motionManager.stopUpdates()
    }
    
    // MARK: - Navigation math
    
    private func updateDistanceAndBearing(
        to eventCoord: CLLocationCoordinate2D,
        from userCoord: CLLocationCoordinate2D
    ) {
        let userLoc = CLLocation(
            latitude: userCoord.latitude,
            longitude: userCoord.longitude
        )
        let eventLoc = CLLocation(
            latitude: eventCoord.latitude,
            longitude: eventCoord.longitude
        )
        
        distanceToEvent = userLoc.distance(from: eventLoc)
        bearingToEvent = calculateBearing(
            from: userCoord,
            to: eventCoord
        )
        
        updateCompassRotation()
    }
    
    private func calculateBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2)
            - sin(lat1) * cos(lat2) * cos(dLon)
        
        let bearingDeg = atan2(y, x) * 180 / .pi
        
        return (bearingDeg + 360)
            .truncatingRemainder(dividingBy: 360)
    }
    
    private func updateCompassRotation() {
        compassRotation = bearingToEvent - deviceHeading
    }
    
    // MARK: - Event Listener
    
    private func startEventListener() {
        let db = FirebaseManager.shared.db
        
        // Try events collection first
        let eventRef = db.collection("events").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ EventNavigationModal: Error listening to event: \(error)")
                    // Try userEvents collection as fallback
                    tryUserEventsListener()
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                    print("📊 EventNavigationModal: Updated attendee count to \(attendeeCount)")
                } else if !(snapshot?.exists ?? false) {
                    // Document doesn't exist in events, try userEvents
                    tryUserEventsListener()
                }
            }
        }
    }
    
    private func tryUserEventsListener() {
        let db = FirebaseManager.shared.db
        eventListener?.remove()
        
        let eventRef = db.collection("userEvents").document(event.id)
        eventListener = eventRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ EventNavigationModal: Error listening to userEvent: \(error)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let attendeeCount = data["attendeeCount"] as? Int {
                    liveAttendeeCount = attendeeCount
                    print("📊 EventNavigationModal: Updated attendee count to \(attendeeCount)")
                }
            }
        }
    }
    
    // MARK: - Onboarding
    
    private func dismissOnboarding() {
        TutorialManager.shared.markEventNavigationOnboardingComplete()
        showOnboarding = false
    }
    
    // MARK: - Chat
    
    private func sendMessage() {
        // Prevent multiple simultaneous sends
        guard !isSendingMessage else {
            print("⚠️ EventNavigationModal: Already sending message, ignoring duplicate send")
            return
        }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageToSend = selectedImage
        let imageDataToSend = selectedImageData
        
        guard !text.isEmpty || imageToSend != nil else {
            print("⚠️ EventNavigationModal: Cannot send empty message (no text or image)")
            return
        }
        
        print("📤 EventNavigationModal: Sending message - text: '\(text)', hasImage: \(imageToSend != nil)")
        
        // Clear text and image immediately for better UX
        let messageToSend = text
        messageText = ""
        selectedImage = nil
        selectedImageData = nil
        
        isSendingMessage = true
        
        Task.detached(priority: .userInitiated) {
            do {
                let userId = await currentUserId
                let userName = await currentUserName
                
                print("📤 EventNavigationModal: Calling chatService.sendMessage with userId: \(userId), userName: \(userName)")
                
                try await chatService.sendMessage(
                    eventId: event.id,
                    text: messageToSend,
                    userId: userId,
                    userName: userName,
                    image: imageToSend,
                    imageData: imageDataToSend
                )
                
                print("✅ EventNavigationModal: Message sent successfully")
                
                // Track analytics on main thread
                await MainActor.run {
                    AnalyticsService.shared.trackMessageSent(eventId: event.id, messageLength: messageToSend.count)
                    ChatNotificationService.shared.updateLastSeen(eventId: event.id, timestamp: Date())
                    isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    print("❌ EventNavigationModal: Failed to send message: \(error)")
                    print("❌ EventNavigationModal: Error details: \(error.localizedDescription)")
                    // Restore message text and image on error
                    messageText = messageToSend
                    selectedImage = imageToSend
                    selectedImageData = imageDataToSend
                    isSendingMessage = false
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 6)
                .background(
                    isSelected
                    ? Color.white.opacity(0.3)
                    : Color.black.opacity(0.2)
                )
                .cornerRadius(10)
        }
    }
}

// MARK: - Map Tab View
struct MapTabView: View {
    let event: CrowdEvent
    let userLocation: CLLocationCoordinate2D?
    
    var body: some View {
        RouteMapView(
            destination: event.coordinates,
            userCoordinate: userLocation
        )
        .background(Color.white)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Chat Tab View
struct ChatTabView: View {
    let eventId: String
    let attendeeCount: Int
    @ObservedObject var chatService: EventChatService
    @Binding var messageText: String
    @Binding var selectedImage: UIImage?
    @Binding var selectedImageData: Data?
    let sendMessage: () -> Void
    @Binding var isSendingMessage: Bool
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedItem: PhotosPickerItem?
    @State private var attendees: [UserProfile] = []
    @State private var showParticipantList = false
    @State private var floatingEmojis: [FloatingEmoji] = []
    @State private var activityMessages: [String] = []
    @State private var currentActivityIndex = 0
    @State private var activityTimer: Timer?
    @State private var lastKnownAttendeeCount: Int = 0
    
    private let seedPrompts = [
        "Where y’all at?",
        "Anyone tryna link up?",
        "How’s the energy rn?",
        "Should I slide through?",
        "What did I miss?",
        "What's the vibe rn?",
        "Anyone pulling up?",
        "Who's there already?",
        "Is it packed or chill?"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // People Here Now
                    PeopleHereNowView(
                        attendees: attendees,
                        totalCount: attendeeCount,
                        onTap: { showParticipantList = true }
                    )
                    .padding(.top, 4)
                    .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.top, 6)
                    
                    // Live Activity Banner (hide after user sends first message)
                    if !activityMessages.isEmpty && !chatService.messages.contains(where: { $0.isCurrentUser }) {
                        LiveActivityBanner(
                            messages: activityMessages,
                            currentIndex: currentActivityIndex
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    
                    // Messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(chatService.messages) { message in
                                    ChatMessageBubble(
                                        message: message.text,
                                        imageURL: message.imageURL,
                                        author: message.userName,
                                        isCurrentUser: message.isCurrentUser,
                                        timestamp: message.timestamp
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .onChange(of: chatService.messages.count) { _, _ in
                            if let lastMessage = chatService.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            if focused, let lastMessage = chatService.messages.last {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                    .onTapGesture {
                        isTextFieldFocused = false
                    }
                    
                    // Bottom input area
                    VStack(spacing: 8) {
                        Divider()
                        
                        // Seed prompts row + Reaction bar (hide after user sends first message)
                        if !chatService.messages.contains(where: { $0.isCurrentUser }) {
                            SeedPromptsRow(
                                prompts: seedPrompts,
                                hasMessages: !chatService.messages.isEmpty,
                                onSelect: { prompt in
                                    messageText = prompt
                                    sendMessage()
                                }
                            )
                            
                            ReactionBar(onReact: { emoji in
                                triggerFloatingEmoji(emoji)
                                messageText = emoji
                                sendMessage()
                            })
                        }
                        
                        // Image preview
                        if let image = selectedImage {
                            HStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 100)
                                    .cornerRadius(8)
                                Button(action: {
                                    selectedImage = nil
                                    selectedImageData = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Message input
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $messageText)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(20)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    sendMessage()
                                    isTextFieldFocused = false
                                }
                            
                            Button(action: {
                                sendMessage()
                                isTextFieldFocused = false
                            }) {
                                if isSendingMessage {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) ? .gray : Color(hex: 0x02853E))
                                }
                            }
                            .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) || isSendingMessage)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .background(Color(uiColor: .systemBackground))
                    .offset(y: keyboardHeight > 0 ? -keyboardHeight : 0)
                }
                
                // Floating emojis overlay
                ForEach(floatingEmojis) { emoji in
                    FloatingEmojiView(emoji: emoji.emoji)
                        .position(emoji.position)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            lastKnownAttendeeCount = attendeeCount
            fetchAttendees()
            buildActivityMessages()
            startActivityRotation()
        }
        .onDisappear {
            activityTimer?.invalidate()
        }
        .onChange(of: attendeeCount) { oldValue, newValue in
            if newValue > oldValue {
                addActivityMessage("Someone just joined! 🎉")
            }
            lastKnownAttendeeCount = newValue
            buildActivityMessages()
        }
        .onChange(of: chatService.messages.count) { oldValue, newValue in
            if oldValue == 0 && newValue > 0 {
                addActivityMessage("First message sent! 💬")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .sheet(isPresented: $showParticipantList) {
            ParticipantListSheet(attendees: attendees, totalCount: attendeeCount)
        }
    }
    
    private func fetchAttendees() {
        Task {
            do {
                let fetchedAttendees = try await EventAttendeesService.shared.fetchAttendees(eventId: eventId)
                await MainActor.run {
                    attendees = fetchedAttendees
                    if let firstAttendee = fetchedAttendees.first {
                        addActivityMessage("\(firstAttendee.displayName) is here")
                    }
                }
            } catch {
                print("⚠️ ChatTabView: Failed to fetch attendees: \(error)")
            }
        }
    }
    
    private func buildActivityMessages() {
        var messages: [String] = []
        if attendeeCount > 0 {
            messages.append("\(attendeeCount) people here now")
        }
        messages.append("Ask what the vibe is rn 💬")
        activityMessages = messages
    }
    
    private func addActivityMessage(_ message: String) {
        if !activityMessages.contains(message) {
            activityMessages.insert(message, at: 0)
            currentActivityIndex = 0
        }
    }
    
    private func startActivityRotation() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            guard !activityMessages.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                currentActivityIndex = (currentActivityIndex + 1) % activityMessages.count
            }
        }
    }
    
    private func triggerFloatingEmoji(_ emoji: String) {
        let screenWidth = UIScreen.main.bounds.width
        let id = UUID()
        let startPosition = CGPoint(x: screenWidth / 2, y: UIScreen.main.bounds.height - 200)
        
        let floatingEmoji = FloatingEmoji(id: id, emoji: emoji, position: startPosition)
        floatingEmojis.append(floatingEmoji)
        
        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            floatingEmojis.removeAll { $0.id == id }
        }
    }
}

// MARK: - Floating Emoji Model
struct FloatingEmoji: Identifiable {
    let id: UUID
    let emoji: String
    var position: CGPoint
}

// MARK: - People Here Now View
struct PeopleHereNowView: View {
    let attendees: [UserProfile]
    let totalCount: Int
    let onTap: () -> Void
    
    private let avatarSize: CGFloat = 36
    private let maxAvatars = 8
    private let placeholderColors: [Color] = [
        Color(red: 0.68, green: 0.85, blue: 0.90),  // Pastel blue
        Color(red: 0.80, green: 0.70, blue: 0.90),  // Pastel purple
        Color(red: 1.00, green: 0.71, blue: 0.76),  // Pastel pink
        Color(red: 1.00, green: 0.85, blue: 0.70),  // Pastel peach
        Color(red: 0.70, green: 0.93, blue: 0.80),  // Pastel mint
        Color(red: 1.00, green: 0.95, blue: 0.70),  // Pastel yellow
        Color(red: 0.75, green: 0.85, blue: 1.00),  // Pastel periwinkle
        Color(red: 0.85, green: 0.75, blue: 0.85)   // Pastel lavender
    ]
    
    private var displayCount: Int {
        maxAvatars
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: -12) {
                ForEach(0..<displayCount, id: \.self) { index in
                    Group {
                        if index < attendees.count {
                            realAvatarView(attendees[index])
                        } else {
                            placeholderView(at: index)
                        }
                    }
                    .zIndex(Double(displayCount - index))
                }
                
                if totalCount > displayCount {
                    overflowBubble
                        .zIndex(0)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var overflowBubble: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text("+\(totalCount - displayCount)")
                    .font(.system(size: avatarSize * 0.35, weight: .semibold))
                    .foregroundColor(.primary)
            )
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
    
    private func realAvatarView(_ profile: UserProfile) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageURL = profile.profileImageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView(profile)
                }
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())
            } else {
                initialsView(profile)
            }
            
            // Green online dot
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .offset(x: 2, y: 2)
        }
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
    
    private func initialsView(_ profile: UserProfile) -> some View {
        Circle()
            .fill(profile.avatarColor.opacity(0.25))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(initials(from: profile.displayName))
                    .font(.system(size: avatarSize * 0.4, weight: .bold))
                    .foregroundColor(profile.avatarColor)
            )
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
    
    private func placeholderView(at index: Int) -> some View {
        let color = placeholderColors[index % placeholderColors.count]
        return Circle()
            .fill(color)
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: avatarSize * 0.45))
                    .foregroundColor(.white.opacity(0.6))
            )
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
    
    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
}

// MARK: - Live Activity Banner
struct LiveActivityBanner: View {
    let messages: [String]
    let currentIndex: Int
    
    var body: some View {
        if !messages.isEmpty {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text(messages[currentIndex % messages.count])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .id(currentIndex)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
        }
    }
}

// MARK: - Seed Prompts Row
struct SeedPromptsRow: View {
    let prompts: [String]
    let hasMessages: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.self) { prompt in
                    Button(action: { onSelect(prompt) }) {
                        Text(prompt)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .opacity(hasMessages ? 0.7 : 1.0)
    }
}

// MARK: - Reaction Bar
struct ReactionBar: View {
    let onReact: (String) -> Void
    private let emojis = ["🔥", "👀", "😈", "🙌", "😂"]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: { onReact(emoji) }) {
                    Text(emoji)
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Floating Emoji View
struct FloatingEmojiView: View {
    let emoji: String
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 40))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    offset = -150
                    opacity = 0
                    scale = 1.5
                }
            }
    }
}

// MARK: - Participant List Sheet
struct ParticipantListSheet: View {
    let attendees: [UserProfile]
    let totalCount: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(attendees) { attendee in
                        HStack(spacing: 12) {
                            if let imageURL = attendee.profileImageURL, !imageURL.isEmpty {
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(attendee.avatarColor.opacity(0.25))
                                        .overlay(
                                            Text(initials(from: attendee.displayName))
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(attendee.avatarColor)
                                        )
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(attendee.avatarColor.opacity(0.25))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(initials(from: attendee.displayName))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(attendee.avatarColor)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attendee.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                if let handle = attendee.handle {
                                    Text("@\(handle)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    }
                } header: {
                    Text("\(totalCount) people in this crowd")
                }
            }
            .navigationTitle("People Here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
}

// MARK: - Transport mode helper (temporarily disabled)
/*
private enum TransportMode: Hashable {
    case automobile
    case walking
    case transit
}
*/

// MARK: - Marquee Title
struct MarqueeTitle: View {
    let text: String
    private let speed: Double = 20 // points per second
    private let spacing: CGFloat = 40
    private let baseFontSize: CGFloat = 22
    private let padding: CGFloat = 8 // 4px on each side

    @State private var baseContentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var shouldAnimate: Bool = false
    @State private var calculatedFontSize: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                if shouldAnimate {
                    HStack(spacing: spacing) {
                        title
                        title
                    }
                    .offset(x: offset)
                    .onAppear { startAnimation(container: w) }
                } else {
                    HStack { Spacer(); title; Spacer() }
                }
            }
            .onAppear { 
                containerWidth = w
                updateFontSize()
            }
            .onChange(of: w) { _, newWidth in
                containerWidth = newWidth
                updateFontSize()
            }
        }
        .frame(height: 28)
    }

    private var title: some View {
        Text(text)
            .font(.system(size: calculatedFontSize, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
            .background(
                // Measure at base font size
                Text(text)
                    .font(.system(size: baseFontSize, weight: .bold))
                    .lineLimit(1)
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .onAppear {
                                    baseContentWidth = g.size.width
                                    updateFontSize()
                                }
                                .onChange(of: g.size.width) { _, newWidth in
                                    baseContentWidth = newWidth
                                    updateFontSize()
                                }
                        }
                    )
                    .hidden()
            )
    }
    
    private func updateFontSize() {
        guard containerWidth > 0, baseContentWidth > 0 else { return }
        let availableWidth = containerWidth - padding
        
        if baseContentWidth <= availableWidth {
            calculatedFontSize = baseFontSize
            shouldAnimate = false
        } else {
            // Scale down font size proportionally to fit
            let scaleFactor = availableWidth / baseContentWidth
            let minFontSize: CGFloat = 12
            calculatedFontSize = max(minFontSize, baseFontSize * scaleFactor)
            
            // Calculate actual width at the scaled font size
            let scaledWidth = baseContentWidth * (calculatedFontSize / baseFontSize)
            // Only animate if it still doesn't fit even at minimum size
            shouldAnimate = scaledWidth > availableWidth
        }
    }

    private func startAnimation(container: CGFloat) {
        let availableWidth = container - padding
        let scaledWidth = baseContentWidth * (calculatedFontSize / baseFontSize)
        guard scaledWidth > availableWidth else { return }
        let cycle = (scaledWidth + spacing) / speed
        withAnimation(.linear(duration: cycle).repeatForever(autoreverses: false)) {
            offset = -(scaledWidth + spacing)
        }
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: String
    let imageURL: String?
    let author: String
    let isCurrentUser: Bool
    let profileImageURL: String?
    let timestamp: Date?
    
    init(message: String, imageURL: String?, author: String, isCurrentUser: Bool, profileImageURL: String? = nil, timestamp: Date? = nil) {
        self.message = message
        self.imageURL = imageURL
        self.author = author
        self.isCurrentUser = isCurrentUser
        self.profileImageURL = profileImageURL
        self.timestamp = timestamp
    }
    
    private let avatarSize: CGFloat = 38
    
    private var initials: String {
        let parts = author.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first })
    }
    
    private var handleColor: Color {
        let colors: [Color] = [
            Color(red: 0.2, green: 0.5, blue: 0.8),   // Blue
            Color(red: 0.6, green: 0.3, blue: 0.7),   // Purple
            Color(red: 0.8, green: 0.3, blue: 0.5),   // Pink
            Color(red: 0.9, green: 0.5, blue: 0.2),   // Orange
            Color(red: 0.2, green: 0.6, blue: 0.6),   // Teal
            Color(red: 0.4, green: 0.3, blue: 0.7),   // Indigo
            Color(red: 0.3, green: 0.7, blue: 0.5),   // Mint
            Color(red: 0.2, green: 0.6, blue: 0.8)    // Cyan
        ]
        let hash = author.hashValue
        return colors[abs(hash) % colors.count]
    }
    
    private var formattedTimestamp: String {
        guard let timestamp = timestamp else { return "" }
        
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timeString = timeFormatter.string(from: timestamp)
        
        if calendar.isDate(timestamp, equalTo: now, toGranularity: .weekOfYear) {
            // Within this week - show day of week
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            return "\(dayFormatter.string(from: timestamp)) at \(timeString)"
        } else {
            // Not this week - show m/d/y
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/d/yy"
            return "\(dateFormatter.string(from: timestamp)) at \(timeString)"
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer()
                
                // Handle + Message content (handle at trailing edge)
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(author)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(handleColor)
                        
                        if timestamp != nil {
                            Text(formattedTimestamp)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let imageURL = imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 250, maxHeight: 300)
                                    .cornerRadius(12)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: 15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: 0x02853E))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                }
                
                // Avatar
                avatarView
            } else {
                // Avatar
                avatarView
                
                // Handle + Message content (handle at leading edge)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(author)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(handleColor)
                        
                        if timestamp != nil {
                            Text(formattedTimestamp)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let imageURL = imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 250, maxHeight: 300)
                                    .cornerRadius(12)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: 15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let profileURL = profileImageURL, !profileURL.isEmpty {
            AsyncImage(url: URL(string: profileURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsAvatar
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }
    
    private var initialsAvatar: some View {
        Circle()
            .fill(handleColor.opacity(0.2))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(initials)
                    .font(.system(size: avatarSize * 0.4, weight: .bold))
                    .foregroundColor(handleColor)
            )
    }
}

// MARK: - Live Indicator View
struct LiveIndicatorView: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseScale = 2.0
                }
            }
    }
}

// MARK: - Event Navigation Onboarding Card
struct EventNavigationOnboardingCard: View {
    let title: String
    let description: String
    let buttonText: String
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            // Description
            Text(description)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary.opacity(0.8))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action button
            Button(action: onAction) {
                Text(buttonText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: 0x02853E))
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 340)
    }
}

// MARK: - Preview
#Preview {
    EventNavigationModal(
        event: CrowdEvent.newDraft(
            at: .init(latitude: 33.2148, longitude: -97.1331),
            title: "Game Day Tailgate 🏈",
            hostId: "preview-host",
            hostName: "Preview Host",
            category: "Party",
            description: "Join us for the big game!",
            tags: ["tailgate", "sports"]
        )
    )
}
