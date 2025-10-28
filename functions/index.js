const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// Helper: Calculate distance between two coordinates in meters
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ/2) * Math.sin(Δλ/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return R * c; // Distance in meters
}

// Main Function: Send notifications when events are created
// Follows Apple's Remote Notification Server guidelines
// Reference: https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server
exports.notifyNearbyUsers = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const eventId = context.params.eventId;
    
    console.log('🎉 New event created:', event.title);
    console.log('📍 Category:', event.category);
    console.log('📍 Location:', event.locationName || 'Unknown');

    const eventLat = event.latitude;
    const eventLon = event.longitude;
    const eventCategory = event.category || 'hangout';
    const eventGeohash = event.geohash;
    const eventLocationName = event.locationName || 'a nearby location';
    const eventTitle = event.title || 'New Event';
    const eventHostId = event.hostId;

    // Validate required fields
    if (!eventGeohash || !eventLat || !eventLon) {
      console.log('⚠️ Event missing required location data, skipping notifications');
      return null;
    }

    // Query users with similar geohash (within ~600m radius)
    const geohashPrefix = eventGeohash.substring(0, 5);
    
    try {
      const usersSnapshot = await db.collection('users')
        .where('geohash', '>=', geohashPrefix)
        .where('geohash', '<=', geohashPrefix + '\uf8ff')
        .get();

      console.log(`📍 Found ${usersSnapshot.size} users with similar geohash`);

      // Array to collect qualified notification targets
      const notificationTargets = [];

      // Process each user
      usersSnapshot.forEach(doc => {
        const userId = doc.id;
        const user = doc.data();
        
        // Skip if no FCM token
        if (!user.fcmToken) {
          console.log(`⏭️ User ${userId}: No FCM token`);
          return;
        }

        // Skip event host (don't notify yourself)
        if (userId === eventHostId) {
          console.log(`⏭️ Skipping host: ${user.displayName}`);
          return;
        }

        // Check location data exists
        if (!user.location || !user.location.latitude || !user.location.longitude) {
          console.log(`⏭️ ${user.displayName}: No location data`);
          return;
        }

        // Calculate exact distance
        const distance = calculateDistance(
          eventLat,
          eventLon,
          user.location.latitude,
          user.location.longitude
        );

        console.log(`📏 ${user.displayName}: ${Math.round(distance)}m away`);

        // Filter 1: Distance check (400m radius)
        if (distance > 400) {
          console.log(`⏭️ ${user.displayName}: Too far (${Math.round(distance)}m > 400m)`);
          return;
        }

        // Filter 2: Interest matching (onboarding interests)
        const userInterests = user.interests || [];
        const categoryMatches = userInterests.includes(eventCategory);

        if (!categoryMatches) {
          console.log(`⏭️ ${user.displayName}: No interest in "${eventCategory}"`);
          console.log(`   User interests: ${userInterests.join(', ')}`);
          return;
        }

        // User qualifies for notification!
        notificationTargets.push({
          token: user.fcmToken,
          name: user.displayName,
          distance: Math.round(distance),
          interests: userInterests
        });
        
        console.log(`✅ ${user.displayName} qualifies (${Math.round(distance)}m, interested in ${eventCategory})`);
      });

      // No qualified users found
      if (notificationTargets.length === 0) {
        console.log('📭 No users match criteria (location + interests)');
        return null;
      }

      console.log(`📬 Sending to ${notificationTargets.length} user(s):`);
      notificationTargets.forEach(target => {
        console.log(`   - ${target.name} (${target.distance}m away)`);
      });

      // Extract just the tokens for sending
      const tokens = notificationTargets.map(t => t.token);

      // Build APNs-compliant message following Apple's guidelines
      // Reference: https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server
      const message = {
        tokens: tokens,
        notification: {
          title: `🔥 New ${eventCategory} near you!`,
          body: `${eventTitle} at ${eventLocationName}`,
        },
        data: {
          eventId: eventId,
          type: 'nearby_event',
          category: eventCategory,
          distance: notificationTargets[0].distance.toString(),
          locationName: eventLocationName,
        },
        // APNs-specific configuration (Apple's recommended settings)
        apns: {
          headers: {
            'apns-priority': '10', // High priority (immediate delivery)
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: `🔥 New ${eventCategory} near you!`,
                body: `${eventTitle} at ${eventLocationName}`,
                'launch-image': 'Logo', // Your app icon
              },
              sound: 'default',
              badge: 1,
              category: 'EVENT_INVITE', // For custom notification actions
              'thread-id': `event-${eventId}`, // Groups related notifications
              'content-available': 1, // Enable background updates
              'mutable-content': 1, // Enable notification extensions
            },
            // Custom data for handling notification tap
            eventId: eventId,
            eventCategory: eventCategory,
            eventLocationName: eventLocationName,
          },
        },
        // Android config (if you support Android later)
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'event_notifications',
          },
        },
      };

      // Send notification via FCM (which handles APNs communication)
      const response = await admin.messaging().sendMulticast(message);
      
      console.log(`✅ Successfully sent: ${response.successCount} notification(s)`);
      console.log(`❌ Failed to send: ${response.failureCount} notification(s)`);
      
      // Handle failures (per Apple's recommendations)
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`❌ Failed token ${idx}:`, resp.error.code);
            
            // Mark invalid tokens for removal (Apple recommends this)
            if (resp.error.code === 'messaging/invalid-registration-token' ||
                resp.error.code === 'messaging/registration-token-not-registered') {
              failedTokens.push(tokens[idx]);
            }
          }
        });
        
        // Clean up invalid tokens from Firestore
        if (failedTokens.length > 0) {
          console.log(`🧹 Cleaning up ${failedTokens.length} invalid token(s)`);
          const cleanupPromises = notificationTargets
            .filter(target => failedTokens.includes(target.token))
            .map(target => {
              return db.collection('users')
                .where('fcmToken', '==', target.token)
                .get()
                .then(snapshot => {
                  snapshot.forEach(doc => {
                    doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
                  });
                });
            });
          await Promise.all(cleanupPromises);
          console.log('✅ Invalid tokens removed');
        }
      }
      
      return response;
    } catch (error) {
      console.error('❌ Error in notifyNearbyUsers:', error);
      return null;
    }
  });

