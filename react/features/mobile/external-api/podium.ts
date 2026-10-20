import { NativeEventEmitter, NativeModules } from 'react-native';
import { RTCPeerConnection } from 'react-native-webrtc';

import { IStore } from '../../app/types';
import { APP_WILL_MOUNT, APP_WILL_UNMOUNT } from '../../base/app/actionTypes';
import { CONFERENCE_JOINED, CONFERENCE_LEFT, KICKED_OUT } from '../../base/conference/actionTypes';
import { getCurrentConference } from '../../base/conference/functions';
import { JitsiConferenceEvents, JitsiConnectionQualityEvents } from '../../base/lib-jitsi-meet';
import { MEDIA_TYPE, VIDEO_TYPE } from '../../base/media/constants';
import {
    DOMINANT_SPEAKER_CHANGED,
    PARTICIPANT_MUTED_US,
    PARTICIPANT_ROLE_CHANGED
} from '../../base/participants/actionTypes';
import { kickParticipant, pinParticipant, raiseHand } from '../../base/participants/actions';
import { getLocalParticipant, getRemoteParticipants } from '../../base/participants/functions';
import MiddlewareRegistry from '../../base/redux/MiddlewareRegistry';
import StateListenerRegistry from '../../base/redux/StateListenerRegistry';
import { LOWER_HAND_MESSAGE } from '../../base/tracks/constants';
import { getLocalDesktopTrack } from '../../base/tracks/functions.any';
import { UPDATE_BREAKOUT_ROOMS } from '../../breakout-rooms/actionTypes';
import {
    autoAssignToBreakoutRooms,
    closeBreakoutRoom,
    createBreakoutRoom,
    moveToRoom,
    removeBreakoutRoom,
    sendParticipantToRoom
} from '../../breakout-rooms/actions';
import { getBreakoutRooms, getCurrentRoomId, isInBreakoutRoom } from '../../breakout-rooms/functions';
import { setTileView } from '../../video-layout/actions.any';
import { muteAllParticipants, muteRemote } from '../../video-menu/actions.any';
// @ts-ignore
import { isExternalAPIAvailable } from '../react-native-sdk/functions';

import { participantToParticipantInfo } from './functions';
import logger from './logger';

/**
 * Generic Podium channel between the host app and the conference.
 *
 * Native -> JS: the PODIUM_COMMAND action carries `{ name, payload }`, where payload is a JSON string.
 * JS -> native: the PODIUM_EVENT event carries `{ name, payload }`, where payload is a JSON string.
 * Payloads are strings because the Android broadcast layer stringifies every extra.
 */
const PODIUM_EVENT = 'PODIUM_EVENT';

const AUDIO_LEVELS_FLUSH_INTERVAL = 250;

/**
 * React Native's WebRTC has no RTCRtpReceiver.getSynchronizationSources() or AudioContext, so
 * lib-jitsi-meet never fires TRACK_AUDIO_LEVEL_CHANGED on mobile. Levels are read from
 * getStats() instead.
 */
const AUDIO_LEVELS_POLL_INTERVAL = 300;

/**
 * Stats audio levels are linear and quiet for normal speech; lib-jitsi-meet applies the same
 * gain to remote levels before reporting them.
 */
const AUDIO_LEVEL_GAIN = 2.5;

const CONNECTION_QUALITY_FLUSH_INTERVAL = 3000;

const externalAPIEnabled = isExternalAPIAvailable();

const { AudioMode, ExternalAPI } = NativeModules;

let eventEmitter: any;
let audioLevels: { [participantId: string]: number; } = {};
let audioLevelsTimer: ReturnType<typeof setInterval> | undefined;
let audioLevelsPollTimer: ReturnType<typeof setInterval> | undefined;
let audioLevelsPollInFlight = false;
let localLevelProbe: { receiver: RTCPeerConnection; sender: RTCPeerConnection; track: any; } | undefined;
let qualityConference: any;
let qualityTimer: ReturnType<typeof setInterval> | undefined;
let localQuality: number | undefined;
let remoteQuality: { [participantId: string]: number; } = {};
let qualityDirty = false;
let lastBreakoutRooms: { localId?: string; roomCounter: number; rooms: any; } | undefined;
let breakoutConference: any;

