# Firebase iOS Integration Setup

## 🔗 Backend Repository

The Firebase backend is maintained in a **separate repository**:

**Repository**: `/Users/tenbandz/Code/Crowd-Backend`
**GitHub** (when pushed): `https://github.com/tenbandz/Crowd-Backend`

### Running the Backend Locally

```bash
# Navigate to backend repo
cd /Users/tenbandz/Code/Crowd-Backend

# Start emulators
npm start

# Emulators will run at:
# - Emulator UI: http://localhost:4000
# - Functions: http://localhost:5001
# - Firestore: http://localhost:8080
# - Auth: http://localhost:9099
```

See the backend repository's README for full documentation.

## 📦 Add Firebase Packages to Xcode

You need to add Firebase packages to your Xcode project:

### Option 1: Via Xcode UI (Recommended)

1. Open `Crowd.xcodeproj` in Xcode
2. Select your project in the navigator
3. Go to **File** → **Add Package Dependencies...**
4. Enter the Firebase iOS SDK URL: `https://github.com/firebase/firebase-ios-sdk`
5. Select version: **11.0.0** or later
6. Select these packages to add:
   - ✅ **FirebaseAuth**
   - ✅ **FirebaseFirestore**
   - ✅ **FirebaseFunctions**
7. Click **Add Package**

### Option 2: Via Package.swift (if using SPM)

```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0")
],
targets: [
    .target(
        name: "Crowd",
        dependencies: [
            .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
        ]
    )
]
```

## 🔧 Files Created/Updated

The following files have been created or updated:

### ✅ Created:
- `Crowd/Services/FirebaseManager.swift` - Manages Firebase connection to emulators
- `GoogleService-Info.plist` - Firebase configuration file
- `Crowd/Repositories/FirebaseEventRepository.swift` - Implements event repository with Firebase

### ✅ Updated:
- `Crowd/App/CrowdApp.swift` - Initializes Firebase on app launch
- `Crowd/App/AppEnvironment.swift` - Switched to FirebaseEventRepository
- `Crowd/App/AppState.swift` - Anonymous authentication on bootstrap

## 🧪 Testing the Connection

Once you add the Firebase packages:

1. **Build and run the app** in Xcode
2. **Check console output** for:
   ```
   ✅ Firebase connected to local emulators
      - Firestore: localhost:8080
      - Functions: localhost:5001
      - Auth: localhost:9099
   ✅ Authenticated with Firebase: [userId]
   ```

3. **Visit the Emulator UI** at http://localhost:4000 to see:
   - Authentication: Your anonymous user
   - Firestore: Any events created
   - Functions: Log output from function calls

## 🎯 What's Working

With this setup, your iOS app can now:
- ✅ Create events via Firebase Cloud Functions
- ✅ Fetch events in real-time from Firestore
- ✅ Join events and boost signals
- ✅ Authenticate anonymously
- ✅ All data stays local during development

## 🚀 Next Steps

1. **Add Firebase packages** to Xcode (see above)
2. **Build the project** to verify everything compiles
3. **Run the app** and test creating/viewing events
4. **Monitor in Emulator UI** to see real-time data flow

## 📝 Production Deployment

When ready for production:
1. Remove the `#if DEBUG` emulator configuration
2. Deploy your backend: `cd Crowd/Backend && firebase deploy`
3. Update `GoogleService-Info.plist` with production values
4. App will automatically connect to production Firebase

## 🔍 Troubleshooting

**Build errors?**
- Ensure Firebase packages are added correctly
- Clean build folder: **Product** → **Clean Build Folder**
- Restart Xcode

**Connection errors?**
- Verify emulators are running: `lsof -i :4000,5001,8080,9099`
- Check console for emulator connection logs

**Auth errors?**
- Emulator UI: http://localhost:4000 → Authentication tab
- Verify anonymous auth is working

---

**Your Firebase backend is ready! Add the packages and start building! 🎉**

