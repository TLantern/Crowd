import { Server as SocketIOServer, Socket } from 'socket.io';
import { Event } from '../models/Event';
import { Signal } from '../models/Signal';
import { Points } from '../models/Points';
import { User } from '../models/User';
import { v4 as uuidv4 } from 'uuid';

export class SocketService {
  private io: SocketIOServer;
  private connectedUsers: Map<string, string> = new Map(); // socketId -> userId

  constructor(io: SocketIOServer) {
    this.io = io;
    this.setupSocketHandlers();
  }

  private setupSocketHandlers(): void {
    this.io.on('connection', (socket: Socket) => {
      console.log(`🔌 User connected: ${socket.id}`);

      // Handle user authentication
      socket.on('authenticate', async (data: { userId: string }) => {
        try {
          const { userId } = data;
          this.connectedUsers.set(socket.id, userId);
          
          // Join user-specific room
          socket.join(`user:${userId}`);
          
          // Update user's last active time
          await User.findOneAndUpdate(
            { id: userId },
            { lastActiveAt: new Date() }
          );

          socket.emit('authenticated', { success: true });
          console.log(`✅ User ${userId} authenticated`);
        } catch (error) {
          socket.emit('error', { message: 'Authentication failed' });
          console.error('Authentication error:', error);
        }
      });

      // Handle joining event
      socket.on('join_event', async (data: { eventId: string, userId: string, location?: { latitude: number, longitude: number } }) => {
        try {
          const { eventId, userId, location } = data;
          
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
          const event = await Event.findOneAndUpdate(
            { id: eventId },
            { 
              $inc: { attendeeCount: 1, signalStrength: 2 },
              $set: { updatedAt: new Date() }
            },
            { new: true }
          );

          if (event) {
            // Award points
            await this.awardPoints(userId, eventId, 'event_join', 10, 'Joined an event');

            // Join event room
            socket.join(`event:${eventId}`);
            
            // Broadcast to event room
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
        } catch (error) {
          socket.emit('error', { message: 'Failed to join event' });
          console.error('Join event error:', error);
        }
      });

      // Handle leaving event
      socket.on('leave_event', async (data: { eventId: string, userId: string }) => {
        try {
          const { eventId, userId } = data;
          
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
          const event = await Event.findOneAndUpdate(
            { id: eventId },
            { 
              $inc: { attendeeCount: -1, signalStrength: -1 },
              $set: { updatedAt: new Date() }
            },
            { new: true }
          );

          if (event) {
            // Leave event room
            socket.leave(`event:${eventId}`);
            
            // Broadcast to event room
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
        } catch (error) {
          socket.emit('error', { message: 'Failed to leave event' });
          console.error('Leave event error:', error);
        }
      });

      // Handle boosting signal
      socket.on('boost_signal', async (data: { eventId: string, userId: string, delta: number }) => {
        try {
          const { eventId, userId, delta } = data;
          
          // Create signal
          const signal = new Signal({
            id: uuidv4(),
            eventId,
            userId,
            signalType: 'boost',
            strength: delta,
            metadata: {
              timestamp: new Date()
            }
          });
          await signal.save();

          // Update event
          const event = await Event.findOneAndUpdate(
            { id: eventId },
            { 
              $inc: { signalStrength: delta },
              $set: { updatedAt: new Date() }
            },
            { new: true }
          );

          if (event) {
            // Award points based on boost strength
            const points = Math.abs(delta) * 2;
            await this.awardPoints(userId, eventId, 'event_boost', points, `Boosted signal by ${delta}`);
            
            // Broadcast to event room
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
        } catch (error) {
          socket.emit('error', { message: 'Failed to boost signal' });
          console.error('Boost signal error:', error);
        }
      });

      // Handle location updates
      socket.on('location_update', async (data: { userId: string, latitude: number, longitude: number }) => {
        try {
          const { userId, latitude, longitude } = data;
          
          // Find nearby events
          const nearbyEvents = await Event.findEventsInRegion(latitude, longitude, 1000);
          
          // Join rooms for nearby events
          nearbyEvents.forEach(event => {
            socket.join(`event:${event.id}`);
          });

          socket.emit('nearby_events', { events: nearbyEvents });
        } catch (error) {
          console.error('Location update error:', error);
        }
      });

      // Handle disconnection
      socket.on('disconnect', () => {
        const userId = this.connectedUsers.get(socket.id);
        if (userId) {
          console.log(`🔌 User disconnected: ${userId}`);
          this.connectedUsers.delete(socket.id);
        }
      });
    });
  }

  private async awardPoints(userId: string, eventId: string | undefined, pointsType: string, points: number, description: string): Promise<void> {
    try {
      const pointsRecord = new Points({
        id: uuidv4(),
        userId,
        eventId,
        pointsType: pointsType as any,
        points,
        description
      });
      await pointsRecord.save();

      // Update user's total aura points
      await User.findOneAndUpdate(
        { id: userId },
        { $inc: { auraPoints: points } }
      );

      // Notify user of points earned
      this.io.to(`user:${userId}`).emit('points_earned', {
        points,
        description,
        totalPoints: await this.getUserTotalPoints(userId)
      });
    } catch (error) {
      console.error('Error awarding points:', error);
    }
  }

  private async getUserTotalPoints(userId: string): Promise<number> {
    try {
      const result = await Points.getUserTotalPoints(userId);
      return result[0]?.totalPoints || 0;
    } catch (error) {
      console.error('Error getting user total points:', error);
      return 0;
    }
  }

  // Public methods for broadcasting from API routes
  public broadcastEventUpdate(eventId: string, eventData: any): void {
    this.io.to(`event:${eventId}`).emit('event_updated', eventData);
  }

  public broadcastNewEvent(eventData: any): void {
    this.io.emit('new_event', eventData);
  }

  public broadcastEventDeleted(eventId: string): void {
    this.io.emit('event_deleted', { eventId });
  }
}