/**
 * Sends a Podium event to the native side.
 *
 * @param {string} name - The event name.
 * @param {Object} data - The event payload.
 * @returns {void}
 */
function emit(name: string, data: Object = {}) {
    try {
        ExternalAPI.sendEvent(PODIUM_EVENT, {
            name,
            payload: JSON.stringify(data)
        });
    } catch (error) {
        logger.warn(`Podium: failed to emit ${name}`, error);
    }
}

/**
 * Builds a snapshot of the state the host app cares about.
 *
 * @param {IStore} store - The redux store.
 * @returns {Object}
 */
function snapshot(store: IStore) {
    const state = store.getState();
    const local = getLocalParticipant(state);
    const participants: Array<Object> = [];

    local && participants.push(participantToParticipantInfo(local));
    getRemoteParticipants(state).forEach(participant => {
        if (!participant.fakeParticipant) {
            participants.push(participantToParticipantInfo(participant));
        }
    });

    return {
        localParticipantId: local?.id,
        role: local?.role,
        participants,
        raisedHands: raisedHandsOf(state),
        screenShare: remoteScreenShareOf(state) || null,
        localScreenShare: isLocalScreenSharing(state),
        localScreenShareTrackId: localScreenShareTrackIdOf(state) || null,
        audioDevices: audioDevicesOf(state),
        breakoutRooms: breakoutRoomsOf(state)
    };
}

/**
 * Returns the audio output devices reported by the native AudioMode module.
 *
 * @param {Object} state - The redux state.
 * @returns {Array<Object>}
 */
function audioDevicesOf(state: any) {
    const devices = state['features/mobile/audio-mode']?.devices || [];

    return devices.map((device: any) => {
        return {
            uid: device.uid || null,
            type: device.type,
            name: device.name || null,
            selected: Boolean(device.selected)
        };
    });
}

/**
 * Returns the breakout rooms of the current conference in a transport friendly shape. Participant ids are
 * endpoint ids, the resource part of each occupant's room jid.
 *
 * @param {Object} state - The redux state.
 * @returns {Object}
 */
function breakoutRoomsOf(state: any) {
    const conference: any = getCurrentConference(state);
    const rooms = getBreakoutRooms(state) || {};
    const currentRoomId = getCurrentRoomId(state);

    // The room's breakout flag comes from disco info, which can arrive after the join.
    const currentRoom: any = currentRoomId ? rooms[currentRoomId] : undefined;

    return {
        supported: Boolean(conference?.getBreakoutRooms?.()?.isSupported?.()),
        currentRoomId: currentRoomId || null,
        isInBreakoutRoom: Boolean(isInBreakoutRoom(state)) || Boolean(currentRoom && !currentRoom.isMainRoom),
        rooms: Object.values(rooms).map((room: any) => {
            return {
                id: room.id,
                jid: room.jid,
                name: room.name || '',
                isMainRoom: Boolean(room.isMainRoom),
                participants: Object.keys(room.participants || {}).map(longId => {
                    const participant = room.participants[longId];
                    const parts = longId.split('/');

                    return {
                        participantId: parts.length > 1 ? parts[1] : longId,
                        displayName: participant?.displayName || ''
                    };
                })
            };
        })
    };
}

/**
 * Remembers the latest non-empty breakout room list, so it can be put back after a room switch.
 *
 * @param {IStore} store - The redux store.
 * @returns {void}
 */
function rememberBreakoutRooms(store: IStore) {
    const state = store.getState();
    const rooms = getBreakoutRooms(state) || {};

    if (Object.keys(rooms).length === 0) {
        return;
    }
    lastBreakoutRooms = {
        localId: getLocalParticipant(state)?.id,
        roomCounter: state['features/breakout-rooms']?.roomCounter ?? 0,
        rooms
    };
}

/**
 * Refills an empty breakout room list. Moving to another room resets the list, and the component
 * sends the new list only once, right after the join, which can be missed; alone in a room, no
 * further update ever comes, so the way back to the main room would be lost.
 *
 * @param {IStore} store - The redux store.
 * @returns {void}
 */
