import express from 'express';
import { User } from '../models/User';
import { Points } from '../models/Points';
import { Signal } from '../models/Signal';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// GET /api/users - Get all users (with pagination)
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 20, sortBy = 'auraPoints', sortOrder = 'desc' } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const sort: any = {};
    sort[sortBy as string] = sortOrder === 'desc' ? -1 : 1;

    const users = await User.find()
      .sort(sort)
      .skip(skip)
      .limit(limitNum);

    const total = await User.countDocuments();

    res.json({
      success: true,
      data: {
        users,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch users'
    });
  }
});

// GET /api/users/:id - Get specific user
router.get('/:id', async (req, res) => {
  try {
    const user = await User.findOne({ id: req.params.id });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      data: user
    });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user'
    });
  }
});

// POST /api/users - Create new user
router.post('/', async (req, res) => {
  try {
    const { id, displayName, preferences } = req.body;

    if (!id || !displayName) {
      return res.status(400).json({
        success: false,
        error: 'ID and display name are required'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ id });
    if (existingUser) {
      return res.status(409).json({
        success: false,
        error: 'User already exists'
      });
    }

    const user = new User({
      id,
      displayName,
      auraPoints: 0,
      preferences: preferences || {
        notifications: true,
        locationSharing: true
      }
    });

    await user.save();

    res.status(201).json({
      success: true,
      data: user
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create user'
    });
  }
});

// PUT /api/users/:id - Update user
router.put('/:id', async (req, res) => {
  try {
    const user = await User.findOneAndUpdate(
      { id: req.params.id },
      { ...req.body, updatedAt: new Date() },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      data: user
    });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update user'
    });
  }
});

// GET /api/users/:id/points - Get user's points history
router.get('/:id/points', async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const points = await Points.find({ userId: req.params.id })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum);

    const total = await Points.countDocuments({ userId: req.params.id });

    // Get total points
    const totalPointsResult = await Points.getUserTotalPoints(req.params.id);
    const totalPoints = totalPointsResult[0]?.totalPoints || 0;

    res.json({
      success: true,
      data: {
        points,
        totalPoints,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching user points:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user points'
    });
  }
});

// GET /api/users/:id/signals - Get user's signal history
router.get('/:id/signals', async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const signals = await Signal.find({ userId: req.params.id })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .populate('eventId', 'title latitude longitude');

    const total = await Signal.countDocuments({ userId: req.params.id });

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
    console.error('Error fetching user signals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user signals'
    });
  }
});

// GET /api/users/:id/stats - Get user statistics
router.get('/:id/stats', async (req, res) => {
  try {
    const userId = req.params.id;

    // Get user
    const user = await User.findOne({ id: userId });
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Get points by type
    const pointsByType = await Points.getUserPointsByType(userId);

    // Get total signals
    const totalSignals = await Signal.countDocuments({ userId });

    // Get events hosted
    const eventsHosted = await require('../models/Event').Event.countDocuments({ hostId: userId });

    res.json({
      success: true,
      data: {
        user,
        stats: {
          totalPoints: user.auraPoints,
          pointsByType,
          totalSignals,
          eventsHosted
        }
      }
    });
  } catch (error) {
    console.error('Error fetching user stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user statistics'
    });
  }
});

export default router;

