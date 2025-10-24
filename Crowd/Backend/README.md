# Crowd Firebase Backend

This Firebase backend provides real-time synchronization and backend logic for the Crowd iOS app. It includes Firestore database, Cloud Functions, and Firebase Authentication integration.

## 🏗️ Architecture

- **Firestore**: Main database with real-time synchronization
- **Cloud Functions**: Backend logic and triggers
- **Firebase Authentication**: User access control
- **Real-time Updates**: Seamless sync with iOS frontend

## 📁 Project Structure

```
Backend/
├── firebase.json                 # Firebase project configuration
├── firestore.rules              # Database security rules
├── firestore.indexes.json       # Database indexes for performance
├── firebase-config.example      # Environment configuration template
├── functions/                   # Cloud Functions
│   ├── package.json            # Node.js dependencies
│   ├── index.js               # Main functions entry point
│   ├── users.js               # User CRUD operations
│   ├── events.js              # Event CRUD operations
│   ├── signals.js             # Signal CRUD operations
│   ├── points.js              # Points CRUD operations
│   └── .eslintrc.js           # Code linting configuration
└── README.md                   # This documentation
```

## 🚀 Quick Setup

### Prerequisites

1. **Node.js** (v18 or higher)
2. **Firebase CLI**: `npm install -g firebase-tools`
3. **Firebase Project** with Firestore, Authentication, and Cloud Functions enabled

### 1. Initialize Firebase Project

```bash
# Navigate to the Backend directory
cd Crowd/Backend

# Login to Firebase
firebase login

# Initialize Firebase project
firebase init
```

During initialization, select:
- ✅ Firestore: Configure security rules and indexes
- ✅ Functions: Configure a Cloud Functions directory
- ✅ Use existing project or create new one

### 2. Configure Environment

```bash
# Copy the configuration template
cp firebase-config.example .env

# Edit .env with your Firebase project details
# Get these values from Firebase Console > Project Settings > Service Accounts
```

### 3. Install Dependencies

```bash
cd functions
npm install
cd ..
```

### 4. Deploy to Firebase

```bash
# Deploy Firestore rules and indexes
firebase deploy --only firestore

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy everything
firebase deploy
```

## 📊 Database Collections

### Users Collection
- **Purpose**: Store user profiles and authentication data
- **Fields**: `id`, `displayName`, `auraPoints`, `createdAt`, `updatedAt`
- **Security**: Users can only access their own data

### Events Collection
- **Purpose**: Store crowd events and location data
- **Fields**: `id`, `title`, `hostId`, `latitude`, `longitude`, `radiusMeters`, `startsAt`, `endsAt`, `signalStrength`, `attendeeCount`, `tags`
- **Security**: Public read, authenticated write, host-only updates

### Signals Collection
- **Purpose**: Store user signals/participation in events
- **Fields**: `id`, `userId`, `eventId`, `signalStrength`, `createdAt`, `updatedAt`
- **Security**: Users can only manage their own signals

### Points Collection
- **Purpose**: Store user points and rewards
- **Fields**: `id`, `userId`, `points`, `reason`, `createdAt`, `updatedAt`
- **Security**: Users can only read their own points

## 🔧 Cloud Functions

### User Functions
- `createUser`: Create new user profile
- `updateUser`: Update user profile
- `deleteUser`: Delete user profile
- `getUser`: Get user profile
- `onUserCreate`: Trigger when user is created (awards welcome bonus)
- `onUserUpdate`: Trigger when user is updated
- `onUserDelete`: Trigger when user is deleted (cleanup)

### Event Functions
- `createEvent`: Create new event
- `updateEvent`: Update event (host only)
- `deleteEvent`: Delete event (host only)
- `getEvent`: Get event details
- `getEventsInRegion`: Get events within geographic region
- `onEventCreate`: Trigger when event is created (awards creation bonus)
- `onEventUpdate`: Trigger when event is updated
- `onEventDelete`: Trigger when event is deleted (cleanup)

