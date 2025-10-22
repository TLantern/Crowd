import mongoose, { Document } from 'mongoose';
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
export declare const User: mongoose.Model<IUser, {}, {}, {}, mongoose.Document<unknown, {}, IUser, {}, {}> & IUser & Required<{
    _id: unknown;
}> & {
    __v: number;
}, any>;
//# sourceMappingURL=User.d.ts.map