"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const Signal_1 = require("../models/Signal");
const Event_1 = require("../models/Event");
const uuid_1 = require("uuid");
const router = express_1.default.Router();
router.get('/', async (req, res) => {
    try {
        const { eventId, userId, signalType, page = 1, limit = 50 } = req.query;
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const skip = (pageNum - 1) * limitNum;
        const filter = {};
        if (eventId)
            filter.eventId = eventId;
        if (userId)
            filter.userId = userId;
        if (signalType)
            filter.signalType = signalType;
        const signals = await Signal_1.Signal.find(filter)
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limitNum)
            .populate('userId', 'displayName auraPoints')
            .populate('eventId', 'title latitude longitude');
        const total = await Signal_1.Signal.countDocuments(filter);
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
        console.error('Error fetching signals:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch signals'
        });
    }
});
router.get('/:id', async (req, res) => {
    try {
        const signal = await Signal_1.Signal.findOne({ id: req.params.id })
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
    }
    catch (error) {
        console.error('Error fetching signal:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch signal'
        });
    }
});
router.post('/', async (req, res) => {
    try {
        const { eventId, userId, signalType, strength, metadata } = req.body;
        if (!eventId || !userId || !signalType || strength === undefined) {
            return res.status(400).json({
                success: false,
                error: 'EventId, userId, signalType, and strength are required'
            });
        }
        const validTypes = ['join', 'leave', 'boost', 'checkin', 'checkout'];
        if (!validTypes.includes(signalType)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid signal type'
            });
        }
        const signal = new Signal_1.Signal({
            id: (0, uuid_1.v4)(),
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
        let updateQuery = { updatedAt: new Date() };
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
            await Event_1.Event.findOneAndUpdate({ id: eventId }, updateQuery);
        }
        res.status(201).json({
            success: true,
            data: signal
        });
    }
    catch (error) {
        console.error('Error creating signal:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to create signal'
        });
    }
});
router.get('/event/:eventId', async (req, res) => {
    try {
        const { page = 1, limit = 50 } = req.query;
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const skip = (pageNum - 1) * limitNum;
        const signals = await Signal_1.Signal.getRecentSignals(req.params.eventId, limitNum);
        res.json({
            success: true,
            data: signals
        });
    }
    catch (error) {
        console.error('Error fetching event signals:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch event signals'
        });
    }
});
router.get('/user/:userId', async (req, res) => {
    try {
        const { page = 1, limit = 50 } = req.query;
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const skip = (pageNum - 1) * limitNum;
        const signals = await Signal_1.Signal.getUserSignals(req.params.userId, limitNum);
        res.json({
            success: true,
            data: signals
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
exports.default = router;
//# sourceMappingURL=signals.js.map