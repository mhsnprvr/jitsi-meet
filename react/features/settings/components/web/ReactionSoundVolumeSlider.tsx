import React, { Component } from "react";
import { connect } from "react-redux";

import { IReduxState } from "../../../app/types";
import { updateSettings } from "../../../base/settings/actions";

interface IProps {
    _soundsReactionsVolume: number;
    _onVolumeChange: (volume: number) => void;
}

/**
 * React component for controlling reaction sound volume.
 */
class ReactionSoundVolumeSlider extends Component<IProps> {
    /**
     * Handles volume change.
     *
     * @param {Event} event - The change event.
     * @returns {void}
     */
    _onVolumeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const volume = parseFloat(event.target.value);
        this.props._onVolumeChange(volume);
    };

    /**
     * Implements React's {@link Component#render()}.
     *
     * @inheritdoc
     * @returns {ReactElement}
     */
    override render() {
        const { _soundsReactionsVolume } = this.props;

        return (
            <div className="reaction-sound-volume-slider">
                <label htmlFor="reaction-sound-volume">
                    Reaction Sound Volume: {Math.round(_soundsReactionsVolume * 100)}%
                </label>
                <input
                    id="reaction-sound-volume"
                    max={1}
                    min={0}
                    onChange={this._onVolumeChange}
                    step={0.1}
                    type="range"
                    value={_soundsReactionsVolume}
                />
            </div>
        );
    }
}

/**
 * Maps (parts of) the Redux state to the associated {@code ReactionSoundVolumeSlider}'s props.
 *
 * @param {Object} state - The Redux state.
 * @private
 * @returns {IProps}
 */
function _mapStateToProps(state: IReduxState) {
    const { soundsReactionsVolume = 0.5 } = state["features/base/settings"];

    return {
        _soundsReactionsVolume: soundsReactionsVolume,
    };
}

/**
 * Maps dispatching of some actions to {@code ReactionSoundVolumeSlider}'s props.
 *
 * @param {Function} dispatch - The Redux dispatch function.
 * @private
 * @returns {IProps}
 */
function _mapDispatchToProps(dispatch: Function) {
    return {
        _onVolumeChange: (volume: number) => {
            dispatch(
                updateSettings({
                    soundsReactionsVolume: volume,
                })
            );
        },
    };
}

export default connect(_mapStateToProps, _mapDispatchToProps)(ReactionSoundVolumeSlider);
