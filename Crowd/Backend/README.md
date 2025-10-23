# Crowd Backend API

A comprehensive backend API for the Crowd iOS app - a location-based event discovery platform with real-time synchronization.

## Features

- **Real-time Sync**: WebSocket support for live event updates
- **Location-based Events**: Geospatial queries for nearby events
- **Points System**: Comprehensive scoring and leaderboard system
- **Signal Tracking**: Real-time event interactions and analytics
- **User Management**: Complete user profiles and preferences
- **RESTful API**: Clean, well-documented endpoints

## Collections

- **Users**: User profiles, preferences, and aura points
- **Events**: Location-based events with signal strength
- **Signals**: Real-time event interactions (join, leave, boost)
- **Points**: User scoring system with detailed history

## Tech Stack

- **Node.js** with **TypeScript**
- **Express.js** for REST API
- **Socket.IO** for real-time communication
- **MongoDB** with **Mongoose** for data persistence
- **JWT** for authentication (demo implementation)

## Quick Start

### Prerequisites

- Node.js 18+ 
- MongoDB 5+
- npm or yarn

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy environment variables:
   ```bash
   cp env.example .env
   ```

4. Update `.env` with your configuration:
   ```env
   NODE_ENV=development
   PORT=3000
   MONGODB_URI=mongodb://localhost:27017/crowd
   JWT_SECRET=your-super-secret-jwt-key
   CORS_ORIGIN=http://localhost:3000
   ```

5. Start the development server:
   ```bash
   npm run dev
   ```

6. The API will be available at `http://localhost:3000`

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login user
- `POST /api/auth/register` - Register new user
- `GET /api/auth/me` - Get current user info
- `POST /api/auth/logout` - Logout user

### Events
- `GET /api/events` - Get events in region
- `GET /api/events/:id` - Get specific event
- `POST /api/events` - Create new event
- `PUT /api/events/:id` - Update event
- `DELETE /api/events/:id` - Delete event
- `POST /api/events/:id/join` - Join event
- `POST /api/events/:id/leave` - Leave event
- `POST /api/events/:id/boost` - Boost event signal

### Users
- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get specific user
- `POST /api/users` - Create new user
- `PUT /api/users/:id` - Update user
- `GET /api/users/:id/points` - Get user's points history
- `GET /api/users/:id/signals` - Get user's signal history
- `GET /api/users/:id/stats` - Get user statistics

### Signals
- `GET /api/signals` - Get signals with filters
- `GET /api/signals/:id` - Get specific signal
- `POST /api/signals` - Create new signal
- `GET /api/signals/event/:eventId` - Get signals for event
- `GET /api/signals/user/:userId` - Get signals for user

### Points
- `GET /api/points` - Get points with filters
- `GET /api/points/leaderboard` - Get leaderboard
- `GET /api/points/user/:userId/total` - Get user's total points
- `GET /api/points/user/:userId/by-type` - Get user's points by type
- `POST /api/points` - Award points manually
- `POST /api/points/bulk` - Award points to multiple users

## WebSocket Events

### Client to Server
- `authenticate` - Authenticate user
- `join_event` - Join an event
- `leave_event` - Leave an event
- `boost_signal` - Boost event signal
- `location_update` - Update user location

### Server to Client
- `authenticated` - Authentication successful
- `event_updated` - Event data updated
- `new_event` - New event created
- `event_deleted` - Event deleted
- `points_earned` - User earned points
- `nearby_events` - Nearby events found

## Database Schema

### User
```typescript
{
  id: string;
  displayName: string;
  auraPoints: number;
  createdAt: Date;
  updatedAt: Date;
  lastActiveAt: Date;
  deviceTokens?: string[];
  preferences?: {
    notifications: boolean;
    locationSharing: boolean;
  };
}
```

### Event
```typescript
{
  id: string;
  title: string;
  hostId: string;
  latitude: number;
  longitude: number;
  radiusMeters: number;
  startsAt?: Date;
  endsAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  signalStrength: number;
  attendeeCount: number;
  tags: string[];
  description?: string;
  maxAttendees?: number;
  isActive: boolean;
  region?: string;
}
```

### Signal
```typescript
{
  id: string;
  eventId: string;
  userId: string;
  signalType: 'join' | 'leave' | 'boost' | 'checkin' | 'checkout';
  strength: number;
  metadata?: {
    location?: { latitude: number; longitude: number };
    deviceInfo?: string;
    timestamp: Date;
  };
  createdAt: Date;
  updatedAt: Date;
}
```

### Points
```typescript
{
  id: string;
  userId: string;
  eventId?: string;
  pointsType: 'event_host' | 'event_join' | 'event_boost' | 'checkin' | 'social_share' | 'daily_active' | 'streak' | 'bonus';
  points: number;
  description: string;
  metadata?: {
    eventTitle?: string;
    signalStrength?: number;
    streakCount?: number;
    multiplier?: number;
  };
  createdAt: Date;
  updatedAt: Date;
}
```

## Development

### Scripts
- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm test` - Run tests
- `npm run lint` - Run ESLint
- `npm run lint:fix` - Fix ESLint issues

### Project Structure
```
src/
├── config/          # Database configuration
├── middleware/       # Express middleware
├── models/          # Mongoose models
├── routes/          # API routes
├── services/        # Business logic services
└── index.ts         # Application entry point
```

## Production Deployment

1. Build the application:
   ```bash
   npm run build
   ```

2. Set production environment variables
3. Start the server:
   ```bash
   npm start
   ```

## Health Check

The API provides a health check endpoint at `/health` that returns:
- Server status
- Timestamp
- Uptime
- Environment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details

