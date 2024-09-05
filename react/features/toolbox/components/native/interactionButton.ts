import { connect } from "react-redux";

import { IReduxState } from "../../../app/types";
import { translate } from "../../../base/i18n/functions";
import { IconBoo, IconCheer, IconDislike, IconLike } from "../../../base/icons/svg";
import AbstractButton, { IProps as AbstractButtonProps } from "../../../base/toolbox/components/AbstractButton";
import { getParticipantById } from "../../../base/participants/functions";

/**
 * The type of the React {@code Component} props of {@link InteractionButton}.
 */
interface IProps extends AbstractButtonProps {
    /**
     * The participant ID.
     */
    participantID: string;
    interactionName: "LIKE" | "DISLIKE" | "CHEER" | "BOO";
    state: IReduxState;
}
const getCustomIcon = (interactionName: "LIKE" | "DISLIKE" | "CHEER" | "BOO") => {
    switch (interactionName) {
        case "LIKE":
            return IconLike;
        case "DISLIKE":
            return IconDislike;
        case "CHEER":
            return IconCheer;
        case "BOO":
            return IconBoo;
    }
};

/**
 * An implementation of a button for toggling the self view.
 */
class InteractionButton extends AbstractButton<IProps> {
    accessibilityLabel = this.props.interactionName.toLowerCase();
    icon = getCustomIcon(this.props.interactionName);
    label = this.props.interactionName.toLowerCase();
    participantId = this.props.participantID;

    /**
     * Handles clicking / pressing the button.
     *
     * @override
     * @protected
     * @returns {void}
     */
    _handleClick() {
        const { dispatch, state } = this.props;
        const participantData = getParticipantById(state, this.participantId);

        dispatch({
            type: this.props.interactionName,
            data: {
                participantId: this.participantId,
                email: participantData?.email,
            },
        });
    }
}

/**
 * Maps (parts of) the redux state to the associated props for the
 * {@code LikeButton} component.
 *
 * @param {Object} state - The Redux state.
 * @private
 */
function _mapStateToProps(state: IReduxState) {
    return {
        state,
    };
}

export default translate(connect(_mapStateToProps)(InteractionButton));
