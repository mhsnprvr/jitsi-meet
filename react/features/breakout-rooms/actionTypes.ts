/**
 * The type of (redux) action to reset the breakout rooms data.
 */
export const _RESET_BREAKOUT_ROOMS = '_RESET_BREAKOUT_ROOMS';

/**
 * The type of (redux) action to update the room counter locally.
 */
export const _UPDATE_ROOM_COUNTER = '_UPDATE_ROOM_COUNTER';

/**
  * The type of (redux) action to update the breakout room data.
  *
  */
export const UPDATE_BREAKOUT_ROOMS = 'UPDATE_BREAKOUT_ROOMS';

/**
 * The type of (redux) action asking the host app for a pass to a Podium protected breakout room,
 * dispatched instead of moving there without one.
 *
 * {
 *     type: PODIUM_PROTECTED_MOVE_REQUESTED,
 *     roomId: string
 * }
 */
export const PODIUM_PROTECTED_MOVE_REQUESTED = 'PODIUM_PROTECTED_MOVE_REQUESTED';