// Helper function: Manually test notification sending
// Call this from Firebase Console to test
exports.testNotification = functions.https.onCall(async (data, context) => {
  const { userId, testMessage } = data;
  
  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }
  
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }
    
    const user = userDoc.data();
    if (!user.fcmToken) {
      throw new functions.https.HttpsError('failed-precondition', 'User has no FCM token');
    }
    
    const message = {
      token: user.fcmToken,
      notification: {
        title: '🧪 Test Notification',
        body: testMessage || 'This is a test notification from Crowd!',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };
    
    const response = await admin.messaging().send(message);
    console.log('✅ Test notification sent:', response);
    
    return { success: true, messageId: response };
  } catch (error) {
    console.error('❌ Test notification failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Create a new event
exports.createEvent = functions.https.onCall(async (data, context) => {
  try {
    console.log('📝 Creating event:', data.title);
    
    const eventData = {
      id: data.id,
      title: data.title,
      latitude: data.latitude,
      longitude: data.longitude,
      radiusMeters: data.radiusMeters || 50,
      startsAt: data.startsAt,
      endsAt: data.endsAt,
      tags: data.tags || [],
      category: data.category || 'hangout',
      geohash: data.geohash,
      hostId: data.hostId,
      hostName: data.hostName,
      description: data.description || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      attendeeCount: 0,
      signalStrength: 1
    };
    
    await db.collection('events').doc(data.id).set(eventData);
    console.log('✅ Event created:', data.id);
    
    return { success: true, eventId: data.id };
  } catch (error) {
    console.error('❌ Error creating event:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Get events in a region
exports.getEventsInRegion = functions.https.onCall(async (data, context) => {
  try {
    const { latitude, longitude, radiusKm } = data;
    
    console.log(`📍 Fetching events near (${latitude}, ${longitude}) within ${radiusKm}km`);
    
    // Get all events (we'll filter by distance)
    const eventsSnapshot = await db.collection('events').get();
    
    const events = [];
    eventsSnapshot.forEach(doc => {
      const event = doc.data();
      
      // Calculate distance
      const distance = calculateDistance(
        latitude,
        longitude,
        event.latitude,
        event.longitude
      );
      
      // Only include events within radius
      if (distance <= radiusKm * 1000) {
        events.push({
          ...event,
          distance: Math.round(distance)
        });
      }
    });
    
    console.log(`✅ Found ${events.length} events in region`);
    return { events };
  } catch (error) {
    console.error('❌ Error fetching events:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Delete an event
exports.deleteEvent = functions.https.onCall(async (data, context) => {
  try {
    const eventId = data.id; // App sends 'id' parameter
    
    if (!eventId) {
      throw new functions.https.HttpsError('invalid-argument', 'eventId is required');
    }
    
    console.log(`🗑️ Deleting event: ${eventId}`);
    
    // Get the event to verify it exists
    const eventDoc = await db.collection('events').doc(eventId).get();
    
    if (!eventDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Event not found');
    }
    
    // Delete the event
    await db.collection('events').doc(eventId).delete();
    
    // Also delete any associated signals
    const signalsSnapshot = await db.collection('signals')
      .where('eventId', '==', eventId)
      .get();
    
    const deletePromises = signalsSnapshot.docs.map(doc => doc.ref.delete());
    await Promise.all(deletePromises);
    
    console.log(`✅ Event deleted: ${eventId} (and ${signalsSnapshot.size} signals)`);
    
    return { success: true };
  } catch (error) {
    console.error('❌ Error deleting event:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

