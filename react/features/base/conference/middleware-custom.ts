import { AnyAction } from "redux";

import { IStore } from "../../app/types";
import { CONFERENCE_JOINED, CONFERENCE_WILL_JOIN } from "../conference/actionTypes";

/**
 * Middleware to handle custom conference data.
 * This middleware can be extended to automatically set custom data
 * when conference events occur, if needed.
 */
export function customConferenceDataMiddleware(store: IStore) {
    return (next: Function) => (action: AnyAction) => {
        const result = next(action);

        switch (action.type) {
            case CONFERENCE_WILL_JOIN:
            case CONFERENCE_JOINED:
                break;
        }

        return result;
    };
}
