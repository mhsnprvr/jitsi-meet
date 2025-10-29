import { JitsiMeeting } from "@jitsi/react-sdk";
import React, { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";

import { setCohostsUuids, setCreatorUuid } from "./features/base/conference/actions-custom";
import {
    getCohostsUuids,
    getCreatorUuid,
    hasSpecialPrivileges,
    isCurrentUserCohost,
    isCurrentUserCreator,
} from "./features/base/conference/selectors-custom";

interface CustomJitsiMeetProps {
    domain: string;
    roomName: string;
    userInfo: {
        displayName: string;
        email: string;
    };
    creatorUuid?: string;
    cohostsUuids?: string[];
    configOverwrite?: any;
    onConferenceJoined?: () => void;
    onConferenceLeft?: () => void;
    // ... other props
}

const CustomJitsiMeet: React.FC<CustomJitsiMeetProps> = ({
    domain,
    roomName,
    userInfo,
    creatorUuid,
    cohostsUuids,
    configOverwrite,
    onConferenceJoined,
    onConferenceLeft,
    ...otherProps
}) => {
    const dispatch = useDispatch();

    // Selectors to access custom data
    const storedCreatorUuid = useSelector(getCreatorUuid);
    const storedCohostsUuids = useSelector(getCohostsUuids);
    const isCreator = useSelector(isCurrentUserCreator);
    const isCohost = useSelector(isCurrentUserCohost);
    const hasPrivileges = useSelector(hasSpecialPrivileges);

    // Set separate IDs when component mounts or props change
    useEffect(() => {
        if (creatorUuid) dispatch(setCreatorUuid(creatorUuid));
        if (cohostsUuids) dispatch(setCohostsUuids(cohostsUuids));
    }, [dispatch, creatorUuid, cohostsUuids]);

    // Example: Log custom data for debugging
    useEffect(() => {
        console.log("Creator UUID:", storedCreatorUuid);
        console.log("Cohosts UUIDs:", storedCohostsUuids);
        console.log("Is current user creator:", isCreator);
        console.log("Is current user cohost:", isCohost);
        console.log("Has special privileges:", hasPrivileges);
    }, [storedCreatorUuid, storedCohostsUuids, isCreator, isCohost, hasPrivileges]);

    // Log build version from server (served as /VERSION by nginx)
    useEffect(() => {
        fetch("/VERSION")
            .then((res) => res.text())
            .then((v) => console.log(`[Jitsi Web Version] ${v.trim()}`))
            .catch(() => {});
    }, []);

    return (
        <JitsiMeeting
            domain={domain}
            roomName={roomName}
            userInfo={userInfo}
            configOverwrite={configOverwrite}
            onConferenceJoined={onConferenceJoined}
            onConferenceLeft={onConferenceLeft}
            {...otherProps}
        />
    );
};

export default CustomJitsiMeet;
