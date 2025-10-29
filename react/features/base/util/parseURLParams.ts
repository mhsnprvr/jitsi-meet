// @ts-ignore
import { safeJsonParse } from "@jitsi/js-utils/json";

/**
 * A list if keys to ignore when parsing.
 *
 * @type {string[]}
 */
const blacklist = ["__proto__", "constructor", "prototype"];

/**
 * Parses the query/search or fragment/hash parameters out of a specific URL and
 * returns them as a JS object.
 *
 * @param {URL} url - The URL to parse.
 * @param {boolean} dontParse - If falsy, some transformations (for parsing the
 * value as JSON) will be executed.
 * @param {string} source - If {@code 'search'}, the parameters will parsed out
 * of {@code url.search}; otherwise, out of {@code url.hash}.
 * @returns {Object}
 */
export function parseURLParams(url: URL | string, dontParse = false, source = "hash") {
    if (!url) {
        return {};
    }

    if (typeof url === "string") {
        // eslint-disable-next-line no-param-reassign
        url = new URL(url);
    }
    const paramStr = source === "search" ? url.search : url.hash;
    const params: any = {};
    const paramParts = paramStr?.substr(1).split("&") || [];

    // Detect and ignore hash params for hash routers.
    if (source === "hash" && paramParts.length === 1) {
        const firstParam = paramParts[0];

        if (firstParam.startsWith("/") && firstParam.split("&").length === 1) {
            return params;
        }
    }

    paramParts.forEach((part: string) => {
        const param = part.split("=");
        const key = param[0];

        if (!key || key.split(".").some((k: string) => blacklist.includes(k))) {
            return;
        }

        let value;
        let decoded: string | undefined;

        try {
            value = param[1];

            if (!dontParse) {
                decoded = decodeURIComponent(value)
                    .replace(/\\&/, "&")
                    .replace(/[\u2018\u2019]/g, "'")
                    .replace(/[\u201C\u201D]/g, '"');

                // Attempt to parse JSON values, but gracefully fallback to the raw
                // decoded string (e.g. for UUIDs like 0199e693-...) when parsing fails.
                value = decoded === "undefined" ? undefined : safeJsonParse(decoded);
            }
        } catch (e: any) {
            // Fallback: if JSON parsing fails, use the decoded string value instead
            // of dropping the parameter or reporting an error. This avoids errors
            // for plain string params such as UUIDs.
            if (typeof decoded === "string") {
                value = decoded;
            } else {
                // If we couldn't even decode, keep the original raw value.
                value = param[1];
            }
        }
        params[key] = value;
    });

    return params;
}
