# Custom Conference Metadata for Jitsi Meet

This implementation adds support for custom conference metadata (`creatorUuid` and `cohostsUuids`) to Jitsi Meet, allowing you to store and access additional information about conference participants in Redux state.

## Features

- **Creator UUID**: Store the UUID of the conference creator (extracted from local user's email)
- **Cohosts UUIDs**: Store an array of UUIDs for cohosts
- **Redux Integration**: All data is stored in Redux state for easy access
- **Selectors**: Convenient selectors to access and check user privileges
- **Separate Props**: Custom fields are passed as separate props, not inside userInfo

## Files Added/Modified

### New Files
- `react/features/base/conference/actions-custom.ts` - Action creators for custom data
- `react/features/base/conference/middleware-custom.ts` - Middleware for automatic data extraction
- `react/features/base/conference/selectors-custom.ts` - Selectors for accessing custom data
- `examples/CustomJitsiMeet.tsx` - Example React component
- `examples/AppExample.tsx` - Usage example

### Modified Files
- `react/features/base/conference/actionTypes.ts` - Added new action types
- `react/features/base/conference/reducer.ts` - Added custom fields to state and reducer cases

## Usage

### 1. Basic Usage with Separate Props

```tsx
import { JitsiMeeting } from '@jitsi/react-sdk';

// Helper function to extract UUID from email
const transformEmailLikeToId = (email: string) => email.split('@')[0];

const userInfo = {
    displayName: 'John Doe',
    email: 'john@example.com'
};

// Extract creatorUuid from local user's email
const creatorUuid = transformEmailLikeToId('john.doe@example.com');
const cohostsUuids = ['cohost-uuid-1', 'cohost-uuid-2'];

<JitsiMeeting
    domain="your-domain.com"
    roomName="room-name"
    userInfo={userInfo}
    creatorUuid={creatorUuid}
    cohostsUuids={cohostsUuids}
    // ... other props
/>
```

### 2. Using Custom Component with Redux Integration

```tsx
import CustomJitsiMeet from './CustomJitsiMeet';

// Helper function to extract UUID from email
const transformEmailLikeToId = (email: string) => email.split('@')[0];

const userInfo = {
    displayName: 'John Doe',
    email: 'john@example.com'
};

// Extract creatorUuid from local user's email
const creatorUuid = transformEmailLikeToId('john.doe@example.com');
const cohostsUuids = ['cohost-uuid-1', 'cohost-uuid-2'];

<CustomJitsiMeet
    domain="your-domain.com"
    roomName="room-name"
    userInfo={userInfo}
    creatorUuid={creatorUuid}
    cohostsUuids={cohostsUuids}
    configOverwrite={{
        startWithAudioMuted: true,
        startWithVideoMuted: false
    }}
/>
```

### 3. Accessing Custom Data in Components

```tsx
import { useSelector } from 'react-redux';
import { 
    getCreatorUuid, 
    getCohostsUuids, 
    isCurrentUserCreator,
    isCurrentUserCohost,
    hasSpecialPrivileges 
} from './features/base/conference/selectors-custom';

const MyComponent = () => {
    const creatorUuid = useSelector(getCreatorUuid);
    const cohostsUuids = useSelector(getCohostsUuids);
    const isCreator = useSelector(isCurrentUserCreator);
    const isCohost = useSelector(isCurrentUserCohost);
    const hasPrivileges = useSelector(hasSpecialPrivileges);

    return (
        <div>
            {isCreator && <div>You are the creator!</div>}
            {isCohost && <div>You are a cohost!</div>}
            {hasPrivileges && <div>You have special privileges!</div>}
        </div>
    );
};
```

### 4. Manual Data Setting

```tsx
import { useDispatch } from 'react-redux';
import { 
    setCreatorUuid, 
    setCohostsUuids, 
    setCustomConferenceData 
} from './features/base/conference/actions-custom';

const MyComponent = () => {
    const dispatch = useDispatch();

    const handleSetCreator = () => {
        dispatch(setCreatorUuid('new-creator-uuid'));
    };

    const handleSetCohosts = () => {
        dispatch(setCohostsUuids(['cohost-1', 'cohost-2']));
    };

    const handleSetAllData = () => {
        dispatch(setCustomConferenceData({
            creatorUuid: 'creator-uuid',
            cohostsUuids: ['cohost-1', 'cohost-2']
        }));
    };

    return (
        <div>
            <button onClick={handleSetCreator}>Set Creator</button>
            <button onClick={handleSetCohosts}>Set Cohosts</button>
            <button onClick={handleSetAllData}>Set All Data</button>
        </div>
    );
};
```

## Key Differences from Previous Version

- **Separate Props**: `creatorUuid` and `cohostsUuids` are now passed as separate props, not inside `userInfo`
- **Email Extraction**: `creatorUuid` should be extracted from the local user's email using `transformEmailLikeToId`
- **Cleaner Interface**: The `userInfo` object only contains standard Jitsi Meet fields (`displayName`, `email`)

## Redux State Structure

The custom data is stored in the conference state:

```typescript
interface IConferenceState {
    // ... existing fields
    creatorUuid?: string;
    cohostsUuids?: string[];
    customData?: {
        creatorUuid: string;
        cohostsUuids: string[];
    };
}
```

## Available Selectors

- `getCreatorUuid(state)` - Get the creator UUID
- `getCohostsUuids(state)` - Get the cohosts UUIDs array
- `getCustomConferenceData(state)` - Get all custom data
- `isCurrentUserCreator(state)` - Check if current user is creator
- `isCurrentUserCohost(state)` - Check if current user is cohost
- `hasSpecialPrivileges(state)` - Check if current user has special privileges

## Available Actions

- `setCreatorUuid(creatorUuid)` - Set creator UUID
- `setCohostsUuids(cohostsUuids)` - Set cohosts UUIDs
- `setCustomConferenceData(customData)` - Set all custom data

## Integration Steps

1. **Add the files** to your Jitsi Meet project
2. **Use the custom component** or pass custom fields as separate props
3. **Extract creatorUuid** from local user's email using `transformEmailLikeToId`
4. **Access data** using selectors in your components
5. **Set data manually** using actions when needed

## Notes

- The custom data is set when the component mounts or props change
- All data is stored in Redux state and persists during the conference session
- The `creatorUuid` should be extracted from the local user's email, not from the user's ID
- Selectors provide convenient ways to check user privileges and access data
