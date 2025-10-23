import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
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

const UserSchema = new Schema<IUser>({
  id: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  displayName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50
  },
  auraPoints: {
    type: Number,
    default: 0,
    min: 0
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  lastActiveAt: {
    type: Date,
    default: Date.now
  },
  deviceTokens: [{
    type: String,
    trim: true
  }],
  preferences: {
    notifications: {
      type: Boolean,
      default: true
    },
    locationSharing: {
      type: Boolean,
      default: true
    }
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

// Update the updatedAt field on save
UserSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

export const User = mongoose.model<IUser>('User', UserSchema);

