export interface IRoom {
    id: string;
    isMainRoom?: boolean;
    jid: string;
    name: string;
    participants: {
        [jid: string]: {
            displayName: string;
            jid: string;
            role: string;
        };
    };

    /**
     * Podium access policy id of a protected room; joining it needs a pass from the Podium server.
     */
    podiumAccess?: string;
}

export interface IRooms {
    [jid: string]: IRoom;
}

export interface IRoomInfo {
    id: string;
    isMainRoom: boolean;
    jid: string;
    participants: IRoomInfoParticipant[];
}

export interface IRoomsInfo {
    rooms: IRoomInfo[];
}

export interface IRoomInfoParticipant {
    avatarUrl: string;
    displayName: string;
    id: string;
    jid: string;
    role: string;
}
