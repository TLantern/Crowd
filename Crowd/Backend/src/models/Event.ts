import mongoose, { Schema, Document, Model } from 'mongoose';

export interface IEvent extends Document {
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

const EventSchema = new Schema<IEvent>({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100
  },
  hostId: {
    type: String,
    required: true,
    index: true
  },
  latitude: {
    type: Number,
    required: true,
    min: -90,
    max: 90
  },
  longitude: {
    type: Number,
    required: true,
    min: -180,
    max: 180
  },
  radiusMeters: {
    type: Number,
    required: true,
    min: 10,
    max: 1000,
    default: 60
  },
  startsAt: {
    type: Date,
    index: true
  },
  endsAt: {
    type: Date,
    index: true
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  signalStrength: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
  },
  attendeeCount: {
    type: Number,
    default: 0,
    min: 0
  },
  tags: [{
    type: String,
    trim: true,
    lowercase: true
  }],
  description: {
    type: String,
    trim: true,
    maxlength: 500
  },
  maxAttendees: {
    type: Number,
    min: 1
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  region: {
    type: String,
    trim: true,
    index: true
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

// Create geospatial index for location-based queries
EventSchema.index({ latitude: 1, longitude: 1 });

// Create compound indexes for efficient queries
EventSchema.index({ isActive: 1, createdAt: -1 });
EventSchema.index({ hostId: 1, createdAt: -1 });
EventSchema.index({ region: 1, isActive: 1 });

// Update the updatedAt field on save
EventSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// Static method to find events within a region
EventSchema.statics.findEventsInRegion = function(centerLat: number, centerLon: number, maxDistanceMeters: number = 600) {
  return this.find({
    isActive: true,
    latitude: {
      $gte: centerLat - (maxDistanceMeters / 111000), // Rough conversion: 1 degree ≈ 111km
      $lte: centerLat + (maxDistanceMeters / 111000)
    },
    longitude: {
      $gte: centerLon - (maxDistanceMeters / (111000 * Math.cos(centerLat * Math.PI / 180))),
      $lte: centerLon + (maxDistanceMeters / (111000 * Math.cos(centerLat * Math.PI / 180)))
    }
  }).sort({ signalStrength: -1, createdAt: -1 });
};

export interface IEventModel extends Model<IEvent> {
  findEventsInRegion(centerLat: number, centerLon: number, maxDistanceMeters?: number): Promise<IEvent[]>;
}

export const Event = mongoose.model<IEvent, IEventModel>('Event', EventSchema);

