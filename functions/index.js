const functions = require('firebase-functions');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// === Utilities ===
function normalizeLocationKey(name) {
  if (!name || typeof name !== 'string') return null;
  return name.trim().toLowerCase().replace(/\s+/g, ' ').slice(0, 200);
}

// Minimal geohash encoder (base32), precision 6 is plenty for campus scale
const GEO_BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';
function geohashEncode(latitude, longitude, precision = 6) {
  let idx = 0;
  let bit = 0;
  let evenBit = true;
  let geohash = '';
  let latMin = -90, latMax = 90;
  let lonMin = -180, lonMax = 180;
  while (geohash.length < precision) {
    if (evenBit) {
      const lonMid = (lonMin + lonMax) / 2;
      if (longitude >= lonMid) { idx = idx * 2 + 1; lonMin = lonMid; }
      else { idx = idx * 2; lonMax = lonMid; }
    } else {
      const latMid = (latMin + latMax) / 2;
      if (latitude >= latMid) { idx = idx * 2 + 1; latMin = latMid; }
      else { idx = idx * 2; latMax = latMid; }
    }
    evenBit = !evenBit;
    if (++bit === 5) { geohash += GEO_BASE32.charAt(idx); bit = 0; idx = 0; }
  }
  return geohash;
}

// Parse common campus time strings like
// "Tuesday, October 28, 2025 at 10:00 AM" or a range ".. to .."
function parseStartDateFromString(startTimeLocal) {
  if (!startTimeLocal || typeof startTimeLocal !== 'string') return null;
  const firstPart = startTimeLocal.includes(' to ')
    ? startTimeLocal.split(' to ')[0]
    : startTimeLocal;
  // Try replacing " at " with ", " to aid Date parsing
  const candidate = firstPart.replace(' at ', ', ');
  const d = new Date(candidate);
  return isNaN(d.getTime()) ? null : d;
}

// Convert ISO-like string to millis, or null if invalid
function toMillis(s) {
  if (!s || typeof s !== 'string') return null;
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : d.getTime();
}

// Determine a location string from event doc
function deriveLocationString(doc) {
  // Prefer explicit 'location' from Firebase source as provided by user
  if (doc.location && typeof doc.location === 'string' && doc.location.trim().length) {
    return doc.location.trim();
  }
  if (doc.locationName && typeof doc.locationName === 'string' && doc.locationName.trim().length) {
    return doc.locationName.trim();
  }
  // Try description's first segment before a bullet "•", dash or comma
  if (doc.description && typeof doc.description === 'string') {
    const firstLine = doc.description.split('\n')[0] || '';
    const seg = firstLine.split('•')[0].split('-')[0].split(',')[0].trim();
    if (seg.length >= 3) return seg;
  }
  if (doc.organization && typeof doc.organization === 'string') {
    return doc.organization.trim();
  }
  if (doc.sourceOrg && typeof doc.sourceOrg === 'string') {
    return doc.sourceOrg.trim();
  }
  return null;
}

