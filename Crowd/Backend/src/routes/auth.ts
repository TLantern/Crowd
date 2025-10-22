import express from 'express';
import { User } from '../models/User';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// POST /api/auth/login - Simple login (for demo purposes)
router.post('/login', async (req, res) => {
  try {
    const { userId, displayName } = req.body;

    if (!userId || !displayName) {
      return res.status(400).json({
        success: false,
        error: 'User ID and display name are required'
      });
    }

    // Find or create user
    let user = await User.findOne({ id: userId });
    
    if (!user) {
      user = new User({
        id: userId,
        displayName,
        auraPoints: 0,
        preferences: {
          notifications: true,
          locationSharing: true
        }
      });
      await user.save();
    } else {
      // Update last active time
      user.lastActiveAt = new Date();
      await user.save();
    }

    return res.json({
      success: true,
      data: {
        user,
        token: `demo-token-${userId}` // In production, use JWT
      }
    });
  } catch (error) {
    console.error('Error during login:', error);
    res.status(500).json({
      success: false,
      error: 'Login failed'
    });
  }
});

// POST /api/auth/register - Register new user
router.post('/register', async (req, res) => {
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

    return res.status(201).json({
      success: true,
      data: {
        user,
        token: `demo-token-${id}` // In production, use JWT
      }
    });
  } catch (error) {
    console.error('Error during registration:', error);
    res.status(500).json({
      success: false,
      error: 'Registration failed'
    });
  }
});

// GET /api/auth/me - Get current user info
router.get('/me', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'No token provided'
      });
    }

    // Extract user ID from demo token
    const userId = token.replace('demo-token-', '');
    
    const user = await User.findOne({ id: userId });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    return res.json({
      success: true,
      data: user
    });
  } catch (error) {
    console.error('Error fetching user info:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user info'
    });
  }
});

// POST /api/auth/logout - Logout (for demo purposes)
router.post('/logout', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'No token provided'
      });
    }

    // Extract user ID from demo token
    const userId = token.replace('demo-token-', '');
    
    // Update last active time
    await User.findOneAndUpdate(
      { id: userId },
      { lastActiveAt: new Date() }
    );

    return res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Error during logout:', error);
    res.status(500).json({
      success: false,
      error: 'Logout failed'
    });
  }
});

export default router;

