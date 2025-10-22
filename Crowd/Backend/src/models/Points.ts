import mongoose, { Schema, Document, Model } from 'mongoose';

export interface IPoints extends Document {
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

const PointsSchema = new Schema<IPoints>({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
    index: true
  },
  eventId: {
    type: String,
    index: true
  },
  pointsType: {
    type: String,
    required: true,
    enum: ['event_host', 'event_join', 'event_boost', 'checkin', 'social_share', 'daily_active', 'streak', 'bonus'],
    index: true
  },
  points: {
    type: Number,
    required: true,
    min: 0
  },
  description: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  metadata: {
    eventTitle: {
      type: String,
      trim: true
    },
    signalStrength: {
      type: Number,
      min: 0,
      max: 100
    },
    streakCount: {
      type: Number,
      min: 0
    },
    multiplier: {
      type: Number,
      min: 1,
      max: 10
    }
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true,
  toJSON: {
    transform: function(doc: any, ret: any) {
      ret.id = ret._id;
      delete ret._id;
      delete ret.__v;
      return ret;
    }
  }
});

// Create compound indexes for efficient queries
PointsSchema.index({ userId: 1, createdAt: -1 });
PointsSchema.index({ userId: 1, pointsType: 1 });
PointsSchema.index({ eventId: 1, createdAt: -1 });

// Update the updatedAt field on save
PointsSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// Static method to get user's total points
PointsSchema.statics.getUserTotalPoints = function(userId: string) {
  return this.aggregate([
    { $match: { userId } },
    { $group: { _id: null, totalPoints: { $sum: '$points' } } }
  ]);
};

// Static method to get user's points by type
PointsSchema.statics.getUserPointsByType = function(userId: string) {
  return this.aggregate([
    { $match: { userId } },
    { $group: { _id: '$pointsType', totalPoints: { $sum: '$points' }, count: { $sum: 1 } } },
    { $sort: { totalPoints: -1 } }
  ]);
};

// Static method to get leaderboard
PointsSchema.statics.getLeaderboard = function(limit: number = 50) {
  return this.aggregate([
    {
      $group: {
        _id: '$userId',
        totalPoints: { $sum: '$points' },
        lastActivity: { $max: '$createdAt' }
      }
    },
    { $sort: { totalPoints: -1, lastActivity: -1 } },
    { $limit: limit }
  ]);
};

export interface IPointsModel extends Model<IPoints> {
  getUserTotalPoints(userId: string): Promise<{ totalPoints: number }[]>;
  getUserPointsByType(userId: string): Promise<any[]>;
  getLeaderboard(limit?: number): Promise<any[]>;
}

export const Points = mongoose.model<IPoints, IPointsModel>('Points', PointsSchema);

