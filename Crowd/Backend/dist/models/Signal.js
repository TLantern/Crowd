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
exports.Signal = void 0;
const mongoose_1 = __importStar(require("mongoose"));
const SignalSchema = new mongoose_1.Schema({
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
        transform: function (doc, ret) {
            ret.id = ret._id;
            delete ret._id;
            delete ret.__v;
            return ret;
        }
    }
});
SignalSchema.index({ eventId: 1, createdAt: -1 });
SignalSchema.index({ userId: 1, createdAt: -1 });
SignalSchema.index({ signalType: 1, createdAt: -1 });
SignalSchema.index({ eventId: 1, userId: 1, signalType: 1 });
SignalSchema.pre('save', function (next) {
    this.updatedAt = new Date();
    next();
});
SignalSchema.statics.getRecentSignals = function (eventId, limit = 50) {
    return this.find({ eventId })
        .sort({ createdAt: -1 })
        .limit(limit)
        .populate('userId', 'displayName auraPoints');
};
SignalSchema.statics.getUserSignals = function (userId, limit = 100) {
    return this.find({ userId })
        .sort({ createdAt: -1 })
        .limit(limit)
        .populate('eventId', 'title latitude longitude');
};
exports.Signal = mongoose_1.default.model('Signal', SignalSchema);
//# sourceMappingURL=Signal.js.map