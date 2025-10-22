import express from 'express';
import { Points } from '../models/Points';
import { User } from '../models/User';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// GET /api/points - Get points with filters
router.get('/', async (req, res) => {
  try {
    const { 
      userId, 
      eventId, 
      pointsType, 
      page = 1, 
      limit = 50 
    } = req.query;
    
    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    // Build filter
    const filter: any = {};
    if (userId) filter.userId = userId;
    if (eventId) filter.eventId = eventId;
    if (pointsType) filter.pointsType = pointsType;

    const points = await Points.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .populate('userId', 'displayName auraPoints')
      .populate('eventId', 'title');

    const total = await Points.countDocuments(filter);

    res.json({
      success: true,
      data: {
        points,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching points:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch points'
    });
  }
});

// GET /api/points/leaderboard - Get leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const { limit = 50 } = req.query;
    const limitNum = parseInt(limit as string);

    const leaderboard = await Points.getLeaderboard(limitNum);

    // Get user details for leaderboard
    const userIds = leaderboard.map(entry => entry._id);
    const users = await User.find({ id: { $in: userIds } });

    // Combine leaderboard with user details
    const leaderboardWithUsers = leaderboard.map(entry => {
      const user = users.find(u => u.id === entry._id);
      return {
        userId: entry._id,
        displayName: user?.displayName || 'Unknown',
        totalPoints: entry.totalPoints,
        lastActivity: entry.lastActivity
      };
    });

    res.json({
      success: true,
      data: leaderboardWithUsers
    });
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch leaderboard'
    });
  }
});

// GET /api/points/user/:userId/total - Get user's total points
router.get('/user/:userId/total', async (req, res) => {
  try {
    const result = await Points.getUserTotalPoints(req.params.userId);
    const totalPoints = result[0]?.totalPoints || 0;

    res.json({
      success: true,
      data: { totalPoints }
    });
  } catch (error) {
    console.error('Error fetching user total points:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user total points'
    });
  }
});

// GET /api/points/user/:userId/by-type - Get user's points by type
router.get('/user/:userId/by-type', async (req, res) => {
  try {
    const pointsByType = await Points.getUserPointsByType(req.params.userId);

    res.json({
      success: true,
      data: pointsByType
    });
  } catch (error) {
    console.error('Error fetching user points by type:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user points by type'
    });
  }
});

// POST /api/points - Award points manually (admin function)
router.post('/', async (req, res) => {
  try {
    const {
      userId,
      eventId,
      pointsType,
      points,
      description,
      metadata
    } = req.body;

    if (!userId || !pointsType || !points || !description) {
      return res.status(400).json({
        success: false,
        error: 'UserId, pointsType, points, and description are required'
      });
    }

    // Validate points type
    const validTypes = ['event_host', 'event_join', 'event_boost', 'checkin', 'social_share', 'daily_active', 'streak', 'bonus'];
    if (!validTypes.includes(pointsType)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid points type'
      });
    }

    const pointsRecord = new Points({
      id: uuidv4(),
      userId,
      eventId,
      pointsType,
      points: parseInt(points),
      description,
      metadata
    });

    await pointsRecord.save();

    // Update user's total aura points
    await User.findOneAndUpdate(
      { id: userId },
      { $inc: { auraPoints: parseInt(points) } }
    );

    res.status(201).json({
      success: true,
      data: pointsRecord
    });
  } catch (error) {
    console.error('Error awarding points:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to award points'
    });
  }
});

// POST /api/points/bulk - Award points to multiple users
router.post('/bulk', async (req, res) => {
  try {
    const { awards } = req.body;

    if (!Array.isArray(awards)) {
      return res.status(400).json({
        success: false,
        error: 'Awards must be an array'
      });
    }

    const results = [];

    for (const award of awards) {
      const {
        userId,
        eventId,
        pointsType,
        points,
        description,
        metadata
      } = award;

      if (!userId || !pointsType || !points || !description) {
        results.push({
          userId,
          success: false,
          error: 'Missing required fields'
        });
        continue;
      }

      try {
        const pointsRecord = new Points({
          id: uuidv4(),
          userId,
          eventId,
          pointsType,
          points: parseInt(points),
          description,
          metadata
        });

        await pointsRecord.save();

        // Update user's total aura points
        await User.findOneAndUpdate(
          { id: userId },
          { $inc: { auraPoints: parseInt(points) } }
        );

        results.push({
          userId,
          success: true,
          pointsRecord
        });
      } catch (error) {
        results.push({
          userId,
          success: false,
          error: error.message
        });
      }
    }

    res.json({
      success: true,
      data: results
    });
  } catch (error) {
    console.error('Error awarding bulk points:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to award bulk points'
    });
  }
});

export default router;

