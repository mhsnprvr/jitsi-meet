import React from "react";
import CustomJitsiMeet from "./CustomJitsiMeet";

// Example usage in your application
const MyApp: React.FC = () => {
    const hostUrl = "your-jitsi-domain.com";
    const outpost = { uuid: "room-uuid-123" };
    const myUser = {
        name: "John Doe",
        uuid: "user-uuid-456",
        email: "john.doe@example.com", // This will be used to extract creatorUuid
    };

    // Helper functions (you'll need to implement these)
    const truncate = (str: string, length: number) => str.substring(0, length);
    const transformIdToEmailLike = (id: string) => `${id}@example.com`;
    const transformEmailLikeToId = (email: string) => email.split("@")[0]; // Extract UUID from email

    const userInfo = {
        displayName: myUser.name?.includes("@") ? truncate(myUser.name, 8) : myUser.name ?? truncate(myUser.uuid, 8),
        email: transformIdToEmailLike(myUser.uuid) ?? "",
    };

    // Extract creatorUuid from the local user's email
    const creatorUuid = transformEmailLikeToId(myUser.email);
    const cohostsUuids = ["cohost-uuid-1", "cohost-uuid-2"]; // Array of cohost UUIDs

    const configOverwrite = {
        // Your existing config overrides
        startWithAudioMuted: true,
        startWithVideoMuted: false,
        // ... other config options
    };

    return (
        <div style={{ width: "100%", height: "100vh" }}>
            <CustomJitsiMeet
                domain={hostUrl}
                roomName={outpost.uuid}
                userInfo={userInfo}
                creatorUuid={creatorUuid}
                cohostsUuids={cohostsUuids}
                configOverwrite={configOverwrite}
                // Add any additional props you need
                onConferenceJoined={() => {
                    console.log("Conference joined!");
                    // Access custom data here if needed
                }}
                onConferenceLeft={() => {
                    console.log("Conference left!");
                }}
            />
        </div>
    );
};

export default MyApp;
