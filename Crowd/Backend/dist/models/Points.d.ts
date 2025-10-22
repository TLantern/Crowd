import { Document, Model } from 'mongoose';
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
export interface IPointsModel extends Model<IPoints> {
    getUserTotalPoints(userId: string): Promise<{
        totalPoints: number;
    }[]>;
    getUserPointsByType(userId: string): Promise<any[]>;
    getLeaderboard(limit?: number): Promise<any[]>;
}
export declare const Points: IPointsModel;
//# sourceMappingURL=Points.d.ts.map