// Call Google Geocoding API with server key in functions config: geocode.api_key
async function geocodeLocation(locationName) {
  const key = functions.config().geocode && functions.config().geocode.api_key;
  if (!key) throw new Error('Missing geocode.api_key config');
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(locationName)}&key=${key}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Geocode HTTP ${res.status}`);
  const payload = await res.json();
  if (payload.status !== 'OK' || !payload.results || payload.results.length === 0) {
    throw new Error(`Geocode failed: ${payload.status}`);
  }
  const r = payload.results[0];
  const lat = r.geometry.location.lat;
  const lng = r.geometry.location.lng;
  const placeId = r.place_id;
  return { latitude: lat, longitude: lng, placeId };
}

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

// Helper: Get emoji for interest/category name
function getInterestEmoji(categoryName) {
  const emojiMap = {
    'music': '🎵',
    'party': '🎉',
    'food': '🍕',
    'coffee': '☕',
    'sports': '⚽',
    'study': '📚',
    'academic': '📚',
    'art': '🎨',
    'culture': '🎭',
    'social': '🤝',
    'networking': '🤝',
    'wellness': '🧘',
    'health': '🏥',
    'outdoor': '🏔️',
    'gaming': '🎮',
    'lifestyle': '👗',
    'politics': '🏛️',
    'hangout': '🫂',
    'default': '🎉'
  };
  
  const lowerCategory = categoryName.toLowerCase();
  for (const [key, emoji] of Object.entries(emojiMap)) {
    if (lowerCategory.includes(key)) {
      return emoji;
    }
  }
  return emojiMap.default;
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

    // Get current timestamp for cooldown checks
    const nowSeconds = Math.floor(Date.now() / 1000);
    const cooldownSeconds = 3 * 60 * 60; // 3 hours in seconds

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

        // Filter 1: Distance check (1km radius)
        if (distance > 1000) {
          console.log(`⏭️ ${user.displayName}: Too far (${Math.round(distance)}m > 1000m)`);
          return;
        }

        // Filter 2: Interest matching (onboarding interests + event tags)
        const userInterests = user.interests || [];
        const eventTags = event.tags || [];
        const categoryMatches = userInterests.includes(eventCategory);
        
        // Check if user has matching tags
        let tagMatches = false;
        for (const tag of eventTags) {
          if (userInterests.some(interest => interest.toLowerCase().includes(tag.toLowerCase()) || tag.toLowerCase().includes(interest.toLowerCase()))) {
            tagMatches = true;
            break;
          }
        }

        if (!categoryMatches && !tagMatches) {
          console.log(`⏭️ ${user.displayName}: No interest in "${eventCategory}" or matching tags`);
          console.log(`   User interests: ${userInterests.join(', ')}`);
          return;
        }

        // Filter 3: Cooldown check (3 hours)
        const notificationCooldowns = user.notificationCooldowns || {};
        const lastNotification = notificationCooldowns.nearby_event;
        if (lastNotification && typeof lastNotification._seconds === 'number') {
          const secondsSinceLastNotification = nowSeconds - lastNotification._seconds;
          if (secondsSinceLastNotification < cooldownSeconds) {
            const remainingMinutes = Math.ceil((cooldownSeconds - secondsSinceLastNotification) / 60);
            console.log(`⏭️ ${user.displayName}: Still in cooldown (${remainingMinutes} min remaining)`);
            return;
          }
        }

        // User qualifies for notification!
        notificationTargets.push({
          token: user.fcmToken,
          userId: userId,
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
      
      // Get emoji for category/interest
      const interestEmoji = getInterestEmoji(eventCategory);

      // Build APNs-compliant message following Apple's guidelines
      // Reference: https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server
      const message = {
        tokens: tokens,
        notification: {
          title: 'Crowd has spawned nearby',
          body: 'Don\'t miss the moment.',
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
                title: 'Crowd has spawned nearby',
                body: 'Don\'t miss the moment.',
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
      
      // Update cooldown for successfully sent notifications
      const successfulTargets = [];
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (resp.success) {
          successfulTargets.push(notificationTargets[idx]);
        } else {
          console.error(`❌ Failed token ${idx}:`, resp.error.code);
          
          // Mark invalid tokens for removal (Apple recommends this)
          if (resp.error.code === 'messaging/invalid-registration-token' ||
              resp.error.code === 'messaging/registration-token-not-registered') {
            failedTokens.push(tokens[idx]);
          }
        }
      });
      
      // Update cooldown timestamps for successful sends
      if (successfulTargets.length > 0) {
        console.log(`⏰ Updating cooldown for ${successfulTargets.length} user(s)`);
        const cooldownUpdates = successfulTargets.map(target => {
          const cooldownTimestamp = admin.firestore.Timestamp.fromMillis(Date.now());
          return db.collection('users').doc(target.userId).update({
            'notificationCooldowns.nearby_event': cooldownTimestamp,
            'lastNotificationSent': cooldownTimestamp
          });
        });
        await Promise.all(cooldownUpdates);
        console.log('✅ Cooldowns updated');
      }
      
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
      
      return response;
    } catch (error) {
      console.error('❌ Error in notifyNearbyUsers:', error);
      return null;
    }
  });

// Helper function: Manually test notification sending
// Call this from Firebase Console to test
// Note: App Check is optional for testing purposes
exports.testNotification = onCall({
  // Disable App Check requirement for testing
  enforceAppCheck: false
}, async (request) => {
  const { data, auth } = request;
  const { userId, notificationType = 'basic', testMessage } = data;
  
  console.log('🧪 Test notification called for userId:', userId);
  console.log('   - Notification type:', notificationType);
  console.log('   - Test message:', testMessage || 'default');
  
  if (!userId) {
    console.log('❌ No userId provided');
    throw new HttpsError('invalid-argument', 'userId is required');
  }
  
  try {
    console.log('🔍 Fetching user document...');
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log('❌ User document does not exist');
      throw new HttpsError('not-found', 'User not found');
    }
    
    const user = userDoc.data();
    console.log('✅ User found:', user.displayName || 'Unknown');
    
    if (!user.fcmToken) {
      console.log('❌ User has no FCM token');
      throw new HttpsError('failed-precondition', 'User has no FCM token');
    }
    
    console.log('🔑 FCM token found, preparing notification...');
    
    // Build notification based on type
    let message;
    
    switch (notificationType) {
      case 'nearby_event':
        message = {
          token: user.fcmToken,
          notification: {
            title: 'Crowd has spawned nearby',
            body: 'Don\'t miss the moment.',
          },
          data: {
            eventId: 'test-event-id',
            type: 'nearby_event',
            category: 'Party',
            distance: '200',
            locationName: 'Test Location',
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                alert: {
                  title: 'Crowd has spawned nearby',
                  body: 'Don\'t miss the moment.',
                },
                sound: 'default',
                badge: 1,
                category: 'EVENT_INVITE',
                'thread-id': 'event-test-event-id',
                'content-available': 1,
                'mutable-content': 1,
              },
              eventId: 'test-event-id',
              eventCategory: 'Party',
              eventLocationName: 'Test Location',
            },
          },
        };
        break;
        
      case 'engagement':
        message = {
          token: user.fcmToken,
          notification: {
            title: 'This Crowd is popping off!',
            body: '5 are here. Join the Crowd.',
          },
          data: {
            eventId: 'test-event-id',
            type: 'engagement',
            attendeeCount: '5',
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: 'This Crowd is popping off!',
                  body: '5 are here. Join the Crowd.',
                },
                sound: 'default',
                badge: 1,
                category: 'EVENT_INVITE',
              },
              eventId: 'test-event-id',
            },
          },
        };
        break;
        
      case 'study_reminder':
        message = {
          token: user.fcmToken,
          notification: {
            title: 'Don\'t study solo.',
            body: 'Start a Crowd and find your study crew.',
          },
          data: {
            type: 'promotional',
            action: 'showHostSheet',
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: 'Don\'t study solo.',
                  body: 'Start a Crowd and find your study crew.',
                },
                sound: 'default',
                badge: 1,
              },
            },
          },
        };
        break;
        
      case 'social_reminder':
        message = {
          token: user.fcmToken,
          notification: {
            title: 'Start a crowd 👩‍❤️‍💋‍👨💋',
            body: 'Someone\'s always down to link.',
          },
          data: {
            type: 'promotional',
            action: 'showHostSheet',
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: 'Start a crowd 👩‍❤️‍💋‍👨💋',
                  body: 'Someone\'s always down to link.',
                },
                sound: 'default',
                badge: 1,
              },
            },
          },
        };
        break;
        
      default: // 'basic'
        message = {
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
    }
    
    const response = await admin.messaging().send(message);
    console.log('✅ Test notification sent:', response);
    
    return { success: true, messageId: response, type: notificationType };
  } catch (error) {
    console.error('❌ Test notification failed:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', error.message);
  }
});

// Create a new event
exports.createEvent = functions.https.onCall(async (data, context) => {
  try {
    console.log('📝 Creating event:', data.title);
    
    function normalizeEndsAtMillis(endsAt) {
      if (!endsAt) return null;
      if (typeof endsAt === 'number') {
        // assume seconds if it's reasonably small, otherwise millis
        return endsAt < 10_000_000_000 ? endsAt * 1000 : endsAt;
      }
      if (endsAt._seconds) return endsAt._seconds * 1000;
      if (endsAt.seconds) return endsAt.seconds * 1000;
      return null;
    }

    const nowMs = Date.now();
    const endsAtMs = normalizeEndsAtMillis(data.endsAt);
    const expiresAtMs = endsAtMs != null
      ? endsAtMs + 60 * 60 * 1000 // endsAt + 1h grace
      : nowMs + 24 * 60 * 60 * 1000; // default 24h if no endsAt provided

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
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
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

// Scheduled cleanup: delete chats for events that have ended
exports.cleanupExpiredEventChats = functions.pubsub
  .schedule('every 30 minutes')
  .timeZone('Etc/UTC')
  .onRun(async (context) => {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const expiredEventIds = new Set();

    function normalizeEndsAt(endsAt) {
      if (!endsAt) return null;
      if (typeof endsAt === 'number') return endsAt;
      if (endsAt._seconds) return endsAt._seconds; // Firestore Timestamp object
      return null;
    }

    async function collectExpired(collectionName) {
      const snapshot = await db.collection(collectionName).get();
      snapshot.forEach(doc => {
        const endsAt = normalizeEndsAt(doc.data().endsAt);
        if (endsAt && endsAt < nowSeconds) {
          expiredEventIds.add(doc.id);
        }
      });
    }

    // Gather expired events from both sources
    await Promise.all([
      collectExpired('events'),
      collectExpired('userEvents'),
    ]);

    if (expiredEventIds.size === 0) {
      console.log('🧹 No expired events found for chat cleanup');
      return null;
    }

    console.log(`🧹 Cleaning chats for ${expiredEventIds.size} expired event(s)`);

    async function deleteEventChat(eventId) {
      const messagesRef = db.collection('eventChats').doc(eventId).collection('messages');
      const batchSize = 500;
      let deletedTotal = 0;

      while (true) {
        const snap = await messagesRef.limit(batchSize).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        deletedTotal += snap.size;
        if (snap.size < batchSize) break;
      }

      // Delete the parent chat doc if it exists
      await db.collection('eventChats').doc(eventId).delete().catch(() => {});
      console.log(`🗑️ Deleted ${deletedTotal} message(s) and chat doc for event ${eventId}`);
    }

    await Promise.all(Array.from(expiredEventIds).map(deleteEventChat));
    console.log('✅ Chat cleanup complete');
    return null;
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

// Create a signal (join an event)
exports.createSignal = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { eventId, latitude, longitude, signalStrength } = data;
    const userId = context.auth.uid;
    
    console.log(`📡 Creating signal for event ${eventId} by user ${userId}`);
    console.log(`   Location: (${latitude}, ${longitude})`);
    console.log(`   Signal strength: ${signalStrength}`);
    
    // Validate required fields
    if (!eventId || !latitude || !longitude) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: eventId, latitude, longitude');
    }
    
    // Check if event exists
    const eventDoc = await db.collection('events').doc(eventId).get();
    const userEventDoc = await db.collection('userEvents').doc(eventId).get();
    
    if (!eventDoc.exists && !userEventDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Event not found');
    }
    
    // Check if user already has a signal for this event
    const existingSignalQuery = await db.collection('signals')
      .where('eventId', '==', eventId)
      .where('userId', '==', userId)
      .get();
    
    if (!existingSignalQuery.empty) {
      console.log(`⚠️ User ${userId} already has a signal for event ${eventId}`);
      return { success: true, message: 'Already joined event' };
    }
    
    // Create signal document
    const signalData = {
      eventId: eventId,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      signalStrength: signalStrength || 3,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Add to signals collection
    const signalRef = db.collection('signals').doc();
    await signalRef.set(signalData);
    
    // Update event attendee count
    const eventRef = eventDoc.exists ? db.collection('events').doc(eventId) : db.collection('userEvents').doc(eventId);
    await eventRef.update({
      attendeeCount: admin.firestore.FieldValue.increment(1),
      signalStrength: admin.firestore.FieldValue.increment(signalStrength || 3)
    });
    
    console.log(`✅ Signal created successfully: ${signalRef.id}`);
    
    return { 
      success: true, 
      signalId: signalRef.id,
      message: 'Successfully joined event'
    };
  } catch (error) {
    console.error('❌ Error creating signal:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Test function: Add sample campus events to campus_events_live collection
exports.addSampleCampusEvents = functions.https.onCall(async (data, context) => {
  try {
    console.log('📝 Adding sample campus events to campus_events_live collection');
    
    const sampleEvents = [
      {
        title: "Halloween Bash",
        locationName: "Student Union Ballroom",
        startTimeLocal: "2024-10-31T19:00:00-05:00",
        endTimeLocal: "2024-10-31T23:00:00-05:00",
        sourceType: "instagram",
        sourceOrg: "bsu_unt",
        sourceUrl: "https://instagram.com/p/sample1",
        confidence: 0.95,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        title: "Study Session - Finals Prep",
        locationName: "Willis Library Room 241",
        startTimeLocal: "2024-11-01T18:00:00-05:00",
        endTimeLocal: "2024-11-01T21:00:00-05:00",
        sourceType: "official",
        sourceOrg: "UNT Academic Success",
        sourceUrl: "https://unt.edu/events/study-session",
        confidence: 0.98,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        title: "Basketball Pickup Game",
        locationName: "Pohl Recreation Center",
        startTimeLocal: "2024-11-02T16:00:00-05:00",
        endTimeLocal: "2024-11-02T18:00:00-05:00",
        sourceType: "instagram",
        sourceOrg: "unt_rec_sports",
        sourceUrl: "https://instagram.com/p/sample2",
        confidence: 0.87,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        title: "Coffee & Networking Meetup",
        locationName: "Starbucks - Union",
        startTimeLocal: "2024-11-03T10:00:00-05:00",
        endTimeLocal: "2024-11-03T11:30:00-05:00",
        sourceType: "instagram",
        sourceOrg: "unt_business_club",
        sourceUrl: "https://instagram.com/p/sample3",
        confidence: 0.92,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        title: "Movie Night - Horror Films",
        locationName: "Union Theater",
        startTimeLocal: "2024-11-04T19:30:00-05:00",
        endTimeLocal: "2024-11-04T22:00:00-05:00",
        sourceType: "official",
        sourceOrg: "UNT Student Activities",
        sourceUrl: "https://unt.edu/events/movie-night",
        confidence: 0.94,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      }
    ];
    
    const batch = db.batch();
    
    sampleEvents.forEach((event, index) => {
      const endMs = toMillis(event.endTimeLocal);
      const expiresAt = endMs != null
        ? admin.firestore.Timestamp.fromMillis(endMs + 60 * 60 * 1000)
        : admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
      const docRef = db.collection('campus_events_live').doc(`sample_event_${index + 1}`);
      batch.set(docRef, { ...event, expiresAt });
    });
    
    await batch.commit();
    
    console.log(`✅ Added ${sampleEvents.length} sample campus events`);
    
    return { success: true, count: sampleEvents.length };
  } catch (error) {
    console.error('❌ Error adding sample campus events:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// === Callable: Return today's campus events with coordinates (backend geocoding + caching) ===
exports.getTodaysEvents = functions.https.onCall(async (data, context) => {
  try {
    const { geohashPrefix, date, limit = 50 } = data || {};
    if (!date) {
      throw new functions.https.HttpsError('invalid-argument', 'date (YYYY-MM-DD) is required');
    }
    if (limit > 100) {
      throw new functions.https.HttpsError('invalid-argument', 'limit must be <= 100');
    }

    // Compute start/end of day in UTC for comparison after parsing local strings
    const [y, m, d] = date.split('-').map(Number);
    if (!y || !m || !d) throw new functions.https.HttpsError('invalid-argument', 'date must be YYYY-MM-DD');
    const startOfDay = new Date(Date.UTC(y, m - 1, d, 0, 0, 0));
    const endOfDay = new Date(Date.UTC(y, m - 1, d, 23, 59, 59, 999));

    // Fetch a window of docs; filtering and enrichment happens in memory
    const snap = await db.collection('campus_events_live').limit(limit * 3).get();
    const docs = snap.docs.map(d => ({ id: d.id, ...(d.data() || {}) }));

    // Helper: check if start time is on requested day
    function isOnRequestedDay(doc) {
      // Prefer numeric timestamps if present
      if (doc.startsAt && typeof doc.startsAt === 'object' && doc.startsAt._seconds) {
        const ms = doc.startsAt._seconds * 1000;
        const dt = new Date(ms);
        return dt >= startOfDay && dt <= endOfDay;
      }
      // ISO fields from feed (e.g., startTimeISO)
      if (doc.startTimeISO && typeof doc.startTimeISO === 'string') {
        const dt = new Date(doc.startTimeISO);
        if (!isNaN(dt.getTime())) return dt >= startOfDay && dt <= endOfDay;
      }
      if (doc.startTimeLocal) {
        const dt = parseStartDateFromString(doc.startTimeLocal);
        if (dt) {
          return dt >= startOfDay && dt <= endOfDay;
        }
      }
      return false;
    }

    // Filter to today's events first
    let todays = docs.filter(isOnRequestedDay).slice(0, limit * 2);

    const results = [];
    for (const ev of todays) {
      let latitude = ev.latitude;
      let longitude = ev.longitude;
      let geohash = ev.geohash;

      if ((latitude == null || longitude == null) || (isNaN(latitude) || isNaN(longitude))) {
        // Derive a human location string
        const locStr = deriveLocationString(ev);
        if (locStr) {
          const cacheKey = normalizeLocationKey(locStr);
          let cached = null;
          if (cacheKey) {
            const cachedDoc = await db.collection('geocoding_cache').doc(cacheKey).get();
            if (cachedDoc.exists) cached = cachedDoc.data();
          }
          try {
            let geo = cached;
            if (!geo) {
              geo = await geocodeLocation(locStr);
              if (cacheKey) {
                await db.collection('geocoding_cache').doc(cacheKey).set({
                  name: locStr,
                  normalized: cacheKey,
                  latitude: geo.latitude,
                  longitude: geo.longitude,
                  placeId: geo.placeId || null,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
              }
            }
            latitude = geo.latitude;
            longitude = geo.longitude;
            geohash = geohashEncode(latitude, longitude, 6);
            // Persist back to the source doc for future efficiency
            // Also add expiresAt if missing to enable Firestore TTL cleanup
            const endMs = toMillis && ev.endTimeLocal ? toMillis(ev.endTimeLocal) : null;
            const expiresAt = (endMs != null)
              ? admin.firestore.Timestamp.fromMillis(endMs + 60 * 60 * 1000)
              : (ev.expiresAt ? ev.expiresAt : admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000));
            await db.collection('campus_events_live').doc(ev.id).set({ latitude, longitude, geohash, expiresAt }, { merge: true });
          } catch (e) {
            console.warn(`Geocode failed for "${locStr}":`, e.message);
          }
        }
      }

      // Region filter if we have both coords and a prefix
      if (geohashPrefix && latitude != null && longitude != null) {
        const gh = geohash || geohashEncode(latitude, longitude, 6);
        if (!(gh >= geohashPrefix && gh <= geohashPrefix + '\uf8ff')) {
          continue; // skip outside region
        }
      }

      // Build DTO compatible with CrowdEvent
      if (latitude != null && longitude != null) {
        results.push({
          id: ev.id,
          title: ev.title || 'Event',
          hostId: ev.sourceOrg || 'campus',
          hostName: ev.sourceOrg || 'Campus',
          latitude,
          longitude,
          radiusMeters: 60,
          startsAt: ev.startsAt || null,
          endsAt: ev.endsAt || null,
          createdAt: ev.createdAt || null,
          signalStrength: 0,
          attendeeCount: 0,
          tags: Array.isArray(ev.tags) ? ev.tags : [],
          category: ev.category || null,
          description: ev.description || null,
          sourceURL: ev.sourceUrl || ev.sourceURL || null,
        });
      }

      if (results.length >= limit) break;
    }

    return { events: results };
  } catch (error) {
    console.error('❌ getTodaysEvents failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// === Callable: Geocode a single campus_events_live event if it lacks coords ===
exports.geocodeEventIfNeeded = functions.https.onCall(async (data, context) => {
  try {
    const { id } = data || {};
    if (!id) {
      throw new functions.https.HttpsError('invalid-argument', 'id is required');
    }
    const ref = db.collection('campus_events_live').doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'event not found');
    }
    const ev = snap.data() || {};
    let { latitude, longitude, geohash } = ev;
    if (typeof latitude === 'number' && typeof longitude === 'number') {
      return { success: true, latitude, longitude, geohash: geohash || geohashEncode(latitude, longitude, 6) };
    }
    const locStr = deriveLocationString(ev);
    if (!locStr) {
      return { success: false, reason: 'no_location_string' };
    }
    const cacheKey = normalizeLocationKey(locStr);
    let cached = null;
    if (cacheKey) {
      const cachedDoc = await db.collection('geocoding_cache').doc(cacheKey).get();
      if (cachedDoc.exists) cached = cachedDoc.data();
    }
    let geo = cached;
    if (!geo) {
      geo = await geocodeLocation(locStr);
      if (cacheKey) {
        await db.collection('geocoding_cache').doc(cacheKey).set({
          name: locStr,
          normalized: cacheKey,
          latitude: geo.latitude,
          longitude: geo.longitude,
          placeId: geo.placeId || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }
    latitude = geo.latitude; longitude = geo.longitude; geohash = geohashEncode(latitude, longitude, 6);
    await ref.set({ latitude, longitude, geohash }, { merge: true });
    return { success: true, latitude, longitude, geohash };
  } catch (error) {
    console.error('❌ geocodeEventIfNeeded failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Engagement Notification: Notify users when event reaches 5 attendees
exports.notifyPopularEvent = functions.firestore
  .document('signals/{signalId}')
  .onCreate(async (snap, context) => {
    const signal = snap.data();
    const eventId = signal.eventId;
    
    console.log('📡 Signal created for event:', eventId);
    
    // Count total signals for this event
    const signalsSnapshot = await db.collection('signals')
      .where('eventId', '==', eventId)
      .get();
    
    const attendeeCount = signalsSnapshot.size;
    console.log(`👥 Event now has ${attendeeCount} attendees`);
    
    // Only trigger at exactly 5 attendees
    if (attendeeCount !== 5) {
      console.log(`⏭️ Attendee count is ${attendeeCount}, not 5. Skipping.`);
      return null;
    }
    
    // Get event details (check both events and userEvents collections)
    let eventDoc = await db.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      eventDoc = await db.collection('userEvents').doc(eventId).get();
    }
    
    if (!eventDoc.exists) {
      console.log('⚠️ Event not found in events or userEvents');
      return null;
    }
    
    const event = eventDoc.data();
    const eventLat = event.latitude;
    const eventLon = event.longitude;
    const eventGeohash = event.geohash;
    const eventTitle = event.title || 'Event';
    const eventLocationName = event.locationName || 'a nearby location';
    const eventCategory = event.category || 'hangout';
    
    // Validate location data
    if (!eventGeohash || !eventLat || !eventLon) {
      console.log('⚠️ Event missing location data');
      return null;
    }
    
    // Get all attendee user IDs
    const attendeeUserIds = new Set();
    signalsSnapshot.forEach(doc => {
      const signalData = doc.data();
      if (signalData.userId) {
        attendeeUserIds.add(signalData.userId);
      }
    });
    
    console.log(`👥 Attendee user IDs: ${Array.from(attendeeUserIds).join(', ')}`);
    
    // Query nearby users who haven't joined
    const geohashPrefix = eventGeohash.substring(0, 5);
    
    try {
      const usersSnapshot = await db.collection('users')
        .where('geohash', '>=', geohashPrefix)
        .where('geohash', '<=', geohashPrefix + '\uf8ff')
        .get();
      
      console.log(`📍 Found ${usersSnapshot.size} users with similar geohash`);
      
      const notificationTargets = [];
      
      usersSnapshot.forEach(doc => {
        const userId = doc.id;
        const user = doc.data();
        
        // Skip if no FCM token
        if (!user.fcmToken) {
          return;
        }
        
        // Skip if user is already attending
        if (attendeeUserIds.has(userId)) {
          console.log(`⏭️ Skipping attendee: ${user.displayName}`);
          return;
        }
        
        // Check location data exists
        if (!user.location || !user.location.latitude || !user.location.longitude) {
          return;
        }
        
        // Calculate distance
        const distance = calculateDistance(
          eventLat,
          eventLon,
          user.location.latitude,
          user.location.longitude
        );
        
        // Filter by 1km radius
        if (distance > 1000) {
          return;
        }
        
        // User qualifies for notification
        notificationTargets.push({
          token: user.fcmToken,
          userId: userId,
          name: user.displayName,
          distance: Math.round(distance)
        });
        
        console.log(`✅ ${user.displayName} qualifies (${Math.round(distance)}m)`);
      });
      
      if (notificationTargets.length === 0) {
        console.log('📭 No users to notify about popular event');
        return null;
      }
      
      console.log(`📬 Sending to ${notificationTargets.length} user(s):`);
      notificationTargets.forEach(target => {
        console.log(`   - ${target.name} (${target.distance}m away)`);
      });
      
      const tokens = notificationTargets.map(t => t.token);
      
      const message = {
        tokens: tokens,
        notification: {
          title: 'This Crowd is popping off!',
          body: '5 are here. Join the Crowd.',
        },
        data: {
          eventId: eventId,
          type: 'popular_event',
          category: eventCategory,
          locationName: eventLocationName,
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: 'This Crowd is popping off!',
                body: '5 are here. Join the Crowd.',
              },
              sound: 'default',
              badge: 1,
              category: 'EVENT_INVITE',
              'thread-id': `event-${eventId}`,
              'content-available': 1,
              'mutable-content': 1,
            },
            eventId: eventId,
            eventCategory: eventCategory,
            eventLocationName: eventLocationName,
          },
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'event_notifications',
          },
        },
      };
      
      const response = await admin.messaging().sendMulticast(message);
      
      console.log(`✅ Successfully sent: ${response.successCount} notification(s)`);
      console.log(`❌ Failed to send: ${response.failureCount} notification(s)`);
      
      return response;
    } catch (error) {
      console.error('❌ Error in notifyPopularEvent:', error);
      return null;
    }
  });

// Scheduled: Study Session Reminder (12pm and 3pm daily)
exports.sendStudySessionReminder = functions.pubsub
  .schedule('0 12,15 * * *')  // Cron: 12pm and 3pm daily in UTC-6 (America/Chicago)
  .timeZone('America/Chicago')
  .onRun(async (context) => {
    console.log('📚 Study session reminder triggered');
    
    try {
      const usersSnapshot = await db.collection('users')
        .where('fcmToken', '!=', null)
        .get();
      
      if (usersSnapshot.empty) {
        console.log('📭 No users with FCM tokens found');
        return null;
      }
      
      const tokens = [];
      usersSnapshot.forEach(doc => {
        const user = doc.data();
        if (user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      });
      
      console.log(`📬 Sending study session reminder to ${tokens.length} user(s)`);
      
      const message = {
        tokens: tokens,
        notification: {
          title: 'Don\'t study solo.',
          body: 'Start a Crowd and find your study crew.',
        },
        data: {
          type: 'promotional',
          category: 'study',
        },
        apns: {
          headers: {
            'apns-priority': '5',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: 'Don\'t study solo.',
                body: 'Start a Crowd and find your study crew.',
              },
              sound: 'default',
            },
          },
        },
        android: {
          priority: 'normal',
          notification: {
            sound: 'default',
            channelId: 'promotional_notifications',
          },
        },
      };
      
      const response = await admin.messaging().sendMulticast(message);
      
      console.log(`✅ Successfully sent: ${response.successCount} notification(s)`);
      console.log(`❌ Failed to send: ${response.failureCount} notification(s)`);
      
      return response;
    } catch (error) {
      console.error('❌ Error in sendStudySessionReminder:', error);
      return null;
    }
  });

// Scheduled: Social Link Reminder (7:30pm and 10pm daily)
exports.sendSocialLinkReminder = functions.pubsub
  .schedule('30 19,22 * * *')  // Cron: 7:30pm and 10pm daily in UTC-6 (America/Chicago)
  .timeZone('America/Chicago')
  .onRun(async (context) => {
    console.log('👩‍❤️‍💋‍👨 Social link reminder triggered');
    
    try {
      const usersSnapshot = await db.collection('users')
        .where('fcmToken', '!=', null)
        .get();
      
      if (usersSnapshot.empty) {
        console.log('📭 No users with FCM tokens found');
        return null;
      }
      
      const tokens = [];
      usersSnapshot.forEach(doc => {
        const user = doc.data();
        if (user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      });
      
      console.log(`📬 Sending social link reminder to ${tokens.length} user(s)`);
      
      const message = {
        tokens: tokens,
        notification: {
          title: 'Start a crowd 👩‍❤️‍💋‍👨💋',
          body: 'Someone\'s always down to link.',
        },
        data: {
          type: 'promotional',
          category: 'social',
        },
        apns: {
          headers: {
            'apns-priority': '5',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: 'Start a crowd 👩‍❤️‍💋‍👨💋',
                body: 'Someone\'s always down to link.',
              },
              sound: 'default',
            },
          },
        },
        android: {
          priority: 'normal',
          notification: {
            sound: 'default',
            channelId: 'promotional_notifications',
          },
        },
      };
      
      const response = await admin.messaging().sendMulticast(message);
      
      console.log(`✅ Successfully sent: ${response.successCount} notification(s)`);
      console.log(`❌ Failed to send: ${response.failureCount} notification(s)`);
      
      return response;
    } catch (error) {
      console.error('❌ Error in sendSocialLinkReminder:', error);
      return null;
  }
});

// Scheduled: Anchor Notifications
// Runs every minute to check for anchors that need notifications sent
exports.sendAnchorNotifications = functions.pubsub
  .schedule('* * * * *')  // Every minute
  .timeZone('America/Chicago')
  .onRun(async (context) => {
    console.log('🔔 Anchor notification check triggered');
    
    try {
      const now = new Date();
      const chicagoTime = new Date(now.toLocaleString('en-US', { timeZone: 'America/Chicago' }));
      const currentHour = chicagoTime.getHours();
      const currentMinute = chicagoTime.getMinutes();
      const currentDay = chicagoTime.getDay(); // 0 = Sunday, 1 = Monday, etc.
      
      // Map day number to abbreviation
      const dayAbbrevs = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const currentDayAbbrev = dayAbbrevs[currentDay];
      
      // Get all anchors that should send notifications
      const anchorsSnapshot = await db.collection('anchors')
        .where('send_notification', '==', true)
        .get();
      
      if (anchorsSnapshot.empty) {
        console.log('📭 No anchors with notifications enabled');
        return null;
      }
      
      const notificationsToSend = [];
      
      anchorsSnapshot.forEach(doc => {
        const anchor = doc.data();
        const anchorId = anchor.id || doc.id;
        
        // Check if anchor is active today
        const daysActive = anchor.days_active || [];
        if (!daysActive.includes(currentDayAbbrev)) {
          return; // Skip if not active today
        }
        
        // Check notification time
        const notificationTime = anchor.notification_time_local;
        if (!notificationTime) {
          return; // Skip if no notification time
        }
        
        const [hour, minute] = notificationTime.split(':').map(Number);
        if (hour === currentHour && minute === currentMinute) {
          // Check if notification was already sent today
          const dateString = chicagoTime.toISOString().split('T')[0];
          const logId = `${anchorId}_${dateString}_${currentDay}`;
          
          notificationsToSend.push({
            anchorId,
            anchorName: anchor.name || 'Unknown Anchor',
            notificationMessage: anchor.notification_message || '',
            location: anchor.location || '',
            logId
          });
        }
      });
      
      if (notificationsToSend.length === 0) {
        console.log('📭 No anchor notifications to send at this time');
        return null;
      }
      
      // Check for duplicates and send notifications
      for (const notification of notificationsToSend) {
        // Check if already logged
        const logDoc = await db.collection('anchor_notification_logs').doc(notification.logId).get();
        if (logDoc.exists) {
          console.log(`⏭️ Skipping duplicate notification for anchor ${notification.anchorId}`);
          continue;
        }
        
        // Get all users with FCM tokens
        const usersSnapshot = await db.collection('users')
          .where('fcmToken', '!=', null)
          .get();
        
        if (usersSnapshot.empty) {
          console.log('📭 No users with FCM tokens found');
          continue;
        }
        
        const tokens = [];
        usersSnapshot.forEach(userDoc => {
          const user = userDoc.data();
          if (user.fcmToken) {
            tokens.push(user.fcmToken);
          }
        });
        
        console.log(`📬 Sending anchor notification for ${notification.anchorName} to ${tokens.length} user(s)`);
        
        const message = {
          tokens: tokens,
          notification: {
            title: notification.anchorName,
            body: notification.notificationMessage,
          },
          data: {
            type: 'anchor_notification',
            anchorId: notification.anchorId,
            anchorName: notification.anchorName,
            location: notification.location,
          },
          apns: {
            headers: {
              'apns-priority': '5',
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                alert: {
                  title: notification.anchorName,
                  body: notification.notificationMessage,
                },
                sound: 'default',
              },
            },
          },
          android: {
            priority: 'normal',
            notification: {
              sound: 'default',
              channelId: 'anchor_notifications',
            },
          },
        };
        
        const response = await admin.messaging().sendMulticast(message);
        
        console.log(`✅ Successfully sent: ${response.successCount} notification(s) for anchor ${notification.anchorId}`);
        console.log(`❌ Failed to send: ${response.failureCount} notification(s)`);
        
        // Log to Firestore to prevent duplicates
        await db.collection('anchor_notification_logs').doc(notification.logId).set({
          anchorId: notification.anchorId,
          anchorName: notification.anchorName,
          notificationTime: `${currentHour}:${currentMinute.toString().padStart(2, '0')}`,
          date: chicagoTime.toISOString().split('T')[0],
          weekday: currentDay,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          successCount: response.successCount,
          failureCount: response.failureCount
        });
      }
      
      return { success: true, sent: notificationsToSend.length };
    } catch (error) {
      console.error('❌ Error in sendAnchorNotifications:', error);
      return null;
    }
  });

// Auto-delete expired events from all collections
// Runs every hour and deletes events that have ended (with 1 hour grace period)
exports.cleanupExpiredEvents = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('Etc/UTC')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const nowSeconds = now.seconds || Math.floor(Date.now() / 1000);
    // Grace period: delete events that ended more than 1 hour ago
    const gracePeriodSeconds = 60 * 60; // 1 hour
    const cutoffTime = nowSeconds - gracePeriodSeconds;
    const cutoffTimestamp = admin.firestore.Timestamp.fromSeconds(cutoffTime);
    
    console.log('🧹 Starting expired events cleanup...');
    
    function normalizeEndsAt(endsAt) {
      if (!endsAt) return null;
      if (typeof endsAt === 'number') return endsAt;
      if (endsAt._seconds) return endsAt._seconds; // Firestore Timestamp object
      if (endsAt.seconds) return endsAt.seconds; // Firestore Timestamp (alternative format)
      return null;
    }
    
    function normalizeExpiresAt(expiresAt) {
      if (!expiresAt) return null;
      if (typeof expiresAt === 'number') return expiresAt;
      if (expiresAt._seconds) return expiresAt._seconds;
      if (expiresAt.seconds) return expiresAt.seconds;
      return null;
    }
    
    async function deleteExpiredFromCollection(collectionName) {
      const expiredEventIds = [];
      
      // Try to use Firestore query to find expired events by expiresAt field (if it exists)
      // This is more efficient than fetching all documents
      try {
        const expiresAtQuery = await db.collection(collectionName)
          .where('expiresAt', '<=', cutoffTimestamp)
          .limit(500)
          .get();
        
        expiresAtQuery.forEach(doc => {
          expiredEventIds.push({ id: doc.id, type: collectionName });
        });
        
        console.log(`📍 Found ${expiresAtQuery.size} expired event(s) via expiresAt query in ${collectionName}`);
      } catch (error) {
        console.log(`⚠️ Could not query by expiresAt in ${collectionName}: ${error.message}`);
      }
      
      // Also query by endsAt field for events that have that field
      try {
        const endsAtTimestamp = admin.firestore.Timestamp.fromSeconds(cutoffTime);
        const endsAtQuery = await db.collection(collectionName)
          .where('endsAt', '<=', endsAtTimestamp)
          .limit(500)
          .get();
        
        endsAtQuery.forEach(doc => {
          const docId = doc.id;
          // Avoid duplicates
          if (!expiredEventIds.find(e => e.id === docId)) {
            expiredEventIds.push({ id: docId, type: collectionName });
          }
        });
        
        console.log(`📍 Found ${endsAtQuery.size} expired event(s) via endsAt query in ${collectionName}`);
      } catch (error) {
        console.log(`⚠️ Could not query by endsAt in ${collectionName}: ${error.message}`);
      }
      
      // For events without endsAt or expiresAt, we need to check all documents
      // This is a fallback for older events that might not have these fields indexed
      // Limit this check to avoid timeout on large collections
      try {
        const allDocsSnapshot = await db.collection(collectionName)
          .limit(1000)
          .get();
        
        allDocsSnapshot.forEach(doc => {
          const docId = doc.id;
          // Skip if already marked for deletion
          if (expiredEventIds.find(e => e.id === docId)) return;
          
          const data = doc.data();
          const endsAt = normalizeEndsAt(data.endsAt);
          const expiresAt = normalizeExpiresAt(data.expiresAt);
          
          // If no endsAt or expiresAt, check createdAt + reasonable default (24 hours)
          if (!endsAt && !expiresAt) {
            const createdAt = normalizeEndsAt(data.createdAt);
            if (createdAt && createdAt < cutoffTime - (23 * 60 * 60)) { // 23 hours ago (24h default - 1h grace)
              expiredEventIds.push({ id: docId, type: collectionName });
            }
          } else if (expiresAt && expiresAt < cutoffTime) {
            expiredEventIds.push({ id: docId, type: collectionName });
          } else if (endsAt && endsAt < cutoffTime) {
            expiredEventIds.push({ id: docId, type: collectionName });
          }
        });
      } catch (error) {
        console.log(`⚠️ Error in fallback scan for ${collectionName}: ${error.message}`);
      }
      
      if (expiredEventIds.length === 0) {
        return { deleted: 0, collectionName };
      }
      
      console.log(`🗑️ Found ${expiredEventIds.length} total expired event(s) in ${collectionName}`);
      
      // Delete related data first (signals, attendances, chats)
      for (const event of expiredEventIds) {
        const eventId = event.id;
        
        // Delete signals for this event
        const signalsSnapshot = await db.collection('signals')
          .where('eventId', '==', eventId)
          .get();
        if (!signalsSnapshot.empty) {
          const batch = db.batch();
          signalsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          console.log(`   🗑️ Deleted ${signalsSnapshot.size} signal(s) for event ${eventId}`);
        }
        
        // Delete attendances for this event
        const attendancesSnapshot = await db.collection('userAttendances')
          .where('eventId', '==', eventId)
          .get();
        if (!attendancesSnapshot.empty) {
          const batch = db.batch();
          attendancesSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          console.log(`   🗑️ Deleted ${attendancesSnapshot.size} attendance(s) for event ${eventId}`);
        }
        
        // Delete chat messages for this event (subcollection)
        const messagesRef = db.collection('eventChats').doc(eventId).collection('messages');
        let deletedMessages = 0;
        while (true) {
          const messagesSnap = await messagesRef.limit(500).get();
          if (messagesSnap.empty) break;
          const batch = db.batch();
          messagesSnap.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          deletedMessages += messagesSnap.size;
          if (messagesSnap.size < 500) break;
        }
        
        // Delete parent chat doc if exists
        await db.collection('eventChats').doc(eventId).delete().catch(() => {});
        if (deletedMessages > 0) {
          console.log(`   🗑️ Deleted ${deletedMessages} message(s) and chat doc for event ${eventId}`);
        }
        
        // Finally, delete the event itself
        await db.collection(collectionName).doc(eventId).delete();
        console.log(`   ✅ Deleted event ${eventId} from ${collectionName}`);
      }
      
      return { deleted: expiredEventIds.length, collectionName };
    }
    
    // Clean up all event collections in parallel
    const results = await Promise.all([
      deleteExpiredFromCollection('events'),
      deleteExpiredFromCollection('userEvents'),
      deleteExpiredFromCollection('campus_events_live'),
    ]);
    
    const totalDeleted = results.reduce((sum, r) => sum + r.deleted, 0);
    console.log(`✅ Expired events cleanup complete: ${totalDeleted} event(s) deleted`);
    console.log(`   - ${results[0].deleted} from events collection`);
    console.log(`   - ${results[1].deleted} from userEvents collection`);
    console.log(`   - ${results[2].deleted} from campus_events_live collection`);
    
    return null;
  });

// Scheduled: Aggregate Daily Active Users (DAU) metrics
// Runs daily at midnight UTC to process yesterday's activity logs
exports.aggregateDailyDAU = functions.pubsub
  .schedule('0 0 * * *')  // Cron: midnight UTC daily
  .timeZone('Etc/UTC')
  .onRun(async (context) => {
    console.log('📊 Starting DAU aggregation...');
    
    // Calculate yesterday's date in YYYY-MM-DD format
    const yesterday = new Date();
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const year = yesterday.getUTCFullYear();
    const month = String(yesterday.getUTCMonth() + 1).padStart(2, '0');
    const day = String(yesterday.getUTCDate()).padStart(2, '0');
    const dateString = `${year}-${month}-${day}`;
    
    console.log(`📅 Processing date: ${dateString}`);
    
    try {
      // Query all events from yesterday's activity_logs
      const eventsRef = db.collection('activity_logs')
        .doc(dateString)
        .collection('events');
      
      const eventsSnapshot = await eventsRef.get();
      
      if (eventsSnapshot.empty) {
        console.log(`⚠️ No events found for ${dateString}`);
        // Still create a metrics document with zero values
        await db.collection('metrics').doc('daily').collection('daily').doc(dateString).set({
          date: dateString,
          dau: 0,
          zoneCounts: {},
          totalEvents: 0,
          aggregatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        console.log(`✅ Created empty metrics document for ${dateString}`);
        return null;
      }
      
      console.log(`📊 Found ${eventsSnapshot.size} events to process`);
      
      // Aggregate data
      const uniqueUsers = new Set();
      const zoneUserMap = new Map(); // zone -> Set of userIds
      let totalEvents = 0;
      
      eventsSnapshot.forEach(doc => {
        const eventData = doc.data();
        const userId = eventData.userId;
        const zone = eventData.zone;
        
        // Count unique users
        if (userId) {
          uniqueUsers.add(userId);
          
          // Count users per zone
          if (zone) {
            if (!zoneUserMap.has(zone)) {
              zoneUserMap.set(zone, new Set());
            }
            zoneUserMap.get(zone).add(userId);
          }
        }
        
        totalEvents++;
      });
      
      // Convert zoneUserMap to zoneCounts object
      const zoneCounts = {};
      zoneUserMap.forEach((userSet, zone) => {
        zoneCounts[zone] = userSet.size;
      });
      
      const dau = uniqueUsers.size;
      
      console.log(`📊 Aggregation results:`);
      console.log(`   - DAU: ${dau}`);
      console.log(`   - Total events: ${totalEvents}`);
      console.log(`   - Zones: ${Object.keys(zoneCounts).length}`);
      
      // Save to metrics/daily/{date}
      const metricsData = {
        date: dateString,
        dau: dau,
        zoneCounts: zoneCounts,
        totalEvents: totalEvents,
        aggregatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      await db.collection('metrics').doc('daily').collection('daily').doc(dateString).set(metricsData, { merge: true });
      
      console.log(`✅ DAU metrics saved for ${dateString}`);
      console.log(`   - Unique users: ${dau}`);
      console.log(`   - Zone breakdown:`, zoneCounts);
      
      return null;
    } catch (error) {
      console.error('❌ Error aggregating DAU:', error);
      return null;
    }
  });

// === Content Moderation: Process Flagged Content Reports ===
// Scheduled function that runs every hour to check for reports older than 24 hours
// Automatically removes content and ejects users if not manually reviewed
exports.processFlaggedContent = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('Etc/UTC')
  .onRun(async (context) => {
    console.log('🚨 Starting flagged content review process...');
    
    const now = admin.firestore.Timestamp.now();
    const nowSeconds = now.seconds || Math.floor(Date.now() / 1000);
    const twentyFourHoursAgo = nowSeconds - (24 * 60 * 60); // 24 hours in seconds
    const cutoffTimestamp = admin.firestore.Timestamp.fromSeconds(twentyFourHoursAgo);
    
    try {
      // Process flagged events
      const flaggedEventsSnapshot = await db.collection('flaggedEvents')
        .where('status', '==', 'pending')
        .where('createdAt', '<=', cutoffTimestamp)
        .get();
      
      console.log(`📋 Found ${flaggedEventsSnapshot.size} flagged event(s) older than 24 hours`);
      
      for (const flagDoc of flaggedEventsSnapshot.docs) {
        const flagData = flagDoc.data();
        const eventId = flagData.eventId;
        const reportedBy = flagData.reportedBy;
        const reason = flagData.reason || 'No reason provided';
        
        console.log(`🚨 Processing flagged event: ${eventId} (reported by: ${reportedBy})`);
        
        // Get the event to find the host
        let eventDoc = await db.collection('events').doc(eventId).get();
        let eventCollection = 'events';
        
        if (!eventDoc.exists) {
          eventDoc = await db.collection('userEvents').doc(eventId).get();
          eventCollection = 'userEvents';
        }
        
        if (!eventDoc.exists) {
          console.log(`⚠️ Event ${eventId} not found, marking flag as resolved`);
          await flagDoc.ref.update({
            status: 'resolved',
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
            resolution: 'event_not_found',
            resolvedBy: 'system'
          });
          continue;
        }
        
        const event = eventDoc.data();
        const hostId = event.hostId;
        
        // Remove the event
        console.log(`🗑️ Removing event: ${eventId}`);
        await db.collection(eventCollection).doc(eventId).delete();
        
        // Delete related data
        // Delete signals
        const signalsSnapshot = await db.collection('signals')
          .where('eventId', '==', eventId)
          .get();
        if (!signalsSnapshot.empty) {
          const batch = db.batch();
          signalsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          console.log(`   🗑️ Deleted ${signalsSnapshot.size} signal(s)`);
        }
        
        // Delete attendances
        const attendancesSnapshot = await db.collection('userAttendances')
          .where('eventId', '==', eventId)
          .get();
        if (!attendancesSnapshot.empty) {
          const batch = db.batch();
          attendancesSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          console.log(`   🗑️ Deleted ${attendancesSnapshot.size} attendance(s)`);
        }
        
        // Delete chat messages
        const messagesRef = db.collection('eventChats').doc(eventId).collection('messages');
        let deletedMessages = 0;
        while (true) {
          const messagesSnap = await messagesRef.limit(500).get();
          if (messagesSnap.empty) break;
          const batch = db.batch();
          messagesSnap.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          deletedMessages += messagesSnap.size;
          if (messagesSnap.size < 500) break;
        }
        await db.collection('eventChats').doc(eventId).delete().catch(() => {});
        if (deletedMessages > 0) {
          console.log(`   🗑️ Deleted ${deletedMessages} chat message(s)`);
        }
        
        // Eject the user (ban them)
        if (hostId) {
          console.log(`👢 Ejecting user: ${hostId}`);
          
          // Mark user as banned
          await db.collection('users').doc(hostId).update({
            banned: true,
            bannedAt: admin.firestore.FieldValue.serverTimestamp(),
            banReason: `Content violation: ${reason}`,
            bannedBy: 'system_auto_moderation'
          });
          
          // Delete all events created by this user
          const userEventsSnapshot = await db.collection('events')
            .where('hostId', '==', hostId)
            .get();
          const userEventsSnapshot2 = await db.collection('userEvents')
            .where('hostId', '==', hostId)
            .get();
          
          const allUserEvents = [...userEventsSnapshot.docs, ...userEventsSnapshot2.docs];
          if (allUserEvents.length > 0) {
            console.log(`   🗑️ Deleting ${allUserEvents.length} event(s) created by banned user`);
            for (const eventDoc of allUserEvents) {
              await eventDoc.ref.delete();
            }
          }
          
          // Remove all signals from this user
          const userSignalsSnapshot = await db.collection('signals')
            .where('userId', '==', hostId)
            .get();
          if (!userSignalsSnapshot.empty) {
            const batch = db.batch();
            userSignalsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            console.log(`   🗑️ Deleted ${userSignalsSnapshot.size} signal(s) from banned user`);
          }
        }
        
        // Mark flag as resolved
        await flagDoc.ref.update({
          status: 'resolved',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolution: 'content_removed_user_ejected',
          resolvedBy: 'system_auto_moderation',
          eventRemoved: true,
          userEjected: hostId || null
        });
        
        console.log(`✅ Processed flagged event ${eventId}: content removed, user ${hostId} ejected`);
      }
      
      // Process flagged users
      const flaggedUsersSnapshot = await db.collection('flaggedUsers')
        .where('status', '==', 'pending')
        .where('createdAt', '<=', cutoffTimestamp)
        .get();
      
      console.log(`📋 Found ${flaggedUsersSnapshot.size} flagged user(s) older than 24 hours`);
      
      for (const flagDoc of flaggedUsersSnapshot.docs) {
        const flagData = flagDoc.data();
        const userId = flagData.userId;
        const reportedBy = flagData.reportedBy;
        const reason = flagData.reason || 'No reason provided';
        
        console.log(`🚨 Processing flagged user: ${userId} (reported by: ${reportedBy})`);
        
        // Check if user exists
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          console.log(`⚠️ User ${userId} not found, marking flag as resolved`);
          await flagDoc.ref.update({
            status: 'resolved',
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
            resolution: 'user_not_found',
            resolvedBy: 'system'
          });
          continue;
        }
        
        // Ban the user
        console.log(`👢 Banning user: ${userId}`);
        await db.collection('users').doc(userId).update({
          banned: true,
          bannedAt: admin.firestore.FieldValue.serverTimestamp(),
          banReason: `User violation: ${reason}`,
          bannedBy: 'system_auto_moderation'
        });
        
        // Delete all events created by this user
        const userEventsSnapshot = await db.collection('events')
          .where('hostId', '==', userId)
          .get();
        const userEventsSnapshot2 = await db.collection('userEvents')
          .where('hostId', '==', userId)
          .get();
        
        const allUserEvents = [...userEventsSnapshot.docs, ...userEventsSnapshot2.docs];
        if (allUserEvents.length > 0) {
          console.log(`   🗑️ Deleting ${allUserEvents.length} event(s) created by banned user`);
          for (const eventDoc of allUserEvents) {
            const eventId = eventDoc.id;
            await eventDoc.ref.delete();
            
            // Clean up related data
            const signalsSnapshot = await db.collection('signals')
              .where('eventId', '==', eventId)
              .get();
            if (!signalsSnapshot.empty) {
              const batch = db.batch();
              signalsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
              await batch.commit();
            }
          }
        }
        
        // Remove all signals from this user
        const userSignalsSnapshot = await db.collection('signals')
          .where('userId', '==', userId)
          .get();
        if (!userSignalsSnapshot.empty) {
          const batch = db.batch();
          userSignalsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
          console.log(`   🗑️ Deleted ${userSignalsSnapshot.size} signal(s) from banned user`);
        }
        
        // Mark flag as resolved
        await flagDoc.ref.update({
          status: 'resolved',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolution: 'user_banned',
          resolvedBy: 'system_auto_moderation',
          userBanned: true
        });
        
        console.log(`✅ Processed flagged user ${userId}: user banned, all content removed`);
      }
      
      const totalProcessed = flaggedEventsSnapshot.size + flaggedUsersSnapshot.size;
      console.log(`✅ Flagged content review complete: ${totalProcessed} report(s) processed`);
      
      return { success: true, eventsProcessed: flaggedEventsSnapshot.size, usersProcessed: flaggedUsersSnapshot.size };
    } catch (error) {
      console.error('❌ Error processing flagged content:', error);
      return null;
    }
  });

// === Account Deletion: Permanently delete user account and all data ===
// Per App Store requirements: complete deletion, not deactivation
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  console.log(`🗑️ Starting account deletion for user: ${userId}`);
  
  try {
    // 1. Delete all events created by the user
    const eventsSnapshot = await db.collection('events')
      .where('hostId', '==', userId)
      .get();
    
    for (const doc of eventsSnapshot.docs) {
      const eventId = doc.id;
      
      // Delete related signals
      const signalsSnapshot = await db.collection('signals')
        .where('eventId', '==', eventId)
        .get();
      if (!signalsSnapshot.empty) {
        const batch = db.batch();
        signalsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
      }
      
      // Delete related chat messages
      const messagesRef = db.collection('eventChats').doc(eventId).collection('messages');
      while (true) {
        const messagesSnap = await messagesRef.limit(500).get();
        if (messagesSnap.empty) break;
        const batch = db.batch();
        messagesSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        if (messagesSnap.size < 500) break;
      }
      await db.collection('eventChats').doc(eventId).delete().catch(() => {});
      
      // Delete the event
      await doc.ref.delete();
    }
    console.log(`   ✓ Deleted ${eventsSnapshot.size} events`);
    
    // Delete from userEvents collection
    const userEventsSnapshot = await db.collection('userEvents')
      .where('hostId', '==', userId)
      .get();
    
    for (const doc of userEventsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`   ✓ Deleted ${userEventsSnapshot.size} userEvents`);
    
    // 2. Delete all signals from this user
    const userSignalsSnapshot = await db.collection('signals')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of userSignalsSnapshot.docs) {
      // Decrement attendee count on the event
      const eventId = doc.data().eventId;
      if (eventId) {
        await db.collection('events').doc(eventId).update({
          attendeeCount: admin.firestore.FieldValue.increment(-1)
        }).catch(() => {});
        await db.collection('userEvents').doc(eventId).update({
          attendeeCount: admin.firestore.FieldValue.increment(-1)
        }).catch(() => {});
      }
      await doc.ref.delete();
    }
    console.log(`   ✓ Deleted ${userSignalsSnapshot.size} signals`);
    
    // 3. Delete user attendances
    const attendancesSnapshot = await db.collection('userAttendances')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of attendancesSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`   ✓ Deleted ${attendancesSnapshot.size} attendances`);
    
    // 4. Delete chat messages from this user
    const eventChatsSnapshot = await db.collection('eventChats').get();
    let deletedMessages = 0;
    for (const chatDoc of eventChatsSnapshot.docs) {
      const messagesSnapshot = await chatDoc.ref.collection('messages')
        .where('senderId', '==', userId)
        .get();
      
      for (const messageDoc of messagesSnapshot.docs) {
        await messageDoc.ref.delete();
        deletedMessages++;
      }
    }
    console.log(`   ✓ Deleted ${deletedMessages} chat messages`);
    
    // 5. Delete hidden events records
    const hiddenSnapshot = await db.collection('hiddenEvents')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of hiddenSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`   ✓ Deleted ${hiddenSnapshot.size} hidden events records`);
    
    // 6. Delete flag reports made by this user
    const eventFlagsSnapshot = await db.collection('flaggedEvents')
      .where('reportedBy', '==', userId)
      .get();
    
    for (const doc of eventFlagsSnapshot.docs) {
      await doc.ref.delete();
    }
    
    const userFlagsSnapshot = await db.collection('flaggedUsers')
      .where('reportedBy', '==', userId)
      .get();
    
    for (const doc of userFlagsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`   ✓ Deleted flag reports`);
    
    // 7. Delete user profile
    await db.collection('users').doc(userId).delete();
    console.log(`   ✓ Deleted user profile`);
    
    // 8. Delete Firebase Auth account
    await admin.auth().deleteUser(userId);
    console.log(`   ✓ Deleted Firebase Auth account`);
    
    console.log(`✅ Account deletion complete for user: ${userId}`);
    
    return { success: true };
  } catch (error) {
    console.error('❌ Error deleting account:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// === Manual Review Function: Allow admins to manually process reports ===
exports.manualReviewReport = functions.https.onCall(async (data, context) => {
  // Note: In production, add admin authentication check here
  // if (!context.auth || !isAdmin(context.auth.uid)) {
  //   throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  // }
  
  try {
    const { flagId, type, action } = data; // type: 'event' or 'user', action: 'approve' or 'reject'
    
    if (!flagId || !type || !action) {
      throw new functions.https.HttpsError('invalid-argument', 'flagId, type, and action are required');
    }
    
    const collectionName = type === 'event' ? 'flaggedEvents' : 'flaggedUsers';
    const flagDoc = await db.collection(collectionName).doc(flagId).get();
    
    if (!flagDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Flag not found');
    }
    
    const flagData = flagDoc.data();
    
    if (action === 'approve') {
      // Same logic as automatic processing
      if (type === 'event') {
        const eventId = flagData.eventId;
        let eventDoc = await db.collection('events').doc(eventId).get();
        let eventCollection = 'events';
        if (!eventDoc.exists) {
          eventDoc = await db.collection('userEvents').doc(eventId).get();
          eventCollection = 'userEvents';
        }
        const hostId = eventDoc.exists ? eventDoc.data().hostId : null;
        
        if (eventDoc.exists) {
          await db.collection(eventCollection).doc(eventId).delete();
        }
        
        if (hostId) {
          await db.collection('users').doc(hostId).update({
            banned: true,
            bannedAt: admin.firestore.FieldValue.serverTimestamp(),
            banReason: `Content violation: ${flagData.reason || 'Manual review'}`,
            bannedBy: context.auth?.uid || 'admin'
          });
        }
        
        await flagDoc.ref.update({
          status: 'resolved',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolution: 'content_removed_user_ejected',
          resolvedBy: context.auth?.uid || 'admin',
          eventRemoved: true,
          userEjected: hostId || null
        });
      } else {
        // Ban user
        const userId = flagData.userId;
        await db.collection('users').doc(userId).update({
          banned: true,
          bannedAt: admin.firestore.FieldValue.serverTimestamp(),
          banReason: `User violation: ${flagData.reason || 'Manual review'}`,
          bannedBy: context.auth?.uid || 'admin'
        });
        
        await flagDoc.ref.update({
          status: 'resolved',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolution: 'user_banned',
          resolvedBy: context.auth?.uid || 'admin',
          userBanned: true
        });
      }
    } else {
      // Reject - mark as false positive
      await flagDoc.ref.update({
        status: 'resolved',
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        resolution: 'false_positive',
        resolvedBy: context.auth?.uid || 'admin'
      });
    }
    
    return { success: true };
  } catch (error) {
    console.error('❌ Error in manual review:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

