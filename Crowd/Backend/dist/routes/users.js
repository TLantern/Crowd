"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const User_1 = require("../models/User");
const Points_1 = require("../models/Points");
const Signal_1 = require("../models/Signal");
const router = express_1.default.Router();
router.get('/', async (req, res) => {
    try {
        const { page = 1, limit = 20, sortBy = 'auraPoints', sortOrder = 'desc' } = req.query;
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const skip = (pageNum - 1) * limitNum;
        const sort = {};
        sort[sortBy] = sortOrder === 'desc' ? -1 : 1;
        const users = await User_1.User.find()
            .sort(sort)
            .skip(skip)
            .limit(limitNum);
        const total = await User_1.User.countDocuments();
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
    }
    catch (error) {
        console.error('Error fetching users:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch users'
        });
    }
});
router.get('/:id', async (req, res) => {
    try {
        const user = await User_1.User.findOne({ id: req.params.id });
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
    }
    catch (error) {
        console.error('Error fetching user:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch user'
        });
    }
});
router.post('/', async (req, res) => {
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
        res.status(201).json({
            success: true,
            data: user
        });
    }
    catch (error) {
        console.error('Error creating user:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to create user'
        });
    }
});
router.put('/:id', async (req, res) => {
    try {
        const user = await User_1.User.findOneAndUpdate({ id: req.params.id }, { ...req.body, updatedAt: new Date() }, { new: true });
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
    }
    catch (error) {
        console.error('Error updating user:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to update user'
        });
    }
});
router.get('/:id/points', async (req, res) => {
    try {
        const { page = 1, limit = 50 } = req.query;
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const skip = (pageNum - 1) * limitNum;
        const points = await Points_1.Points.find({ userId: req.params.id })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limitNum);
        const total = await Points_1.Points.countDocuments({ userId: req.params.id });
        const totalPointsResult = await Points_1.Points.getUserTotalPoints(req.params.id);
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
    }
    catch (error) {
        console.error('Error fetching user points:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch user points'
        });
    }
});
router.get('/:id/signals', async (req, res) => {
    try {
        const { page = 1, limit = 50 } = req.query;
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const skip = (pageNum - 1) * limitNum;
        const signals = await Signal_1.Signal.find({ userId: req.params.id })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limitNum)
            .populate('eventId', 'title latitude longitude');
        const total = await Signal_1.Signal.countDocuments({ userId: req.params.id });
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
    }
    catch (error) {
        console.error('Error fetching user signals:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch user signals'
        });
    }
});
router.get('/:id/stats', async (req, res) => {
    try {
        const userId = req.params.id;
        const user = await User_1.User.findOne({ id: userId });
        if (!user) {
            return res.status(404).json({
                success: false,
                error: 'User not found'
            });
        }
        const pointsByType = await Points_1.Points.getUserPointsByType(userId);
        const totalSignals = await Signal_1.Signal.countDocuments({ userId });
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
    }
    catch (error) {
        console.error('Error fetching user stats:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch user statistics'
        });
    }
});
exports.default = router;
//# sourceMappingURL=users.js.map