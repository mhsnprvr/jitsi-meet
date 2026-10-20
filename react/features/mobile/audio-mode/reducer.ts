import ReducerRegistry from '../../base/redux/ReducerRegistry';
import { equals, set } from '../../base/redux/functions';

import { _SET_AUDIOMODE_DEVICES, _SET_AUDIOMODE_INPUTS, _SET_AUDIOMODE_SUBSCRIPTIONS } from './actionTypes';
import { IRawDevice } from './components/AudioRoutePickerDialog';

/**
 * A microphone, as returned by native.
 */
export interface IRawInput {
    name?: string;

    /**
     * Whether the user picked this microphone.
     */
    preferred: boolean;

    /**
     * Whether this microphone is the one in use.
     */
    selected: boolean;

    /**
     * One of BUILTIN, WIRED, BLUETOOTH, USB, CAR or OTHER.
     */
    type: string;
    uid: string;
}

export interface IMobileAudioModeState {
    devices: IRawDevice[];
    inputs: IRawInput[];
    subscriptions: {
        remove: Function;
    }[];
}

const DEFAULT_STATE = {
    devices: [],
    inputs: [],
    subscriptions: []
};

ReducerRegistry.register<IMobileAudioModeState>('features/mobile/audio-mode',
(state = DEFAULT_STATE, action): IMobileAudioModeState => {
    switch (action.type) {
    case _SET_AUDIOMODE_DEVICES: {
        const { devices } = action;

        if (equals(state.devices, devices)) {
            return state;
        }

        return set(state, 'devices', devices);
    }
    case _SET_AUDIOMODE_INPUTS: {
        const { inputs } = action;

        if (equals(state.inputs, inputs)) {
            return state;
        }

        return set(state, 'inputs', inputs);
    }
    case _SET_AUDIOMODE_SUBSCRIPTIONS:
        return set(state, 'subscriptions', action.subscriptions);
    }

    return state;
});