function restoreBreakoutRooms(store: IStore) {
    const state = store.getState();

    if (Object.keys(getBreakoutRooms(state) || {}).length > 0) {
        return;
    }
    const conference: any = getCurrentConference(state);
    const received = conference?.getBreakoutRooms?.()?._rooms;

    if (received && Object.keys(received).length > 0) {
        logger.info('Podium: restoring breakout rooms from the last update');
        store.dispatch({
            type: UPDATE_BREAKOUT_ROOMS,
            rooms: received,
            roomCounter: lastBreakoutRooms?.roomCounter ?? 0
        });

        return;
    }

    const previous = lastBreakoutRooms;
    const roomId = getCurrentRoomId(state);

    // Only from inside one of those breakout rooms. Back in the main room the server sends the
    // list itself; when it doesn't, the main room was recreated and the old rooms are gone.
    if (!previous || !roomId || !previous.rooms[roomId] || previous.rooms[roomId].isMainRoom) {
        return;
    }
    logger.info('Podium: restoring the breakout rooms known before the switch');

    // The local participant rejoins with a new endpoint id, so its old entry is stale.
    const rooms: any = {};

    Object.entries(previous.rooms).forEach(([ key, room ]: [ string, any ]) => {
        const participants: any = {};

        Object.entries(room.participants || {}).forEach(([ longId, participant ]) => {
            if (longId.split('/')[1] !== previous.localId) {
                participants[longId] = participant;
            }
        });
        rooms[key] = {
            ...room,
            participants
        };
    });
    store.dispatch({
        type: UPDATE_BREAKOUT_ROOMS,
        rooms,
        roomCounter: previous.roomCounter
    });
}

let onBreakoutRoomsUpdated: ((payload: any) => void) | undefined;

/**
 * Applies breakout room updates of the current conference. The breakout-rooms feature attaches
 * its own listener only when a conference appears in the state, which a room switch can skip.
 *
 * @param {IStore} store - The redux store.
 * @returns {void}
 */
function startBreakoutRooms(store: IStore) {
    stopBreakoutRooms();
    const conference: any = getCurrentConference(store.getState());

    if (!conference) {
        return;
    }
    breakoutConference = conference;
    onBreakoutRoomsUpdated = ({ rooms, roomCounter }: any) => {
        logger.info(`Podium: breakout rooms update with ${Object.keys(rooms || {}).length} rooms`);
        if (!rooms || getBreakoutRooms(store.getState()) === rooms) {
            return;
        }
        store.dispatch({
            type: UPDATE_BREAKOUT_ROOMS,
            rooms,
            roomCounter
        });
    };
    conference.on(JitsiConferenceEvents.BREAKOUT_ROOMS_UPDATED, onBreakoutRoomsUpdated);
}

/**
 * Stops applying breakout room updates.
 *
 * @returns {void}
 */
function stopBreakoutRooms() {
    if (breakoutConference && onBreakoutRoomsUpdated) {
        breakoutConference.off(JitsiConferenceEvents.BREAKOUT_ROOMS_UPDATED, onBreakoutRoomsUpdated);
    }
    breakoutConference = undefined;
    onBreakoutRoomsUpdated = undefined;
}

/**
 * Returns the most recent active remote screen share, with the ids the native side needs to find its
 * WebRTC track ({@code WebRTCModule.getTrack(pcId, trackId)}).
 *
 * @param {Object} state - The redux state.
 * @returns {Object|undefined}
 */
function remoteScreenShareOf(state: any) {
    const tracks = state['features/base/tracks'] || [];
    const track = tracks.filter((t: any) =>
        !t.local
        && t.jitsiTrack
        && !t.muted
        && (t.mediaType === MEDIA_TYPE.SCREENSHARE || t.videoType === VIDEO_TYPE.DESKTOP)).pop();

    if (!track) {
        return undefined;
    }
    const rtcTrack = track.jitsiTrack.getTrack?.();

    if (!rtcTrack || rtcTrack._peerConnectionId === undefined) {
        return undefined;
    }

    return {
        participantId: track.participantId,
        sourceName: track.jitsiTrack.getSourceName?.(),
        pcId: rtcTrack._peerConnectionId,
        trackId: rtcTrack.id
    };
}

