import express from 'express';
import { Signal } from '../models/Signal';
import { Points } from '../models/Points';
import { Event } from '../models/Event';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// GET /api/signals - Get signals with filters
router.get('/', async (req, res) => {
  try {
    const { 
      eventId, 
      userId, 
      signalType, 
      page = 1, 
      limit = 50 
    } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    // Build filter
    const filter: any = {};
    if (eventId) filter.eventId = eventId;
    if (userId) filter.userId = userId;
    if (signalType) filter.signalType = signalType;

    const signals = await Signal.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .populate('userId', 'displayName auraPoints')
      .populate('eventId', 'title latitude longitude');

    const total = await Signal.countDocuments(filter);

    res.json({
      success: true,
      data: {
        signals,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching signals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch signals'
    });
  }
});

// GET /api/signals/:id - Get specific signal
router.get('/:id', async (req, res) => {
  try {
    const signal = await Signal.findOne({ id: req.params.id })
      .populate('userId', 'displayName auraPoints')
      .populate('eventId', 'title latitude longitude');

    if (!signal) {
      return res.status(404).json({
        success: false,
        error: 'Signal not found'
      });
    }

    res.json({
      success: true,
      data: signal
    });
  } catch (error) {
    console.error('Error fetching signal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch signal'
    });
  }
});

// POST /api/signals - Create new signal
router.post('/', async (req, res) => {
  try {
    const {
      eventId,
      userId,
      signalType,
      strength,
      metadata
    } = req.body;

    if (!eventId || !userId || !signalType || strength === undefined) {
      return res.status(400).json({
        success: false,
        error: 'EventId, userId, signalType, and strength are required'
      });
    }

    // Validate signal type
    const validTypes = ['join', 'leave', 'boost', 'checkin', 'checkout'];
    if (!validTypes.includes(signalType)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid signal type'
      });
    }

    const signal = new Signal({
      id: uuidv4(),
      eventId,
      userId,
      signalType,
      strength: parseInt(strength),
      metadata: {
        ...metadata,
        timestamp: new Date()
      }
    });

    await signal.save();

    // Update event based on signal type
    let updateQuery: any = { updatedAt: new Date() };
    
    switch (signalType) {
      case 'join':
        updateQuery.$inc = { attendeeCount: 1, signalStrength: Math.abs(parseInt(strength)) };
        break;
      case 'leave':
        updateQuery.$inc = { attendeeCount: -1, signalStrength: -Math.abs(parseInt(strength)) };
        break;
      case 'boost':
        updateQuery.$inc = { signalStrength: parseInt(strength) };
        break;
    }

    if (updateQuery.$inc) {
      await Event.findOneAndUpdate({ id: eventId }, updateQuery);
    }

    res.status(201).json({
      success: true,
      data: signal
    });
  } catch (error) {
    console.error('Error creating signal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create signal'
    });
  }
});

// GET /api/signals/event/:eventId - Get signals for specific event
router.get('/event/:eventId', async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const signals = await Signal.getRecentSignals(req.params.eventId, limitNum);

    res.json({
      success: true,
      data: signals
    });
  } catch (error) {
    console.error('Error fetching event signals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch event signals'
    });
  }
});

// GET /api/signals/user/:userId - Get signals for specific user
router.get('/user/:userId', async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const signals = await Signal.getUserSignals(req.params.userId, limitNum);

    res.json({
      success: true,
      data: signals
    });
  } catch (error) {
    console.error('Error fetching user signals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user signals'
    });
  }
});

export default router;