### Signal Functions
- `createSignal`: Create signal for event participation
- `updateSignal`: Update signal strength
- `deleteSignal`: Delete signal
- `getSignal`: Get signal details
- `getSignalsForEvent`: Get all signals for an event
- `onSignalCreate`: Trigger when signal is created (updates event stats)
- `onSignalUpdate`: Trigger when signal is updated
- `onSignalDelete`: Trigger when signal is deleted

### Point Functions
- `createPoint`: Create point entry
- `updatePoint`: Update point entry
- `deletePoint`: Delete point entry
- `getPoint`: Get point details
- `getUserPoints`: Get all points for a user
- `onPointCreate`: Trigger when point is created (updates user aura)
- `onPointUpdate`: Trigger when point is updated
- `onPointDelete`: Trigger when point is deleted

## 🔐 Security Rules

The Firestore security rules ensure:
- Users can only access their own data
- Events are publicly readable but require authentication to create
- Only event hosts can update/delete their events
- Users can only manage their own signals and points
- System functions can create/update points automatically

## 📱 iOS Integration

### Firebase Configuration

Add your Firebase configuration to your iOS app:

```swift
// In your iOS app's Firebase configuration
import Firebase

class FirebaseManager {
    static let shared = FirebaseManager()
    
    private init() {
        FirebaseApp.configure()
    }
    
    // Your existing Firebase setup
}
```

### Real-time Listeners

```swift
// Listen to events in real-time
func listenToEvents() {
    db.collection("events")
        .addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening to events: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            let events = documents.compactMap { doc in
                try? doc.data(as: CrowdEvent.self)
            }
            
            // Update your UI with new events
            DispatchQueue.main.async {
                self.events = events
            }
        }
}
```

### CRUD Operations

```swift
// Create an event
func createEvent(_ event: CrowdEvent) {
    let functions = Functions.functions()
    let createEvent = functions.httpsCallable("createEvent")
    
    createEvent.call([
        "title": event.title,
        "latitude": event.latitude,
        "longitude": event.longitude,
        "radiusMeters": event.radiusMeters,
        "tags": event.tags
    ]) { result, error in
        if let error = error {
            print("Error creating event: \(error)")
            return
        }
        
        print("Event created successfully")
    }
}
```

## 🛠️ Development

### Local Development

```bash
# Start Firebase emulators for local development
firebase emulators:start

# The emulators will be available at:
# - Functions: http://localhost:5001
# - Firestore: http://localhost:8080
# - Auth: http://localhost:9099
```

### Testing Functions

```bash
# Test functions locally
firebase functions:shell

# In the shell, call functions like:
# createUser({displayName: "Test User"})
```

### Linting

```bash
cd functions
npm run lint
```

## 📈 Monitoring

- **Firebase Console**: Monitor functions, database, and authentication
- **Cloud Logging**: View function logs and errors
- **Firestore Usage**: Monitor database reads/writes
- **Function Metrics**: Track function performance and costs

## 🔄 Deployment

### Production Deployment

```bash
# Deploy everything
firebase deploy

# Deploy specific services
firebase deploy --only functions
firebase deploy --only firestore
```

### Environment Management

```bash
# Set environment variables
firebase functions:config:set app.environment="production"

# Get environment variables
firebase functions:config:get
```

## 🆘 Troubleshooting

### Common Issues

1. **Authentication Errors**: Ensure Firebase Auth is properly configured
2. **Permission Denied**: Check Firestore security rules
3. **Function Timeout**: Increase timeout in firebase.json
4. **Memory Issues**: Increase memory allocation for functions

### Debug Commands

```bash
# View function logs
firebase functions:log

# Test functions locally
firebase functions:shell

# Check Firestore rules
firebase firestore:rules:get
```

## 📞 Support

For issues or questions:
1. Check Firebase Console for errors
2. Review Cloud Functions logs
3. Verify Firestore security rules
4. Ensure proper Firebase configuration in iOS app

## 🔄 Updates

To update the backend:
1. Make changes to functions or rules
2. Test locally with emulators
3. Deploy with `firebase deploy`
4. Update iOS app if API changes are made

---

**Note**: This backend is designed to work seamlessly with your existing Swift iOS app. All functions are optimized for real-time synchronization and include proper error handling and validation.
