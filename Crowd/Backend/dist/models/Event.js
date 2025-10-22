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
exports.Event = void 0;
const mongoose_1 = __importStar(require("mongoose"));
const EventSchema = new mongoose_1.Schema({
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
        transform: function (doc, ret) {
            ret.id = ret._id;
            delete ret._id;
            delete ret.__v;
            return ret;
        }
    }
});
EventSchema.index({ latitude: 1, longitude: 1 });
EventSchema.index({ isActive: 1, createdAt: -1 });
EventSchema.index({ hostId: 1, createdAt: -1 });
EventSchema.index({ region: 1, isActive: 1 });
EventSchema.pre('save', function (next) {
    this.updatedAt = new Date();
    next();
});
EventSchema.statics.findEventsInRegion = function (centerLat, centerLon, maxDistanceMeters = 600) {
    return this.find({
        isActive: true,
        latitude: {
            $gte: centerLat - (maxDistanceMeters / 111000),
            $lte: centerLat + (maxDistanceMeters / 111000)
        },
        longitude: {
            $gte: centerLon - (maxDistanceMeters / (111000 * Math.cos(centerLat * Math.PI / 180))),
            $lte: centerLon + (maxDistanceMeters / (111000 * Math.cos(centerLat * Math.PI / 180)))
        }
    }).sort({ signalStrength: -1, createdAt: -1 });
};
exports.Event = mongoose_1.default.model('Event', EventSchema);
//# sourceMappingURL=Event.js.map