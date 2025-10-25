# Crowd - Repository Structure

The Crowd project is split into **two independent repositories**:

## 📱 iOS App Repository

**Location**: `/Users/tenbandz/Code/Crowd`
**Contains**: 
- iOS app (Swift/SwiftUI)
- Firebase iOS SDK integration
- UI components and features
- Firebase connection configuration

**Key Files**:
- `Crowd/Services/FirebaseManager.swift` - Firebase connection manager
- `Crowd/Repositories/FirebaseEventRepository.swift` - Event repository implementation
- `GoogleService-Info.plist` - Firebase configuration
- `FIREBASE_SETUP.md` - Setup instructions
- `QUICK_START.md` - Quick reference guide

## 🔥 Backend Repository

**Location**: `/Users/tenbandz/Code/Crowd-Backend`
**GitHub** (when pushed): `https://github.com/tenbandz/Crowd-Backend`

**Contains**:
- Firebase Cloud Functions
- Firestore database rules and indexes
- GitHub Actions CI/CD
- Deployment automation
- Backend documentation

**Key Files**:
- `functions/` - All Cloud Functions code
- `firebase.json` - Firebase project configuration
- `firestore.rules` - Database security rules
- `package.json` - NPM scripts for development
- `scripts/` - Helper scripts

**Version**: `v1.0.0`

## 🔗 How They Connect

The iOS app connects to the backend via:

### Local Development
```swift
#if DEBUG
// Connects to localhost emulators
settings.host = "localhost:8080"
functions.useEmulator(withHost: "localhost", port: 5001)
#endif
```

**Emulator Ports**:
- Functions: `localhost:5001`
- Firestore: `localhost:8080`
- Auth: `localhost:9099`
- Emulator UI: `localhost:4000`

### Production
- Uses Firebase Cloud endpoints
- Configured via `GoogleService-Info.plist`
- Project ID: `crowd-6193c`

## 🚀 Development Workflow

### 1. Start Backend

```bash
cd /Users/tenbandz/Code/Crowd-Backend
npm start
```

Visit http://localhost:4000 for Emulator UI

### 2. Run iOS App

```bash
cd /Users/tenbandz/Code/Crowd
# Open Crowd.xcodeproj in Xcode
# Build and run
```

The app will automatically connect to local emulators in DEBUG mode.

## 📦 Dependencies

### iOS App Requires:
- Xcode 15+
- Swift 5.9+
- Firebase iOS SDK (add via SPM):
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseFunctions

### Backend Requires:
- Node.js 18+
- Firebase CLI
- Java 17+ (for Firestore emulator)

## 🔄 Deployment

### Backend
```bash
cd /Users/tenbandz/Code/Crowd-Backend
npm run deploy
```

Or push to `main` branch for automatic deployment via GitHub Actions.

### iOS App
- Build and submit via Xcode
- No backend code changes needed
- Automatically connects to production Firebase

## 📝 Making Changes

### Backend API Changes
1. Update code in `Crowd-Backend/functions/`
2. Test with emulators
3. Update iOS app if API changed
4. Deploy backend
5. Release iOS app update

### iOS-Only Changes
1. Update iOS code
2. Test with local backend emulators
3. No backend deployment needed
4. Release app

## 🗂️ File Organization

```
/Users/tenbandz/Code/
├── Crowd/                      # iOS App Repository
│   ├── Crowd/
│   │   ├── App/
│   │   ├── Features/
│   │   ├── Services/
│   │   │   └── FirebaseManager.swift
│   │   ├── Repositories/
│   │   │   └── FirebaseEventRepository.swift
│   │   └── ...
│   ├── GoogleService-Info.plist
│   ├── FIREBASE_SETUP.md
│   └── QUICK_START.md
│
└── Crowd-Backend/              # Backend Repository
    ├── functions/
    │   ├── events.js
    │   ├── users.js
    │   ├── signals.js
    │   └── points.js
    ├── firestore.rules
    ├── firebase.json
    ├── package.json
    ├── scripts/
    └── README.md
```

## 🤝 Collaboration

### For iOS Developers
- Clone iOS repo
- Clone backend repo separately
- Start backend emulators for testing
- No need to modify backend code

### For Backend Developers
- Clone backend repo
- Make changes to Cloud Functions
- Test with emulators
- Deploy when ready
- Coordinate API changes with iOS team

### For Full-Stack
- Clone both repos
- Modify both as needed
- Test end-to-end locally
- Deploy backend first, then iOS

## 📖 Documentation

- **iOS Setup**: `FIREBASE_SETUP.md` (in iOS repo)
- **Backend Setup**: `README.md` (in backend repo)
- **Deployment**: `DEPLOYMENT.md` (in backend repo)
- **Quick Start**: `QUICK_START.md` (in iOS repo)

## ✅ Benefits of Separation

1. **Independent Development**: Backend and iOS teams can work independently
2. **Separate Version Control**: Different release cycles
3. **CI/CD Automation**: Backend deploys automatically
4. **Clear Boundaries**: Clean separation of concerns
5. **Reusability**: Backend can support multiple clients (iOS, Android, Web)

---

**iOS Repo Version**: Current commit `fc7fb4e`
**Backend Repo Version**: `v1.0.0` (commit `7823eeb`)
**Last Updated**: October 2025

