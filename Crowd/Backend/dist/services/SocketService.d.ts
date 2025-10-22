import { Server as SocketIOServer } from 'socket.io';
export declare class SocketService {
    private io;
    private connectedUsers;
    constructor(io: SocketIOServer);
    private setupSocketHandlers;
    private awardPoints;
    private getUserTotalPoints;
    broadcastEventUpdate(eventId: string, eventData: any): void;
    broadcastNewEvent(eventData: any): void;
    broadcastEventDeleted(eventId: string): void;
}
//# sourceMappingURL=SocketService.d.ts.map