/**
 * Whether the local participant is currently sharing their screen.
 *
 * @param {Object} state - The redux state.
 * @returns {boolean}
 */
function isLocalScreenSharing(state: any) {
    const track: any = getLocalDesktopTrack(state['features/base/tracks'] || []);

    return Boolean(track && !track.muted);
}

/**
 * Returns the WebRTC id of the local screen share track while sharing, which the native side finds
 * with {@code pcId} -1.
 *
 * @param {Object} state - The redux state.
 * @returns {string|undefined}
 */
function localScreenShareTrackIdOf(state: any) {
    const track: any = getLocalDesktopTrack(state['features/base/tracks'] || []);

    if (!track || track.muted) {
        return undefined;
    }

    return track.jitsiTrack?.getTrack?.()?.id;
}

/**
 * Returns the raised hands queue in a transport friendly shape.
 *
 * @param {Object} state - The redux state.
 * @returns {Array<Object>}
 */
function raisedHandsOf(state: any) {
    const queue = state['features/base/participants'].raisedHandsQueue || [];

    return queue.map((item: any) => {
        return {
            participantId: item.id,
            raisedHandTimestamp: item.raisedHandTimestamp
        };
    });
}

/**
 * Handles a command coming from the native side.
 *
 * @param {IStore} store - The redux store.
 * @param {string} name - The command name.
 * @param {Object} data - The command payload.
 * @returns {void}
 */
function handleCommand(store: IStore, name: string, data: any) {
    const { dispatch, getState } = store;
    const conference: any = getCurrentConference(getState());

    switch (name) {
    case 'raiseHand':
        dispatch(raiseHand(Boolean(data.raised)));
        break;
    case 'lowerHand':
        conference?.sendEndpointMessage(data.participantId || '', { name: LOWER_HAND_MESSAGE });
        break;
    case 'lowerAllHands':
        conference?.sendEndpointMessage('', { name: LOWER_HAND_MESSAGE });
        break;
    case 'muteParticipant':
        data.participantId && dispatch(muteRemote(data.participantId, MEDIA_TYPE.AUDIO));
        break;
    case 'muteEveryone': {
        const local = getLocalParticipant(getState());

        dispatch(muteAllParticipants(local ? [ local.id ] : [], MEDIA_TYPE.AUDIO));
        break;
    }
    case 'kickParticipant':
        data.participantId && dispatch(kickParticipant(data.participantId));
        break;
    case 'requestState':
        emit('state', snapshot(store));
        break;
    case 'setAudioDevice':
        (data.uid || data.type) && AudioMode?.setAudioDevice?.(data.uid || data.type);
        break;
    case 'createBreakoutRoom':
        dispatch(createBreakoutRoom(data.name || undefined));
        break;
    case 'removeBreakoutRoom':
        data.jid && dispatch(removeBreakoutRoom(data.jid));
        break;
    case 'closeBreakoutRoom':
        data.roomId && dispatch(closeBreakoutRoom(data.roomId));
        break;
    case 'sendParticipantToRoom':
        data.participantId && data.roomId && dispatch(sendParticipantToRoom(data.participantId, data.roomId));
        break;
    case 'moveToRoom':
        restoreBreakoutRooms(store);
        dispatch(moveToRoom(data.roomId || undefined));
        break;
    case 'autoAssignBreakoutRooms':
        dispatch(autoAssignToBreakoutRooms());
        break;
    default:
        logger.warn(`Podium: unknown command ${name}`);
    }
}

/**
 * Starts forwarding audio levels of the current conference, batched.
 *
 * @param {IStore} store - The redux store.
 * @returns {void}
 */
function startAudioLevels(store: IStore) {
    const conference: any = getCurrentConference(store.getState());

    stopAudioLevels();
    conference?.on(
        JitsiConferenceEvents.TRACK_AUDIO_LEVEL_CHANGED,
        (participantId: string, level: number) => {
            audioLevels[participantId] = Math.round(level * 100) / 100;
        });
    audioLevelsTimer = setInterval(() => {
        if (Object.keys(audioLevels).length === 0) {
            return;
        }
        emit('audioLevels', { levels: audioLevels });
        audioLevels = {};
    }, AUDIO_LEVELS_FLUSH_INTERVAL);
    audioLevelsPollTimer = setInterval(() => {
        pollAudioLevels(conference);
    }, AUDIO_LEVELS_POLL_INTERVAL);
}

