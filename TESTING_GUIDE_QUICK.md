# 🧪 Quick Testing Guide - Backend Integration

## ✅ Status: 100% Complete & Ready to Test!

All Firebase packages are integrated and active:
- ✅ FirebaseAuth
- ✅ FirebaseFirestore  
- ✅ FirebaseFunctions
- ✅ FirebaseStorage
- ✅ FirebaseAnalytics

---

## 🚀 How to Test (5 Minutes)

### Step 1: Start Backend Emulators (Terminal 1)
```bash
cd Crowd-Backend
npm start
```

**Expected**: Emulator UI opens at http://localhost:4000

### Step 2: Run iOS App (Xcode)
1. Open `Crowd.xcodeproj` in Xcode
2. Build and Run (⌘R) on simulator or device
3. App connects to emulators automatically in DEBUG mode

---

## 🎯 Test Scenarios

### 1️⃣ Onboarding Flow (2 min)
**What to test:**
- Enter display name
- Select campus (UNT/SMU)
- Pick interests

**Expected results:**
- ✅ Profile created in Firestore (`users` collection)
- ✅ User gets 100 welcome bonus points
- ✅ Analytics event: `user_created`

**Check in Emulator UI:**
- Go to http://localhost:4000
- Click "Firestore" → `users` → Should see new user document

### 2️⃣ Create Event (1 min)
**What to test:**
- Tap "+" button
- Create an event with title
- Set location

**Expected results:**
- ✅ Event appears on map
- ✅ Event saved to Firestore (`events` collection)
- ✅ Host gets 50 bonus points
- ✅ Geohash auto-generated
- ✅ Analytics event: `event_created`

**Check in Emulator UI:**
- Firestore → `events` → See your event with geohash field

### 3️⃣ Join Event (1 min)
**What to test:**
- Tap an event marker on map
- Tap "Join" button

**Expected results:**
- ✅ Signal created with your GPS location (`signals` collection)
- ✅ Event attendeeCount increases by 1
- ✅ You get 10 participation points
- ✅ Analytics event: `event_joined`

**Check in Emulator UI:**
- Firestore → `signals` → See signal with lat/lng
- Firestore → `events` → See attendeeCount = 1

### 4️⃣ Leaderboard (30 sec)
**What to test:**
- Open leaderboard tab
- Switch timeframes (Today/Week/Month)

**Expected results:**
- ✅ Shows real users from Firestore
- ✅ Sorted by auraPoints
- ✅ Your user appears in list
- ✅ Analytics event: `leaderboard_viewed`

**Check in Emulator UI:**
- Cloud Functions → Logs → See `getLeaderboard` calls

### 5️⃣ Profile Image Upload (30 sec)
**What to test:**
- Go to profile
- Tap profile image
- Select photo from library

**Expected results:**
- ✅ Image uploads to Firebase Storage
- ✅ Profile updated with imageURL
- ✅ Image appears in profile

**Check in Emulator UI:**
- Storage → `profile_images` → See uploaded image

### 6️⃣ Delete Event (30 sec)
**What to test:**
- Open your own event
- Tap "Cancel Event"
- Confirm deletion

**Expected results:**
- ✅ Event removed from Firestore
- ✅ Related signals deleted
- ✅ Event disappears from map
- ✅ Analytics event: `event_deleted`

**Check in Emulator UI:**
- Firestore → `events` → Event should be gone

---

## 📊 What to Monitor

### Firebase Emulator UI (http://localhost:4000)

1. **Firestore Tab**:
   - `users` - Profile data, auraPoints increasing
   - `events` - Events with geohash fields
   - `signals` - Join records with lat/lng
   - `points` - Point transactions
   - `presence` - Heartbeat updates (every 30s)

2. **Functions Tab**:
   - See function calls in real-time
   - Check logs for success/error messages

3. **Storage Tab**:
   - Profile images in `profile_images/` folder

4. **Auth Tab**:
   - Anonymous users created automatically

### Xcode Console

Watch for these log messages:
```
✅ Authenticated with Firebase: [userId]
✅ User profile created: [displayName]
✅ Joined event [eventId] at location (lat, lng)
📊 Analytics: user_created | {...}
📊 Analytics: event_joined | {...}
💓 Heartbeat sent for user [userId]
🔄 Real-time update: [count] events in region
```

---

## 🎉 Success Indicators

You'll know everything is working when:

- ✅ **Onboarding** creates user in Firestore with 100 points
- ✅ **Events** appear on map with real-time updates
- ✅ **Joining** creates signal with GPS coordinates
- ✅ **Leaderboard** shows real users sorted by points
- ✅ **Profile images** upload successfully
- ✅ **Analytics** logs appear in console
- ✅ **Deleting** removes events and signals

---

## 🐛 Troubleshooting

### "Location not available" error when joining
- **iOS Simulator**: Debug → Location → Custom Location
- **Device**: Settings → Privacy → Location → Allow "While Using"

### Emulators not connecting
- Check emulators are running: `firebase emulators:list`
- Check `FirebaseManager.swift` has correct ports
- Make sure you're in DEBUG mode

### Function calls failing
- Check emulators are running
- View function logs in Emulator UI
- Check console for error messages

### Analytics not showing
- Analytics will log to console immediately
- Firebase Console (production) updates take 24-48 hours
- Use Emulator UI to verify data is being sent

---

## 🔥 Quick Commands

```bash
# Start emulators
cd Crowd-Backend && npm start

# View function logs
firebase functions:log --only leaderboard

# Clear emulator data (fresh start)
firebase emulators:exec --project crowd-6193c "echo 'Cleared'"

# Check Firebase config
firebase functions:config:get
```

---

## 📱 Testing on Multiple Devices

To test social features (friends, multiple attendees):

1. **Simulator 1**: iPhone 15 Pro
2. **Simulator 2**: iPhone 15
3. Both connect to same emulators

Test flow:
- User 1 creates event
- User 2 joins event  
- Both users appear in leaderboard
- Attendee count increases

---

## ✅ All Features Working?

If you can complete all 6 test scenarios above successfully, your backend integration is **fully operational**! 🎊

Next steps:
- Deploy to Firebase production when ready
- Add more events and test at scale
- Invite team members to test
- Start building additional features

**Happy Testing! 🚀**



