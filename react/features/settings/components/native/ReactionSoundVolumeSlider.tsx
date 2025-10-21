import React from "react";
import { useTranslation } from "react-i18next";
import { Slider, Text, View, ViewStyle } from "react-native";
import { useDispatch, useSelector } from "react-redux";

import { IReduxState } from "../../../app/types";
import { updateSettings } from "../../../base/settings/actions";

import FormRow from "./FormRow";
import styles from "./styles";

/**
 * React component for controlling reaction sound volume on native platforms.
 */
const ReactionSoundVolumeSlider = () => {
    const { t } = useTranslation();
    const dispatch = useDispatch();
    const { soundsReactionsVolume = 0.5 } = useSelector((state: IReduxState) => state["features/base/settings"]);

    const onVolumeChange = (volume: number) => {
        dispatch(updateSettings({ soundsReactionsVolume: volume }));
    };

    return (
        <FormRow label="settings.reactionSoundVolume">
            <View style={styles.volumeContainer as ViewStyle}>
                <Text style={styles.volumeText}>{Math.round(soundsReactionsVolume * 100)}%</Text>
                <Slider
                    maximumValue={1}
                    minimumValue={0}
                    onValueChange={onVolumeChange}
                    step={0.1}
                    style={styles.volumeSlider}
                    value={soundsReactionsVolume}
                />
            </View>
        </FormRow>
    );
};

export default ReactionSoundVolumeSlider;
