"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.Points = void 0;
const mongoose_1 = __importStar(require("mongoose"));
const PointsSchema = new mongoose_1.Schema({
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
        transform: function (doc, ret) {
            ret.id = ret._id;
            delete ret._id;
            delete ret.__v;
            return ret;
        }
    }
});
PointsSchema.index({ userId: 1, createdAt: -1 });
PointsSchema.index({ userId: 1, pointsType: 1 });
PointsSchema.index({ eventId: 1, createdAt: -1 });
PointsSchema.pre('save', function (next) {
    this.updatedAt = new Date();
    next();
});
PointsSchema.statics.getUserTotalPoints = function (userId) {
    return this.aggregate([
        { $match: { userId } },
        { $group: { _id: null, totalPoints: { $sum: '$points' } } }
    ]);
};
PointsSchema.statics.getUserPointsByType = function (userId) {
    return this.aggregate([
        { $match: { userId } },
        { $group: { _id: '$pointsType', totalPoints: { $sum: '$points' }, count: { $sum: 1 } } },
        { $sort: { totalPoints: -1 } }
    ]);
};
PointsSchema.statics.getLeaderboard = function (limit = 50) {
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
exports.Points = mongoose_1.default.model('Points', PointsSchema);
//# sourceMappingURL=Points.js.map