import express from 'express';
import { Event } from '../models/Event';
import { Signal } from '../models/Signal';
import { Points } from '../models/Points';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// GET /api/events - Get events in a region
router.get('/', async (req, res) => {
  try {
    const { latitude, longitude, radius = 600, limit = 50 } = req.query;
    
    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        error: 'Latitude and longitude are required'
      });
    }

    const lat = parseFloat(latitude as string);
    const lon = parseFloat(longitude as string);
    const maxRadius = parseInt(radius as string);
    const limitNum = parseInt(limit as string);

    const events = await Event.findEventsInRegion(lat, lon, maxRadius);
    const limitedEvents = events.slice(0, limitNum);

    res.json({
      success: true,
      data: limitedEvents
    });
  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch events'
    });
  }
});

// GET /api/events/:id - Get specific event
router.get('/:id', async (req, res) => {
  try {
    const event = await Event.findOne({ id: req.params.id })
      .populate('hostId', 'displayName auraPoints');

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    res.json({
      success: true,
      data: event
    });
  } catch (error) {
    console.error('Error fetching event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch event'
    });
  }
});

// POST /api/events - Create new event
router.post('/', async (req, res) => {
  try {
    const {
      title,
      hostId,
      latitude,
      longitude,
      radiusMeters = 60,
      startsAt,
      endsAt,
      tags = [],
      description,
      maxAttendees,
      region
    } = req.body;

    if (!title || !hostId || !latitude || !longitude) {
      return res.status(400).json({
        success: false,
        error: 'Title, hostId, latitude, and longitude are required'
      });
    }

    const event = new Event({
      id: uuidv4(),
      title,
      hostId,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      radiusMeters: parseInt(radiusMeters),
      startsAt: startsAt ? new Date(startsAt) : undefined,
      endsAt: endsAt ? new Date(endsAt) : undefined,
      tags: Array.isArray(tags) ? tags : [],
      description,
      maxAttendees: maxAttendees ? parseInt(maxAttendees) : undefined,
      region,
      signalStrength: 0,
      attendeeCount: 0,
      isActive: true
    });

    await event.save();

    // Award points for hosting
    await Points.create({
      id: uuidv4(),
      userId: hostId,
      eventId: event.id,
      pointsType: 'event_host',
      points: 20,
      description: 'Hosted an event',
      metadata: {
        eventTitle: title
      }
    });

    res.status(201).json({
      success: true,
      data: event
    });
  } catch (error) {
    console.error('Error creating event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create event'
    });
  }
});

// PUT /api/events/:id - Update event
router.put('/:id', async (req, res) => {
  try {
    const event = await Event.findOneAndUpdate(
      { id: req.params.id },
      { ...req.body, updatedAt: new Date() },
      { new: true }
    );

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    res.json({
      success: true,
      data: event
    });
  } catch (error) {
    console.error('Error updating event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update event'
    });
  }
});

// DELETE /api/events/:id - Delete event
router.delete('/:id', async (req, res) => {
  try {
    const event = await Event.findOneAndUpdate(
      { id: req.params.id },
      { isActive: false, updatedAt: new Date() },
      { new: true }
    );

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    res.json({
      success: true,
      message: 'Event deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete event'
    });
  }
});

// POST /api/events/:id/join - Join event
router.post('/:id/join', async (req, res) => {
  try {
    const { userId, location } = req.body;
    const eventId = req.params.id;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'User ID is required'
      });
    }

    // Check if event exists and is active
    const event = await Event.findOne({ id: eventId, isActive: true });
    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found or inactive'
      });
    }

    // Create signal
    const signal = new Signal({
      id: uuidv4(),
      eventId,
      userId,
      signalType: 'join',
      strength: 2,
      metadata: {
        location,
        timestamp: new Date()
      }
    });
    await signal.save();

    // Update event
    const updatedEvent = await Event.findOneAndUpdate(
      { id: eventId },
      { 
        $inc: { attendeeCount: 1, signalStrength: 2 },
        $set: { updatedAt: new Date() }
      },
      { new: true }
    );

    // Award points
    await Points.create({
      id: uuidv4(),
      userId,
      eventId,
      pointsType: 'event_join',
      points: 10,
      description: 'Joined an event',
      metadata: {
        eventTitle: event.title
      }
    });

    res.json({
      success: true,
      data: {
        event: updatedEvent,
        signal
      }
    });
  } catch (error) {
    console.error('Error joining event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to join event'
    });
  }
});

// POST /api/events/:id/leave - Leave event
router.post('/:id/leave', async (req, res) => {
  try {
    const { userId } = req.body;
    const eventId = req.params.id;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'User ID is required'
      });
    }

    // Create signal
    const signal = new Signal({
      id: uuidv4(),
      eventId,
      userId,
      signalType: 'leave',
      strength: -1,
      metadata: {
        timestamp: new Date()
      }
    });
    await signal.save();

    // Update event
    const updatedEvent = await Event.findOneAndUpdate(
      { id: eventId },
      { 
        $inc: { attendeeCount: -1, signalStrength: -1 },
        $set: { updatedAt: new Date() }
      },
      { new: true }
    );

    res.json({
      success: true,
      data: {
        event: updatedEvent,
        signal
      }
    });
  } catch (error) {
    console.error('Error leaving event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to leave event'
    });
  }
});

// POST /api/events/:id/boost - Boost signal
router.post('/:id/boost', async (req, res) => {
  try {
    const { userId, delta } = req.body;
    const eventId = req.params.id;

    if (!userId || delta === undefined) {
      return res.status(400).json({
        success: false,
        error: 'User ID and delta are required'
      });
    }

    // Create signal
    const signal = new Signal({
      id: uuidv4(),
      eventId,
      userId,
      signalType: 'boost',
      strength: parseInt(delta),
      metadata: {
        timestamp: new Date()
      }
    });
    await signal.save();

    // Update event
    const updatedEvent = await Event.findOneAndUpdate(
      { id: eventId },
      { 
        $inc: { signalStrength: parseInt(delta) },
        $set: { updatedAt: new Date() }
      },
      { new: true }
    );

    // Award points based on boost strength
    const points = Math.abs(parseInt(delta)) * 2;
    await Points.create({
      id: uuidv4(),
      userId,
      eventId,
      pointsType: 'event_boost',
      points,
      description: `Boosted signal by ${delta}`,
      metadata: {
        eventTitle: updatedEvent?.title,
        signalStrength: parseInt(delta)
      }
    });

    res.json({
      success: true,
      data: {
        event: updatedEvent,
        signal
      }
    });
  } catch (error) {
    console.error('Error boosting signal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to boost signal'
    });
  }
});

export default router;