/**
 * Records a level for a participant, keeping the loudest value until the next flush.
 *
 * @param {string} participantId - The participant id.
 * @param {number} rawLevel - Linear audio level from WebRTC stats, 0..1.
 * @returns {void}
 */
function recordAudioLevel(participantId: string, rawLevel: number) {
    const level = Math.round(Math.min(1, rawLevel * AUDIO_LEVEL_GAIN) * 100) / 100;

    if (level <= 0) {
        return;
    }
    audioLevels[participantId] = Math.max(audioLevels[participantId] ?? 0, level);
}

/**
 * Reads remote (inbound-rtp) and local (media-source) audio levels from the active peer
 * connection's stats.
 *
 * @param {Object} conference - The current JitsiConference.
 * @returns {Promise<void>}
 */
async function pollAudioLevels(conference: any) {
    if (!conference || audioLevelsPollInFlight) {
        return;
    }
    audioLevelsPollInFlight = true;
    try {
        const localId = conference.myUserId();
        const localTrack = conference.getLocalAudioTrack();
        const localMuted = !localTrack || localTrack.isMuted();
        const tpc = conference.getActivePeerConnection?.();

        if (!tpc) {
            if (localMuted || !localId) {
                closeLocalLevelProbe();

                return;
            }
            const level = await probeLocalLevel(localTrack.getTrack());

            level !== undefined && recordAudioLevel(localId, level);

            return;
        }
        closeLocalLevelProbe();

        const owners = new Map<number, string>();

        for (const track of tpc.getRemoteTracks(undefined, MEDIA_TYPE.AUDIO)) {
            owners.set(track.getSsrc(), track.getParticipantId());
        }
        const report = await tpc.getStats();

        report.forEach((stat: any) => {
            if (stat.kind !== 'audio' || typeof stat.audioLevel !== 'number') {
                return;
            }
            if (stat.type === 'inbound-rtp') {
                const owner = owners.get(stat.ssrc);

                owner && recordAudioLevel(owner, stat.audioLevel);
            } else if (stat.type === 'media-source' && !localMuted && localId) {
                recordAudioLevel(localId, stat.audioLevel);
            }
        });
    } catch (error) {
        logger.debug('Podium: audio level stats failed', error);
    } finally {
        audioLevelsPollInFlight = false;
    }
}

/**
 * Measures the local mic level while the conference has no peer connection (the local
 * participant is alone), by sending the mic track over an in-process loopback connection.
 *
 * @param {MediaStreamTrack} track - The local audio track.
 * @returns {Promise<number|undefined>} The raw level, or undefined while still connecting.
 */
async function probeLocalLevel(track: any) {
    if (!track) {
        return undefined;
    }
    if (localLevelProbe?.track !== track) {
        closeLocalLevelProbe();
        localLevelProbe = openLocalLevelProbe(track);
    }
    const report = await localLevelProbe!.sender.getStats();
    let level: number | undefined;

    report.forEach((stat: any) => {
        if (stat.type === 'media-source' && stat.kind === 'audio' && typeof stat.audioLevel === 'number') {
            level = stat.audioLevel;
        }
    });

    return level;
}

/**
 * Opens a loopback pair of peer connections carrying the given track.
 *
 * @param {MediaStreamTrack} track - The local audio track.
 * @returns {Object} The probe.
 */
function openLocalLevelProbe(track: any) {
    const sender = new RTCPeerConnection({ iceServers: [] });
    const receiver = new RTCPeerConnection({ iceServers: [] });
    const probe = { track, sender, receiver };

    sender.addEventListener('icecandidate', ({ candidate }: any) => {
        candidate && receiver.addIceCandidate(candidate).catch(() => undefined);
    });
    receiver.addEventListener('icecandidate', ({ candidate }: any) => {
        candidate && sender.addIceCandidate(candidate).catch(() => undefined);
    });
    sender.addTrack(track);

    (async () => {
        const offer = await sender.createOffer({});

        await sender.setLocalDescription(offer);
        await receiver.setRemoteDescription(offer);

        // Native WebRTC plays every remote audio track; a disabled one is played at volume 0.
        for (const { track: echo } of receiver.getReceivers()) {
            echo && (echo.enabled = false);
        }

        const answer = await receiver.createAnswer();

        await receiver.setLocalDescription(answer);
        await sender.setRemoteDescription(answer);
    })().catch(error => {
        logger.debug('Podium: local level probe failed', error);
        localLevelProbe === probe && closeLocalLevelProbe();
    });

    return probe;
}

