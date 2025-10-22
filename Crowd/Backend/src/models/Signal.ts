import mongoose, { Schema, Document, Model } from 'mongoose';

export interface ISignal extends Document {
  id: string;
  eventId: string;
  userId: string;
  signalType: 'join' | 'leave' | 'boost' | 'checkin' | 'checkout';
  strength: number;
  metadata?: {
    location?: {
      latitude: number;
      longitude: number;
    };
    deviceInfo?: string;
    timestamp: Date;
  };
  createdAt: Date;
  updatedAt: Date;
}

const SignalSchema = new Schema<ISignal>({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  eventId: {
    type: String,
    required: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
    index: true
  },
  signalType: {
    type: String,
    required: true,
    enum: ['join', 'leave', 'boost', 'checkin', 'checkout'],
    index: true
  },
  strength: {
    type: Number,
    required: true,
    min: 0,
    max: 100
  },
  metadata: {
    location: {
      latitude: {
        type: Number,
        min: -90,
        max: 90
      },
      longitude: {
        type: Number,
        min: -180,
        max: 180
      }
    },
    deviceInfo: {
      type: String,
      trim: true
    },
    timestamp: {
      type: Date,
      default: Date.now
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
SignalSchema.index({ eventId: 1, createdAt: -1 });
SignalSchema.index({ userId: 1, createdAt: -1 });
SignalSchema.index({ signalType: 1, createdAt: -1 });
SignalSchema.index({ eventId: 1, userId: 1, signalType: 1 });

// Update the updatedAt field on save
SignalSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// Static method to get recent signals for an event
SignalSchema.statics.getRecentSignals = function(eventId: string, limit: number = 50) {
  return this.find({ eventId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .populate('userId', 'displayName auraPoints');
};

// Static method to get user's signal history
SignalSchema.statics.getUserSignals = function(userId: string, limit: number = 100) {
  return this.find({ userId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .populate('eventId', 'title latitude longitude');
};

export interface ISignalModel extends Model<ISignal> {
  getRecentSignals(eventId: string, limit?: number): Promise<ISignal[]>;
  getUserSignals(userId: string, limit?: number): Promise<ISignal[]>;
}

export const Signal = mongoose.model<ISignal, ISignalModel>('Signal', SignalSchema);

