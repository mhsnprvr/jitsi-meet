/*
 * Copyright @ 2026-present 8x8, Inc.
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

#import <React/RCTBridge.h>
#import <WebRTC/WebRTC.h>
#import <react-native-webrtc/WebRTCModule.h>
#import <react-native-webrtc/WebRTCModule+RTCPeerConnection.h>

#import "JitsiMeet+Private.h"
#import "LogUtils.h"
#import "PodiumVideoTap.h"

@implementation PodiumVideoTap

/// Renderer -> track it is attached to. Only touched on the main queue.
+ (NSMapTable<id, RTCVideoTrack *> *)attachments {
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable strongToStrongObjectsMapTable];
    });
    return table;
}

+ (void)addRenderer:(id)renderer
              pcId:(NSInteger)pcId
           trackId:(NSString *)trackId
        completion:(void (^)(BOOL))completion {
    void (^finish)(BOOL) = ^(BOOL attached) {
        if (completion) {
            completion(attached);
        }
    };
    if (![renderer conformsToProtocol:@protocol(RTCVideoRenderer)]) {
        DDLogWarn(@"PodiumVideoTap: renderer is not an RTCVideoRenderer");
        dispatch_async(dispatch_get_main_queue(), ^{ finish(NO); });
        return;
    }

    RCTBridge *bridge = [[JitsiMeet sharedInstance] getReactBridge];
    WebRTCModule *module = [bridge moduleForClass:[WebRTCModule class]];
    if (!module) {
        DDLogWarn(@"PodiumVideoTap: WebRTCModule unavailable");
        dispatch_async(dispatch_get_main_queue(), ^{ finish(NO); });
        return;
    }

    // react-native-webrtc owns its tracks and peer connections on its worker queue.
    dispatch_async(module.workerQueue, ^{
        RTCMediaStreamTrack *found;
        if (pcId == -1) {
            found = module.localTracks[trackId];
        } else {
            found = module.peerConnections[@(pcId)].remoteTracks[trackId];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeRenderer:renderer];
            if (![found isKindOfClass:[RTCVideoTrack class]]) {
                DDLogWarn(@"PodiumVideoTap: no video track for %ld:%@", (long)pcId, trackId);
                finish(NO);
                return;
            }
            RTCVideoTrack *track = (RTCVideoTrack *)found;
            [track addRenderer:(id<RTCVideoRenderer>)renderer];
            [[self attachments] setObject:track forKey:renderer];
            finish(YES);
        });
    });
}

+ (void)removeRenderer:(id)renderer {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeRenderer:renderer];
        });
        return;
    }
    RTCVideoTrack *track = [[self attachments] objectForKey:renderer];
    if (!track) {
        return;
    }
    [[self attachments] removeObjectForKey:renderer];
    [track removeRenderer:(id<RTCVideoRenderer>)renderer];
}

@end
