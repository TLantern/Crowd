"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const Event_1 = require("../models/Event");
const Signal_1 = require("../models/Signal");
const Points_1 = require("../models/Points");
const uuid_1 = require("uuid");
const router = express_1.default.Router();
router.get('/', async (req, res) => {
    try {
        const { latitude, longitude, radius = 600, limit = 50 } = req.query;
        if (!latitude || !longitude) {
            return res.status(400).json({
                success: false,
                error: 'Latitude and longitude are required'
            });
        }
        const lat = parseFloat(latitude);
        const lon = parseFloat(longitude);
        const maxRadius = parseInt(radius);
        const limitNum = parseInt(limit);
        const events = await Event_1.Event.findEventsInRegion(lat, lon, maxRadius);
        const limitedEvents = events.slice(0, limitNum);
        res.json({
            success: true,
            data: limitedEvents
        });
    }
    catch (error) {
        console.error('Error fetching events:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch events'
        });
    }
});
router.get('/:id', async (req, res) => {
    try {
        const event = await Event_1.Event.findOne({ id: req.params.id })
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
    }
    catch (error) {
        console.error('Error fetching event:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch event'
        });
    }
});
router.post('/', async (req, res) => {
    try {
        const { title, hostId, latitude, longitude, radiusMeters = 60, startsAt, endsAt, tags = [], description, maxAttendees, region } = req.body;
        if (!title || !hostId || !latitude || !longitude) {
            return res.status(400).json({
                success: false,
                error: 'Title, hostId, latitude, and longitude are required'
            });
        }
        const event = new Event_1.Event({
            id: (0, uuid_1.v4)(),
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
        await Points_1.Points.create({
            id: (0, uuid_1.v4)(),
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
    }
    catch (error) {
        console.error('Error creating event:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to create event'
        });
    }
});
router.put('/:id', async (req, res) => {
    try {
        const event = await Event_1.Event.findOneAndUpdate({ id: req.params.id }, { ...req.body, updatedAt: new Date() }, { new: true });
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
    }
    catch (error) {
        console.error('Error updating event:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to update event'
        });
    }
});
router.delete('/:id', async (req, res) => {
    try {
        const event = await Event_1.Event.findOneAndUpdate({ id: req.params.id }, { isActive: false, updatedAt: new Date() }, { new: true });
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
    }
    catch (error) {
        console.error('Error deleting event:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to delete event'
        });
    }
});
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
        const event = await Event_1.Event.findOne({ id: eventId, isActive: true });
        if (!event) {
            return res.status(404).json({
                success: false,
                error: 'Event not found or inactive'
            });
        }
        const signal = new Signal_1.Signal({
            id: (0, uuid_1.v4)(),
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
        const updatedEvent = await Event_1.Event.findOneAndUpdate({ id: eventId }, {
            $inc: { attendeeCount: 1, signalStrength: 2 },
            $set: { updatedAt: new Date() }
        }, { new: true });
        await Points_1.Points.create({
            id: (0, uuid_1.v4)(),
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
    }
    catch (error) {
        console.error('Error joining event:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to join event'
        });
    }
});
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
        const signal = new Signal_1.Signal({
            id: (0, uuid_1.v4)(),
            eventId,
            userId,
            signalType: 'leave',
            strength: -1,
            metadata: {
                timestamp: new Date()
            }
        });
        await signal.save();
        const updatedEvent = await Event_1.Event.findOneAndUpdate({ id: eventId }, {
            $inc: { attendeeCount: -1, signalStrength: -1 },
            $set: { updatedAt: new Date() }
        }, { new: true });
        res.json({
            success: true,
            data: {
                event: updatedEvent,
                signal
            }
        });
    }
    catch (error) {
        console.error('Error leaving event:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to leave event'
        });
    }
});
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
        const signal = new Signal_1.Signal({
            id: (0, uuid_1.v4)(),
            eventId,
            userId,
            signalType: 'boost',
            strength: parseInt(delta),
            metadata: {
                timestamp: new Date()
            }
        });
        await signal.save();
        const updatedEvent = await Event_1.Event.findOneAndUpdate({ id: eventId }, {
            $inc: { signalStrength: parseInt(delta) },
            $set: { updatedAt: new Date() }
        }, { new: true });
        const points = Math.abs(parseInt(delta)) * 2;
        await Points_1.Points.create({
            id: (0, uuid_1.v4)(),
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
    }
    catch (error) {
        console.error('Error boosting signal:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to boost signal'
        });
    }
});
exports.default = router;
//# sourceMappingURL=events.js.map