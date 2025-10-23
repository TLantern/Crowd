"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SocketService = void 0;
const Event_1 = require("../models/Event");
const Signal_1 = require("../models/Signal");
const Points_1 = require("../models/Points");
const User_1 = require("../models/User");
const uuid_1 = require("uuid");
class SocketService {
    constructor(io) {
        this.connectedUsers = new Map();
        this.io = io;
        this.setupSocketHandlers();
    }
    setupSocketHandlers() {
        this.io.on('connection', (socket) => {
            console.log(`🔌 User connected: ${socket.id}`);
            socket.on('authenticate', async (data) => {
                try {
                    const { userId } = data;
                    this.connectedUsers.set(socket.id, userId);
                    socket.join(`user:${userId}`);
                    await User_1.User.findOneAndUpdate({ id: userId }, { lastActiveAt: new Date() });
                    socket.emit('authenticated', { success: true });
                    console.log(`✅ User ${userId} authenticated`);
                }
                catch (error) {
                    socket.emit('error', { message: 'Authentication failed' });
                    console.error('Authentication error:', error);
                }
            });
            socket.on('join_event', async (data) => {
                try {
                    const { eventId, userId, location } = data;
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
                    const event = await Event_1.Event.findOneAndUpdate({ id: eventId }, {
                        $inc: { attendeeCount: 1, signalStrength: 2 },
                        $set: { updatedAt: new Date() }
                    }, { new: true });
                    if (event) {
                        await this.awardPoints(userId, eventId, 'event_join', 10, 'Joined an event');
                        socket.join(`event:${eventId}`);
                        this.io.to(`event:${eventId}`).emit('event_updated', {
                            eventId,
                            attendeeCount: event.attendeeCount,
                            signalStrength: event.signalStrength,
                            newSignal: {
                                userId,
                                signalType: 'join',
                                strength: 2,
                                timestamp: new Date()
                            }
                        });
                        socket.emit('join_success', { eventId, attendeeCount: event.attendeeCount });
                    }
                }
                catch (error) {
                    socket.emit('error', { message: 'Failed to join event' });
                    console.error('Join event error:', error);
                }
            });
            socket.on('leave_event', async (data) => {
                try {
                    const { eventId, userId } = data;
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
                    const event = await Event_1.Event.findOneAndUpdate({ id: eventId }, {
                        $inc: { attendeeCount: -1, signalStrength: -1 },
                        $set: { updatedAt: new Date() }
                    }, { new: true });
                    if (event) {
                        socket.leave(`event:${eventId}`);
                        this.io.to(`event:${eventId}`).emit('event_updated', {
                            eventId,
                            attendeeCount: event.attendeeCount,
                            signalStrength: event.signalStrength,
                            newSignal: {
                                userId,
                                signalType: 'leave',
                                strength: -1,
                                timestamp: new Date()
                            }
                        });
                        socket.emit('leave_success', { eventId, attendeeCount: event.attendeeCount });
                    }
                }
                catch (error) {
                    socket.emit('error', { message: 'Failed to leave event' });
                    console.error('Leave event error:', error);
                }
            });
            socket.on('boost_signal', async (data) => {
                try {
                    const { eventId, userId, delta } = data;
                    const signal = new Signal_1.Signal({
                        id: (0, uuid_1.v4)(),
                        eventId,
                        userId,
                        signalType: 'boost',
                        strength: delta,
                        metadata: {
                            timestamp: new Date()
                        }
                    });
                    await signal.save();
                    const event = await Event_1.Event.findOneAndUpdate({ id: eventId }, {
                        $inc: { signalStrength: delta },
                        $set: { updatedAt: new Date() }
                    }, { new: true });
                    if (event) {
                        const points = Math.abs(delta) * 2;
                        await this.awardPoints(userId, eventId, 'event_boost', points, `Boosted signal by ${delta}`);
                        this.io.to(`event:${eventId}`).emit('event_updated', {
                            eventId,
                            signalStrength: event.signalStrength,
                            newSignal: {
                                userId,
                                signalType: 'boost',
                                strength: delta,
                                timestamp: new Date()
                            }
                        });
                        socket.emit('boost_success', { eventId, signalStrength: event.signalStrength });
                    }
                }
                catch (error) {
                    socket.emit('error', { message: 'Failed to boost signal' });
                    console.error('Boost signal error:', error);
                }
            });
            socket.on('location_update', async (data) => {
                try {
                    const { userId, latitude, longitude } = data;
                    const nearbyEvents = await Event_1.Event.findEventsInRegion(latitude, longitude, 1000);
                    nearbyEvents.forEach(event => {
                        socket.join(`event:${event.id}`);
                    });
                    socket.emit('nearby_events', { events: nearbyEvents });
                }
                catch (error) {
                    console.error('Location update error:', error);
                }
            });
            socket.on('disconnect', () => {
                const userId = this.connectedUsers.get(socket.id);
                if (userId) {
                    console.log(`🔌 User disconnected: ${userId}`);
                    this.connectedUsers.delete(socket.id);
                }
            });
        });
    }
    async awardPoints(userId, eventId, pointsType, points, description) {
        try {
            const pointsRecord = new Points_1.Points({
                id: (0, uuid_1.v4)(),
                userId,
                eventId,
                pointsType: pointsType,
                points,
                description
            });
            await pointsRecord.save();
            await User_1.User.findOneAndUpdate({ id: userId }, { $inc: { auraPoints: points } });
            this.io.to(`user:${userId}`).emit('points_earned', {
                points,
                description,
                totalPoints: await this.getUserTotalPoints(userId)
            });
        }
        catch (error) {
            console.error('Error awarding points:', error);
        }
    }
    async getUserTotalPoints(userId) {
        try {
            const result = await Points_1.Points.getUserTotalPoints(userId);
            return result[0]?.totalPoints || 0;
        }
        catch (error) {
            console.error('Error getting user total points:', error);
            return 0;
        }
    }
    broadcastEventUpdate(eventId, eventData) {
        this.io.to(`event:${eventId}`).emit('event_updated', eventData);
    }
    broadcastNewEvent(eventData) {
        this.io.emit('new_event', eventData);
    }
    broadcastEventDeleted(eventId) {
        this.io.emit('event_deleted', { eventId });
    }
}
exports.SocketService = SocketService;
//# sourceMappingURL=SocketService.js.map