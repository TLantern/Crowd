"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const User_1 = require("../models/User");
const router = express_1.default.Router();
router.post('/login', async (req, res) => {
    try {
        const { userId, displayName } = req.body;
        if (!userId || !displayName) {
            return res.status(400).json({
                success: false,
                error: 'User ID and display name are required'
            });
        }
        let user = await User_1.User.findOne({ id: userId });
        if (!user) {
            user = new User_1.User({
                id: userId,
                displayName,
                auraPoints: 0,
                preferences: {
                    notifications: true,
                    locationSharing: true
                }
            });
            await user.save();
        }
        else {
            user.lastActiveAt = new Date();
            await user.save();
        }
        return res.json({
            success: true,
            data: {
                user,
                token: `demo-token-${userId}`
            }
        });
    }
    catch (error) {
        console.error('Error during login:', error);
        res.status(500).json({
            success: false,
            error: 'Login failed'
        });
    }
});
router.post('/register', async (req, res) => {
    try {
        const { id, displayName, preferences } = req.body;
        if (!id || !displayName) {
            return res.status(400).json({
                success: false,
                error: 'ID and display name are required'
            });
        }
        const existingUser = await User_1.User.findOne({ id });
        if (existingUser) {
            return res.status(409).json({
                success: false,
                error: 'User already exists'
            });
        }
        const user = new User_1.User({
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
                token: `demo-token-${id}`
            }
        });
    }
    catch (error) {
        console.error('Error during registration:', error);
        res.status(500).json({
            success: false,
            error: 'Registration failed'
        });
    }
});
router.get('/me', async (req, res) => {
    try {
        const token = req.headers.authorization?.replace('Bearer ', '');
        if (!token) {
            return res.status(401).json({
                success: false,
                error: 'No token provided'
            });
        }
        const userId = token.replace('demo-token-', '');
        const user = await User_1.User.findOne({ id: userId });
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
    }
    catch (error) {
        console.error('Error fetching user info:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch user info'
        });
    }
});
router.post('/logout', async (req, res) => {
    try {
        const token = req.headers.authorization?.replace('Bearer ', '');
        if (!token) {
            return res.status(401).json({
                success: false,
                error: 'No token provided'
            });
        }
        const userId = token.replace('demo-token-', '');
        await User_1.User.findOneAndUpdate({ id: userId }, { lastActiveAt: new Date() });
        return res.json({
            success: true,
            message: 'Logged out successfully'
        });
    }
    catch (error) {
        console.error('Error during logout:', error);
        res.status(500).json({
            success: false,
            error: 'Logout failed'
        });
    }
});
exports.default = router;
//# sourceMappingURL=auth.js.map