/**
 * Closes the local level probe, if any.
 *
 * @returns {void}
 */
function closeLocalLevelProbe() {
    if (!localLevelProbe) {
        return;
    }
    const { sender, receiver } = localLevelProbe;

    localLevelProbe = undefined;
    sender.close();
    receiver.close();
}

/**
 * Stops forwarding audio levels.
 *
 * @returns {void}
 */
function stopAudioLevels() {
    closeLocalLevelProbe();
    audioLevelsTimer && clearInterval(audioLevelsTimer);
    audioLevelsTimer = undefined;
    audioLevelsPollTimer && clearInterval(audioLevelsPollTimer);
    audioLevelsPollTimer = undefined;
    audioLevels = {};
}

/**
 * Emits the connection state of the conference.
 *
 * @returns {void}
 */
function onConnectionInterrupted() {
    emit('connection', { state: 'interrupted' });
}

/**
 * Emits the connection state of the conference.
 *
 * @returns {void}
 */
function onConnectionRestored() {
    emit('connection', { state: 'restored' });
}

/**
 * Records the local connection quality, 0..100.
 *
 * @param {Object} stats - The local stats.
 * @returns {void}
 */
function onLocalStats(stats: any) {
    if (typeof stats?.connectionQuality === 'number') {
        localQuality = Math.round(stats.connectionQuality);
        qualityDirty = true;
    }
}

/**
 * Records the connection quality of a remote participant, 0..100.
 *
 * @param {string} participantId - The participant id.
 * @param {Object} stats - The remote stats.
 * @returns {void}
 */
function onRemoteStats(participantId: string, stats: any) {
    if (participantId && typeof stats?.connectionQuality === 'number') {
        remoteQuality[participantId] = Math.round(stats.connectionQuality);
        qualityDirty = true;
    }
}

/**
 * Starts forwarding the connection state and connection quality of the current conference.
 *
 * @param {IStore} store - The redux store.
 * @returns {void}
 */
function startConnectionQuality(store: IStore) {
    stopConnectionQuality();
    const conference: any = getCurrentConference(store.getState());

    if (!conference) {
        return;
    }
    qualityConference = conference;
    conference.on(JitsiConferenceEvents.CONNECTION_INTERRUPTED, onConnectionInterrupted);
    conference.on(JitsiConferenceEvents.CONNECTION_RESTORED, onConnectionRestored);
    conference.on(JitsiConnectionQualityEvents.LOCAL_STATS_UPDATED, onLocalStats);
    conference.on(JitsiConnectionQualityEvents.REMOTE_STATS_UPDATED, onRemoteStats);
    qualityTimer = setInterval(() => {
        if (!qualityDirty) {
            return;
        }
        qualityDirty = false;
        emit('connectionQuality', {
            local: localQuality ?? null,
            remote: remoteQuality
        });
    }, CONNECTION_QUALITY_FLUSH_INTERVAL);
}

/**
 * Stops forwarding the connection state and quality.
 *
 * @returns {void}
 */
function stopConnectionQuality() {
    if (qualityConference) {
        qualityConference.off(JitsiConferenceEvents.CONNECTION_INTERRUPTED, onConnectionInterrupted);
        qualityConference.off(JitsiConferenceEvents.CONNECTION_RESTORED, onConnectionRestored);
        qualityConference.off(JitsiConnectionQualityEvents.LOCAL_STATS_UPDATED, onLocalStats);
        qualityConference.off(JitsiConnectionQualityEvents.REMOTE_STATS_UPDATED, onRemoteStats);
        qualityConference = undefined;
    }
    qualityTimer && clearInterval(qualityTimer);
    qualityTimer = undefined;
    localQuality = undefined;
    remoteQuality = {};
    qualityDirty = false;
}

