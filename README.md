# Crowd

A location-based social iOS app for discovering and joining campus events in real-time.

## Overview

Crowd connects students through location-based events, allowing users to host parties, join nearby gatherings, and compete on leaderboards. The app uses real-time location tracking, geohash-based queries, and Firebase backend services to create a dynamic social experience.

## Features

- **Event Discovery**: Real-time map view of nearby events with heatmap visualization
- **Event Hosting**: Create events with categories, interests, and location
- **Location-Based Attendance**: Join events with GPS tracking and signal boosting
- **User Profiles**: Customizable profiles with interests, campus selection, and aura points
- **Leaderboard**: Rank users by aura points with timeframe filtering (today, week, month)
- **Real-Time Updates**: Live event updates using Firestore listeners
- **Analytics**: Comprehensive event tracking with Firebase Analytics
- **Notifications**: Push notifications for events and social interactions
- **Profile Gallery**: View events you've hosted or attended

## Tech Stack

### iOS App
- **Language**: Swift
- **Framework**: SwiftUI
- **Minimum iOS**: iOS 17+
- **Architecture**: MVVM with Repository pattern

### Backend
- **Platform**: Firebase
- **Services**:
  - Firebase Authentication (Anonymous)
  - Cloud Firestore (Database)
  - Cloud Functions (Backend logic)
  - Firebase Storage (Profile images)
  - Firebase Analytics (Event tracking)

## Project Structure

```
Crowd/
├── Crowd/                    # Main iOS app
│   ├── App/                  # App entry point and configuration
│   ├── Features/             # Feature modules
│   │   ├── Home/             # Main map and event views
│   │   ├── EventDetail/      # Event detail screens
│   │   ├── Host/             # Event creation
│   │   ├── Profile/          # User profile
│   │   ├── Leaderboard/      # Leaderboard views
│   │   └── Onboarding/       # User onboarding flow
│   ├── Services/             # Business logic services
│   ├── Repositories/         # Data layer abstraction
│   ├── Models/               # Data models
│   ├── Components/           # Reusable UI components
│   └── Extensions/           # Swift extensions
├── functions/                # Firebase Cloud Functions
├── firestore.rules          # Firestore security rules
└── storage.rules            # Storage security rules
```

## Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Node.js 20+ (for Firebase Functions)
- Firebase CLI installed globally
- CocoaPods or Swift Package Manager

## Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Crowd
```

### 2. Backend Setup

The Firebase backend is maintained in a separate repository:

**Backend Repository**: `/Users/tenbandz/Code/Crowd-Backend`

See `FIREBASE_SETUP.md` and `QUICK_START.md` for detailed backend setup instructions.

To run the backend locally:

```bash
cd /Users/tenbandz/Code/Crowd-Backend
npm install
npm start
```

The emulators will run at:
- **Emulator UI**: http://localhost:4000
- **Functions**: http://localhost:5001
- **Firestore**: http://localhost:8080
- **Auth**: http://localhost:9099

### 3. iOS App Setup

1. **Open the project**:
   ```bash
   open Crowd.xcodeproj
   ```

2. **Add Firebase Packages**:
   - In Xcode, go to **File** → **Add Package Dependencies...**
   - Enter: `https://github.com/firebase/firebase-ios-sdk`
   - Select version: **11.0.0** or later
   - Add these packages:
     - ✅ FirebaseAuth
     - ✅ FirebaseFirestore
     - ✅ FirebaseFunctions
     - ✅ FirebaseStorage
     - ✅ FirebaseAnalytics

3. **Configure Firebase**:
   - Ensure `GoogleService-Info.plist` is in the project root
   - The app automatically connects to emulators in DEBUG mode
   - Production endpoints are used in RELEASE mode

4. **Build and Run**:
   - Select a simulator or device
   - Press `Cmd + R` to build and run

## Development

### Running Locally

1. **Start Firebase Emulators** (in backend repo):
   ```bash
   cd /Users/tenbandz/Code/Crowd-Backend
   npm start
   ```

2. **Run iOS App**:
   - Open `Crowd.xcodeproj` in Xcode
   - Build and run on simulator or device

### Key Services

- **FirebaseManager**: Manages Firebase initialization and emulator connection
- **LocationService**: Handles GPS location tracking
- **PresenceService**: Sends location heartbeats every 30 seconds
- **UserProfileService**: User profile CRUD operations
- **AnalyticsService**: Event tracking and analytics
- **EventRepository**: Event data access layer

### Architecture

- **MVVM Pattern**: ViewModels manage state and business logic
- **Repository Pattern**: Abstracts data sources (Firebase/Mock)
- **Dependency Injection**: Services injected via `AppEnvironment`
- **Reactive Updates**: SwiftUI views update automatically on state changes

## Testing

See `TESTING_GUIDE_QUICK.md` and `PARTY_DATA_TESTING_GUIDE.md` for comprehensive testing instructions.

### Quick Test Checklist

- [ ] User onboarding creates profile in Firestore
- [ ] Event creation appears on map
- [ ] Joining event includes GPS coordinates
- [ ] Leaderboard displays real user data
- [ ] Profile updates persist to Firestore
- [ ] Event deletion works (host only)
- [ ] Real-time event updates work

## Deployment

### Production Deployment

1. **Deploy Backend**:
   ```bash
   cd /Users/tenbandz/Code/Crowd-Backend
   firebase deploy
   ```

2. **Update iOS App**:
   - Remove `#if DEBUG` emulator configuration in `FirebaseManager.swift`
   - Update `GoogleService-Info.plist` with production values
   - Build for release

3. **App Store**:
   - Archive in Xcode
   - Upload to App Store Connect
   - Submit for review

## Documentation

- `QUICK_START.md` - Quick setup guide
- `FIREBASE_SETUP.md` - Detailed Firebase configuration
- `BACKEND_INTEGRATION_COMPLETE.md` - Backend integration summary
- `NOTIFICATION_SYSTEM_COMPLETE.md` - Notification system details
- `PARTY_DATA_TESTING_GUIDE.md` - Event data testing guide
- `PROFILE_FIXES.md` - Profile feature documentation

## Known Limitations

- Chat functionality is stubbed (messages logged but not persisted)
- Friends system UI not yet implemented
- Presence cleanup (heartbeats don't expire automatically)
- Time-based leaderboard filtering prepared but not fully implemented

## Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## License

[Add your license here]

## Support

For issues or questions, please open an issue in the repository.
