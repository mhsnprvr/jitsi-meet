import { IReduxState } from "../../app/types";

/**
 * Selector to get the creator UUID from the conference state.
 */
export const getCreatorUuid = (state: IReduxState): string | undefined => state["features/base/conference"].creatorUuid;

/**
 * Selector to get the cohosts UUIDs from the conference state.
 */
export const getCohostsUuids = (state: IReduxState): string[] | undefined =>
    state["features/base/conference"].cohostsUuids;

/**
 * Helper: get the local user's email from settings.
 */
const getLocalEmail = (state: IReduxState): string | undefined =>
    state["features/base/settings"]?.email as string | undefined;

/**
 * Helper: transform email-like string to UUID format using the local-part,
 * inserting dashes as 8-4-4-4-12.
 * Example: 054dfc78c17449dca6200f0da86d0400@gmail.com ->
 *          054dfc78-c174-49dc-a620-0f0da86d0400
 */
export const transformEmailLikeToId = (email?: string): string | undefined => {
    if (!email || typeof email !== "string") {
        return undefined;
    }
    const parts = email.split("@");
    const id = parts[0] || "";
    const len = id.length;
    const first = id.slice(0, 8);
    const second = id.slice(8, 12);
    const third = id.slice(12, 16);
    const fourth = id.slice(16, 20);
    const fifth = id.slice(20, len);
    const segments = [first, second, third, fourth, fifth].filter(Boolean);
    return segments.join("-");
};

/**
 * Selector to check if the current user is the creator.
 */
export const isCurrentUserCreator = (state: IReduxState): boolean => {
    const creatorUuid = getCreatorUuid(state);
    const localEmail = getLocalEmail(state);
    const localId = transformEmailLikeToId(localEmail);
    return Boolean(creatorUuid && localId && creatorUuid === localId);
};

/**
 * Selector to check if the current user is a cohost.
 */
export const isCurrentUserCohost = (state: IReduxState): boolean => {
    const cohostsUuids = getCohostsUuids(state);
    const localEmail = getLocalEmail(state);
    const localId = transformEmailLikeToId(localEmail);
    return Boolean(Array.isArray(cohostsUuids) && localId && cohostsUuids.includes(localId));
};

/**
 * Selector to check if the current user has special privileges (creator or cohost).
 */
export const hasSpecialPrivileges = (state: IReduxState): boolean => {
    return isCurrentUserCreator(state) || isCurrentUserCohost(state);
};