externalAPIEnabled && MiddlewareRegistry.register(store => next => action => {
    const result = next(action);

    switch (action.type) {
    case APP_WILL_MOUNT:
        eventEmitter = eventEmitter || new NativeEventEmitter(ExternalAPI);
        eventEmitter.removeAllListeners(ExternalAPI.PODIUM_COMMAND);
        eventEmitter.addListener(ExternalAPI.PODIUM_COMMAND, ({ name, payload }: any) => {
            let data = {};

            try {
                data = payload ? JSON.parse(payload) : {};
            } catch (error) {
                logger.warn(`Podium: invalid payload for ${name}`, error);
            }
            handleCommand(store, name, data);
        });
        break;
    case APP_WILL_UNMOUNT:
        eventEmitter?.removeAllListeners(ExternalAPI.PODIUM_COMMAND);
        stopAudioLevels();
        stopConnectionQuality();
        stopBreakoutRooms();
        lastBreakoutRooms = undefined;
        break;
    case CONFERENCE_JOINED:
        startAudioLevels(store);
        startConnectionQuality(store);
        startBreakoutRooms(store);
        restoreBreakoutRooms(store);
        emit('state', snapshot(store));
        break;
    case CONFERENCE_LEFT:
        stopAudioLevels();
        stopConnectionQuality();
        action.conference === breakoutConference && stopBreakoutRooms();
        break;
    case DOMINANT_SPEAKER_CHANGED:
        emit('dominantSpeaker', {
            participantId: action.participant?.id,
            silence: Boolean(action.participant?.silence)
        });
        break;
    case PARTICIPANT_ROLE_CHANGED: {
        const local = getLocalParticipant(store.getState());

        emit('roleChanged', {
            participantId: action.participant?.id,
            role: action.participant?.role,
            isLocal: action.participant?.id === local?.id
        });
        break;
    }
    case PARTICIPANT_MUTED_US:
        emit('mutedByModerator', {
            actorId: action.participant?.getId?.(),
            mediaType: action.track?.getType?.()
        });
        break;
    case KICKED_OUT:
        emit('kicked', { actorId: action.participant?.getId?.() });
        break;
    }

    return result;
});

externalAPIEnabled && StateListenerRegistry.register(
    /* selector */ state => {
        const share = remoteScreenShareOf(state);

        return share ? `${share.pcId}:${share.trackId}` : '';
    },
    /* listener */ (key, store) => {
        const share = key ? remoteScreenShareOf(store.getState()) : undefined;

        if (share) {
            // The bridge only forwards video the UI asks for, so put the share on stage.
            store.dispatch(setTileView(false));
            store.dispatch(pinParticipant(share.sourceName || share.participantId));
        } else {
            store.dispatch(pinParticipant(null));
        }
        emit('screenShare', { screenShare: share || null });
    });

externalAPIEnabled && StateListenerRegistry.register(
    /* selector */ state => `${isLocalScreenSharing(state)}:${localScreenShareTrackIdOf(state) || ''}`,
    /* listener */ (_key, store) => {
        const state = store.getState();

        emit('localScreenShare', {
            sharing: isLocalScreenSharing(state),
            trackId: localScreenShareTrackIdOf(state) || null
        });
    });

externalAPIEnabled && StateListenerRegistry.register(
    /* selector */ state => state['features/mobile/audio-mode']?.devices,
    /* listener */ (_devices, store) => {
        emit('audioDevices', { devices: audioDevicesOf(store.getState()) });
    });

externalAPIEnabled && StateListenerRegistry.register(
    /* selector */ state => state['features/breakout-rooms']?.rooms,
    /* listener */ (_rooms, store) => {
        rememberBreakoutRooms(store);
        emit('breakoutRooms', breakoutRoomsOf(store.getState()));
    });

externalAPIEnabled && StateListenerRegistry.register(
    /* selector */ state => state['features/base/participants'].raisedHandsQueue,
    /* listener */ (_queue, store) => {
        emit('raisedHands', { raisedHands: raisedHandsOf(store.getState()) });
    });
