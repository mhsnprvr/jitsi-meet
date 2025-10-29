import { AnyAction } from "redux";

import { SET_COHOSTS_UUIDS, SET_CREATOR_UUID } from "./actionTypes";

/**
 * Sets the creator UUID for the current conference.
 *
 * @param {string} creatorUuid - The UUID of the conference creator.
 * @returns {{
 *     type: SET_CREATOR_UUID,
 *     creatorUuid: string
 * }}
 */
export function setCreatorUuid(creatorUuid: string): AnyAction {
    return {
        type: SET_CREATOR_UUID,
        creatorUuid,
    };
}

/**
 * Sets the cohosts UUIDs for the current conference.
 *
 * @param {string[]} cohostsUuids - Array of UUIDs of cohosts.
 * @returns {{
 *     type: SET_COHOSTS_UUIDS,
 *     cohostsUuids: string[]
 * }}
 */
export function setCohostsUuids(cohostsUuids: string[]): AnyAction {
    return {
        type: SET_COHOSTS_UUIDS,
        cohostsUuids,
    };
}

// Combined setter and userInfo extraction removed; use separate setters only.
