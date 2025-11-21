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
    @EnvironmentObject private var appState: AppState
    
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
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var isLeaving = false
    
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
                    // Top bar with close button
                    VStack(spacing: 0) {
                        ZStack {
                            Color(hex: 0x02853E)
                                .frame(height: 40)

                            // Center title: slow-moving marquee when long
                            MarqueeTitle(text: "\(eventEmoji) \(event.title)")
                                .padding(.horizontal, 5)
                                .padding(.bottom, 4)
                        }
                        .padding(.bottom, 4)
                        
                        // Tab switcher
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
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                        .background(Color(hex: 0x02853E))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Joined status row - centered
                        HStack {
                            Spacer()
                            HStack(spacing: 12) {
                                GlassPill(height: 32, horizontalPadding: 12) {
                                    Text("Joined")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                
                                Text("\(liveAttendeeCount)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Green live indicator
                                HStack(spacing: 4) {
                                    LiveIndicatorView()
                                    Text("LIVE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                            
                            // Leave event button (black door icon) and Close button (X circle)
                            HStack(spacing: 8) {
                                if AttendedEventsService.shared.isAttendingEvent(event.id) {
                                    Button(action: {
                                        leaveEvent()
                                    }) {
                                        Image("door")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.black)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .disabled(isLeaving)
                                }
                                
                                Button(action: { 
                                    dismiss() 
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 33, height: 33)
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.trailing, 16)
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0x02853E))
                    }
                    .padding(.top, 20)
                    
                    // Full screen tab content
                    Group {
                        if selectedTab == .map {
                            MapTabView(
                                event: event,
                                userLocation: userLocation
                            )
                        } else {
                            ChatTabView(
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
    
    // MARK: - Leave Event
    
    private func leaveEvent() {
        isLeaving = true
        Task {
            let success = await viewModel.leaveEvent(event: event)
            if success {
                // Clear currentJoinedEvent if it matches
                if appState.currentJoinedEvent?.id == event.id {
                    appState.currentJoinedEvent = nil
                }
                // Dismiss the modal after leaving
                dismiss()
            }
            isLeaving = false
        }
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
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    isSelected
                    ? Color.white.opacity(0.3)
                    : Color.black.opacity(0.2)
                )
                .cornerRadius(8)
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
    @ObservedObject var chatService: EventChatService
    @Binding var messageText: String
    @Binding var selectedImage: UIImage?
    @Binding var selectedImageData: Data?
    let sendMessage: () -> Void
    @Binding var isSendingMessage: Bool
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Show options list when there are no messages
                            if chatService.messages.isEmpty {
                                VStack(spacing: 20) {
                                    Spacer()
                                        .frame(height: UIScreen.main.bounds.height * 0.25)
                                    
                                    OptionsListView(
                                        optionsString: "What's the vibe right now?, Anyone trying to pull up together? , Who's there already, Is it packed or chill right now?",
                                        onOptionSelected: { option in
                                            messageText = option
                                            sendMessage()
                                        }
                                    )
                                    
                                    // Emoji bubbles row - centered
                                    HStack(spacing: 12) {
                                        Spacer()
                                        ForEach(["🔥", "👀", "😈", "🤝", "😂"], id: \.self) { emoji in
                                            BadgeView(
                                                title: emoji,
                                                onTap: {
                                                    messageText = emoji
                                                    sendMessage()
                                                }
                                            )
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    
                                    Spacer()
                                }
                            }
                            
                            LazyVStack(spacing: 12) {
                                ForEach(chatService.messages) { message in
                                    ChatMessageBubble(
                                        message: message.text,
                                        imageURL: message.imageURL,
                                        author: message.userName,
                                        isCurrentUser: message.isCurrentUser
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 60 : 0)
                    }
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
                
                Divider()
                
                // Image preview
                if let image = selectedImage {
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
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
                        .padding(.top, 8)
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                    }
                    .background(Color(uiColor: .systemBackground))
                }
                
                // Message input
                HStack(spacing: 12) {
                    // Image/GIF picker - commented out
                    /*
                    if #available(iOS 16.0, *) {
                        PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .livePhotos])) {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: 0x02853E))
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        selectedImageData = data
                                        selectedImage = UIImage(data: data)
                                    }
                                }
                            }
                        }
                    }
                    */
                    
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(20)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            print("⌨️ EventNavigationModal: TextField onSubmit triggered")
                            sendMessage()
                            isTextFieldFocused = false
                        }
                    
                    Button(action: {
                        print("🔘 EventNavigationModal: Send button tapped")
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
                .padding(.top, 12)
                .padding(.bottom, 32)
                .background(Color(uiColor: .systemBackground))
                .offset(y: keyboardHeight > 0 ? -keyboardHeight : 0)
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
    
    var body: some View {
        HStack(spacing: 8) {
            if isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
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
                Text(author)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0x02853E).opacity(0.15))
                    .cornerRadius(8)
            } else {
                Text(author)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0x02853E).opacity(0.15))
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 4) {
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
