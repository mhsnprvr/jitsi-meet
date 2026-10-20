/*
 * Copyright @ 2017-present 8x8, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <AVFoundation/AVFoundation.h>

#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>
#import <WebRTC/WebRTC.h>

#import "JitsiAudioSession+Private.h"
#import "callkit/JMCallKitProxy.h"


// Audio mode
typedef enum {
    kAudioModeDefault,
    kAudioModeAudioCall,
    kAudioModeVideoCall
} JitsiMeetAudioMode;

// Events
static NSString * const kDevicesChanged = @"org.jitsi.meet:features/audio-mode#devices-update";
static NSString * const kInputsChanged = @"org.jitsi.meet:features/audio-mode#inputs-update";

// Passed to setAudioInput to clear the preferred input and let the system pick.
static NSString * const kInputAuto = @"AUTO";

// Device types (must match JS and Java)
static NSString * const kDeviceTypeBluetooth  = @"BLUETOOTH";
static NSString * const kDeviceTypeCar        = @"CAR";
static NSString * const kDeviceTypeEarpiece   = @"EARPIECE";
static NSString * const kDeviceTypeHeadphones = @"HEADPHONES";
static NSString * const kDeviceTypeSpeaker    = @"SPEAKER";
static NSString * const kDeviceTypeUnknown    = @"UNKNOWN";


@interface AudioMode : RCTEventEmitter<RTCAudioSessionDelegate>

@property(nonatomic, strong) dispatch_queue_t workerQueue;

@end

@implementation AudioMode {
    JitsiMeetAudioMode activeMode;
    RTCAudioSessionConfiguration *defaultConfig;
    RTCAudioSessionConfiguration *audioCallConfig;
    RTCAudioSessionConfiguration *videoCallConfig;
    RTCAudioSessionConfiguration *earpieceConfig;
    BOOL audioDisabled;
    BOOL forceSpeaker;
    BOOL forceEarpiece;
    BOOL isSpeakerOn;
    BOOL isEarpieceOn;
}

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[ kDevicesChanged, kInputsChanged ];
}

- (NSDictionary *)constantsToExport {
    return @{
        @"DEVICE_CHANGE_EVENT": kDevicesChanged,
        @"INPUT_CHANGE_EVENT": kInputsChanged,
        @"AUDIO_CALL" : [NSNumber numberWithInt: kAudioModeAudioCall],
        @"DEFAULT"    : [NSNumber numberWithInt: kAudioModeDefault],
        @"VIDEO_CALL" : [NSNumber numberWithInt: kAudioModeVideoCall]
    };
};

- (instancetype)init {
    self = [super init];
    if (self) {
        dispatch_queue_attr_t attributes =
        dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, -1);
        _workerQueue = dispatch_queue_create("AudioMode.queue", attributes);

        activeMode = kAudioModeDefault;

        defaultConfig = [[RTCAudioSessionConfiguration alloc] init];
        defaultConfig.category = AVAudioSessionCategoryAmbient;
        defaultConfig.categoryOptions = 0;
        defaultConfig.mode = AVAudioSessionModeDefault;

        audioCallConfig = [[RTCAudioSessionConfiguration alloc] init];
        audioCallConfig.category = AVAudioSessionCategoryPlayAndRecord;
        audioCallConfig.categoryOptions = AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionDefaultToSpeaker;
        audioCallConfig.mode = AVAudioSessionModeVoiceChat;

        videoCallConfig = [[RTCAudioSessionConfiguration alloc] init];
        videoCallConfig.category = AVAudioSessionCategoryPlayAndRecord;
        videoCallConfig.categoryOptions = AVAudioSessionCategoryOptionAllowBluetooth;
        videoCallConfig.mode = AVAudioSessionModeVideoChat;

        // Manually routing audio to the earpiece doesn't quite work unless one disables BT (weird, I know).
        earpieceConfig = [[RTCAudioSessionConfiguration alloc] init];
        earpieceConfig.category = AVAudioSessionCategoryPlayAndRecord;
        earpieceConfig.categoryOptions = 0;
        earpieceConfig.mode = AVAudioSessionModeVoiceChat;

        forceSpeaker = NO;
        forceEarpiece = NO;
        isSpeakerOn = NO;
        isEarpieceOn = NO;

        RTCAudioSession *session = JitsiAudioSession.rtcAudioSession;
        [session addDelegate:self];
    }

    return self;
}

- (dispatch_queue_t)methodQueue {
    // Use a dedicated queue for audio mode operations.
    return _workerQueue;
}

- (BOOL)setConfigWithoutLock:(RTCAudioSessionConfiguration *)config
                       error:(NSError * _Nullable *)outError {
    RTCAudioSession *session = JitsiAudioSession.rtcAudioSession;

    return [session setConfiguration:config error:outError];
}

- (BOOL)setConfig:(RTCAudioSessionConfiguration *)config
            error:(NSError * _Nullable *)outError {

    RTCAudioSession *session = JitsiAudioSession.rtcAudioSession;
    [session lockForConfiguration];
    BOOL success = [self setConfigWithoutLock:config error:outError];
    [session unlockForConfiguration];

    return success;
}

#pragma mark - Exported methods

RCT_EXPORT_METHOD(setDisabled:(BOOL)disabled
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject) {
    if (audioDisabled == disabled) {
        resolve(nil);
        return;
    }

    RCTLogInfo(@"[AudioMode] audio disabled: %d", disabled);

    audioDisabled = disabled;
    JMCallKitProxy.enabled = !disabled;

    RTCAudioSession *session = JitsiAudioSession.rtcAudioSession;
    if (disabled) {
        [session removeDelegate:self];
    } else {
        [session addDelegate:self];
    }
    session.useManualAudio = disabled;
}

RCT_EXPORT_METHOD(setMode:(int)mode
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject) {
    if (audioDisabled) {
        resolve(nil);
        return;
    }

    RTCAudioSessionConfiguration *config = [self configForMode:mode];
    NSError *error;

    if (config == nil) {
        reject(@"setMode", @"Invalid mode", nil);
        return;
    }

    // Reset.
    if (mode == kAudioModeDefault) {
        forceSpeaker = NO;
        forceEarpiece = NO;
    }

    activeMode = mode;

    if ([self setConfig:config error:&error]) {
        resolve(nil);
    } else {
        reject(@"setMode", error.localizedDescription, error);
    }
    
    [self notifyDevicesChanged];
}

RCT_EXPORT_METHOD(setAudioDevice:(NSString *)device
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    if (audioDisabled) {
        resolve(nil);
        return;
    }

    RCTLogInfo(@"[AudioMode] Selected device: %@", device);
    
    RTCAudioSession *session = JitsiAudioSession.rtcAudioSession;
    [session lockForConfiguration];
    BOOL success;
    NSError *error = nil;
    
    // Reset these, as we are about to compute them.
    forceSpeaker = NO;
    forceEarpiece = NO;
    
    // The speaker is special, so test for it first.
    if ([device isEqualToString:kDeviceTypeSpeaker]) {
        forceSpeaker = YES;
        success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    } else {
        // Here we use AVAudioSession because RTCAudioSession doesn't expose availableInputs.
        AVAudioSession *_session = [AVAudioSession sharedInstance];
        AVAudioSessionPortDescription *port = nil;

        // Find the matching input device.
        for (AVAudioSessionPortDescription *portDesc in _session.availableInputs) {
            if ([portDesc.UID isEqualToString:device]) {
                port = portDesc;
                break;
            }
        }

        if (port != nil) {
            // First remove the override if we are going to select a different device.
            if (isSpeakerOn) {
                [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
            }
            
            // Special case for the earpiece.
            if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic]) {
                forceEarpiece = YES;
                [self setConfigWithoutLock:earpieceConfig error:nil];
            } else if (isEarpieceOn) {
                // Reset the config.
                RTCAudioSessionConfiguration *config = [self configForMode:activeMode];
                [self setConfigWithoutLock:config error:nil];
            }

            // Select our preferred input.
            success = [session setPreferredInput:port error:&error];
        } else {
            success = NO;
            error = RCTErrorWithMessage(@"Could not find audio device");
        }
    }
    
    [session unlockForConfiguration];
    
    if (success) {
        resolve(nil);
    } else {
        reject(@"setAudioDevice", error != nil ? error.localizedDescription : @"", error);
    }
}

RCT_EXPORT_METHOD(setAudioInput:(NSString *)uid
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    if (audioDisabled) {
        resolve(nil);
        return;
    }

    RCTLogInfo(@"[AudioMode] Selected input: %@", uid);

    AVAudioSessionPortDescription *port = nil;
    if (![uid isEqualToString:kInputAuto]) {
        for (AVAudioSessionPortDescription *portDesc in [AVAudioSession sharedInstance].availableInputs) {
            if ([portDesc.UID isEqualToString:uid]) {
                port = portDesc;
                break;
            }
        }
        if (port == nil) {
            reject(@"setAudioInput", @"Could not find audio input", nil);
            return;
        }
    }

    RTCAudioSession *session = JitsiAudioSession.rtcAudioSession;
    NSError *error = nil;
    [session lockForConfiguration];
    BOOL success = [session setPreferredInput:port error:&error];
    [session unlockForConfiguration];

    if (success) {
        resolve(nil);
    } else {
        reject(@"setAudioInput", error != nil ? error.localizedDescription : @"", error);
    }

    [self notifyDevicesChanged];
}

RCT_EXPORT_METHOD(updateDeviceList) {
    if (audioDisabled) {
        return;
    }

    [self notifyDevicesChanged];
}

#pragma mark - RTCAudioSessionDelegate

- (void)audioSessionDidChangeRoute:(RTCAudioSession *)session
                            reason:(AVAudioSessionRouteChangeReason)reason
                     previousRoute:(AVAudioSessionRouteDescription *)previousRoute {
    RCTLogInfo(@"[AudioMode] Route changed, reason: %lu", (unsigned long)reason);

    // Update JS about the changes.
    [self notifyDevicesChanged];

    dispatch_async(_workerQueue, ^{
        switch (reason) {
            case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
                // If the device list changed, reset our overrides.
                self->forceSpeaker = NO;
                self->forceEarpiece = NO;
                break;
            case AVAudioSessionRouteChangeReasonCategoryChange:
                // The category has changed, re-apply our config.
                // NB: It's tempting to doa  category check here and skip the processing,
                // but that won't work. If the config changes but the category remains
                // the same we'll still find ourselves here.
                break;
            default:
                return;
        }

        // We don't want to touch the category when in default mode.
        // This is to play well with other components which could be integrated
        // into the final application.
        if (self->activeMode != kAudioModeDefault) {
            RCTLogInfo(@"[AudioMode] Route changed, reapplying RTCAudioSession config");
            RTCAudioSessionConfiguration *config = [self configForMode:self->activeMode];
            [self setConfig:config error:nil];
            if (self->forceSpeaker && !self->isSpeakerOn) {
                [session lockForConfiguration];
                [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
                [session unlockForConfiguration];
            }
        }
    });
}

- (void)audioSession:(RTCAudioSession *)audioSession didSetActive:(BOOL)active {
    RCTLogInfo(@"[AudioMode] Audio session didSetActive:%d", active);
}

#pragma mark - Helper methods

- (RTCAudioSessionConfiguration *)configForMode:(int) mode {
    if (mode != kAudioModeDefault && forceEarpiece) {
        return earpieceConfig;
    }

    switch (mode) {
        case kAudioModeAudioCall:
            return audioCallConfig;
        case kAudioModeDefault:
            return defaultConfig;
        case kAudioModeVideoCall:
            return videoCallConfig;
        default:
            return nil;
    }
}

// Here we convert input and output port types into a single type.
- (NSString *)portTypeToString:(AVAudioSessionPort) portType {
    if ([portType isEqualToString:AVAudioSessionPortHeadphones]
            || [portType isEqualToString:AVAudioSessionPortHeadsetMic]) {
        return kDeviceTypeHeadphones;
    } else if ([portType isEqualToString:AVAudioSessionPortBuiltInMic]
            || [portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
        return kDeviceTypeEarpiece;
    } else if ([portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
        return kDeviceTypeSpeaker;
    } else if ([portType isEqualToString:AVAudioSessionPortBluetoothHFP]
            || [portType isEqualToString:AVAudioSessionPortBluetoothLE]
            || [portType isEqualToString:AVAudioSessionPortBluetoothA2DP]) {
        return kDeviceTypeBluetooth;
    } else if ([portType isEqualToString:AVAudioSessionPortCarAudio]) {
        return kDeviceTypeCar; 
    } else {
        return kDeviceTypeUnknown;
    }
}

// Input types (must match Java and the Podium channel consumers).
- (NSString *)inputTypeToString:(AVAudioSessionPort) portType {
    if ([portType isEqualToString:AVAudioSessionPortBuiltInMic]) {
        return @"BUILTIN";
    } else if ([portType isEqualToString:AVAudioSessionPortHeadsetMic]) {
        return @"WIRED";
    } else if ([portType isEqualToString:AVAudioSessionPortBluetoothHFP]
            || [portType isEqualToString:AVAudioSessionPortBluetoothLE]) {
        return @"BLUETOOTH";
    } else if ([portType isEqualToString:AVAudioSessionPortUSBAudio]) {
        return @"USB";
    } else if ([portType isEqualToString:AVAudioSessionPortCarAudio]) {
        return @"CAR";
    } else {
        return @"OTHER";
    }
}

- (void)notifyDevicesChanged {
    dispatch_async(_workerQueue, ^{
        NSMutableArray *data = [[NSMutableArray alloc] init];
        // Here we use AVAudioSession because RTCAudioSession doesn't expose availableInputs.
        AVAudioSession *session = [AVAudioSession sharedInstance];
        AVAudioSessionRouteDescription *currentRoute = session.currentRoute;
        AVAudioSessionPortDescription *output = currentRoute.outputs.firstObject;
        AVAudioSessionPortDescription *input = currentRoute.inputs.firstObject;
        NSString *outputType = output != nil ? [self portTypeToString:output.portType] : kDeviceTypeUnknown;

        self->isSpeakerOn = [outputType isEqualToString:kDeviceTypeSpeaker];
        self->isEarpieceOn = output != nil && [output.portType isEqualToString:AVAudioSessionPortBuiltInReceiver];

        // The output list is made of inputs (plus the speaker), so an entry is the current output
        // when its type matches the output port; wireless devices also have to match by name, as
        // there can be several of them. Matching on the input instead would mark an external mic
        // as the output.
        BOOL (^isCurrentOutput)(NSString *, NSString *) = ^BOOL(NSString *type, NSString *name) {
            if (![type isEqualToString:outputType]) return NO;
            if ([type isEqualToString:kDeviceTypeBluetooth] || [type isEqualToString:kDeviceTypeCar]) {
                return [name isEqualToString:output.portName];
            }
            return YES;
        };

        BOOL headphonesAvailable = NO;
        for (AVAudioSessionPortDescription *portDesc in session.availableInputs) {
            if ([portDesc.portType isEqualToString:AVAudioSessionPortHeadsetMic] || [portDesc.portType isEqualToString:AVAudioSessionPortHeadphones]) {
                headphonesAvailable = YES;
                break;
            }
        }

        for (AVAudioSessionPortDescription *portDesc in session.availableInputs) {
            // Skip "Phone" if headphones are present.
            if (headphonesAvailable && [portDesc.portType isEqualToString:AVAudioSessionPortBuiltInMic]) {
                continue;
            }
            NSString *type = [self portTypeToString:portDesc.portType];
            id deviceData
                = @{
                    @"type": type,
                    @"name": portDesc.portName,
                    @"uid": portDesc.UID,
                    @"selected": [NSNumber numberWithBool:isCurrentOutput(type, portDesc.portName)]
                };
            [data addObject:deviceData];
        }

        // We need to manually add the speaker because it will never show up in the
        // previous list, as it's not an input.
        [data addObject:
            @{ @"type": kDeviceTypeSpeaker,
               @"name": @"Speaker",
               @"uid": kDeviceTypeSpeaker,
               @"selected": [NSNumber numberWithBool:self->isSpeakerOn]
        }];
        
        [self sendEventWithName:kDevicesChanged body:data];

        NSString *preferredUID = session.preferredInput.UID;
        NSMutableArray *inputs = [[NSMutableArray alloc] init];
        for (AVAudioSessionPortDescription *portDesc in session.availableInputs) {
            [inputs addObject:@{
                @"type": [self inputTypeToString:portDesc.portType],
                @"name": portDesc.portName,
                @"uid": portDesc.UID,
                @"selected": [NSNumber numberWithBool:[portDesc.UID isEqualToString:input.UID]],
                @"preferred": [NSNumber numberWithBool:[portDesc.UID isEqualToString:preferredUID]]
            }];
        }

        [self sendEventWithName:kInputsChanged body:inputs];
    });
}

@end
