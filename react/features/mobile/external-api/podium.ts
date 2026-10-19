import { NativeEventEmitter, NativeModules } from 'react-native';

import { IStore } from '../../app/types';
import { APP_WILL_MOUNT, APP_WILL_UNMOUNT } from '../../base/app/actionTypes';
import { CONFERENCE_JOINED, CONFERENCE_LEFT, KICKED_OUT } from '../../base/conference/actionTypes';
import { getCurrentConference } from '../../base/conference/functions';
import { JitsiConferenceEvents } from '../../base/lib-jitsi-meet';
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

const externalAPIEnabled = isExternalAPIAvailable();

const { ExternalAPI } = NativeModules;

let eventEmitter: any;
let audioLevels: { [participantId: string]: number; } = {};
let audioLevelsTimer: ReturnType<typeof setInterval> | undefined;

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
        localScreenShare: isLocalScreenSharing(state)
    };
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
}

/**
 * Stops forwarding audio levels.
 *
 * @returns {void}
 */
function stopAudioLevels() {
    audioLevelsTimer && clearInterval(audioLevelsTimer);
    audioLevelsTimer = undefined;
    audioLevels = {};
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
        break;
    case CONFERENCE_JOINED:
        startAudioLevels(store);
        emit('state', snapshot(store));
        break;
    case CONFERENCE_LEFT:
        stopAudioLevels();
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
    /* selector */ state => isLocalScreenSharing(state),
    /* listener */ sharing => {
        emit('localScreenShare', { sharing });
    });

externalAPIEnabled && StateListenerRegistry.register(
    /* selector */ state => state['features/base/participants'].raisedHandsQueue,
    /* listener */ (_queue, store) => {
        emit('raisedHands', { raisedHands: raisedHandsOf(store.getState()) });
    });
