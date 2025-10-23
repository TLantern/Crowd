import { Document, Model } from 'mongoose';
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
export interface IEventModel extends Model<IEvent> {
    findEventsInRegion(centerLat: number, centerLon: number, maxDistanceMeters?: number): Promise<IEvent[]>;
}
export declare const Event: IEventModel;
//# sourceMappingURL=Event.d.ts.map