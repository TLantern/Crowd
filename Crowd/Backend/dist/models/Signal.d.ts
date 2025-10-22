import { Document, Model } from 'mongoose';
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
export interface ISignalModel extends Model<ISignal> {
    getRecentSignals(eventId: string, limit?: number): Promise<ISignal[]>;
    getUserSignals(userId: string, limit?: number): Promise<ISignal[]>;
}
export declare const Signal: ISignalModel;
//# sourceMappingURL=Signal.d.ts.map