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
#import "PodiumStageView.h"

@interface PodiumStageView () <RTCVideoViewDelegate>
@end

@implementation PodiumStageView {
    RTCMTLVideoView *_renderer;
    RTCVideoTrack *_track;
    NSString *_trackKey;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.blackColor;
        self.clipsToBounds = YES;

        _renderer = [[RTCMTLVideoView alloc] initWithFrame:self.bounds];
        _renderer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _renderer.videoContentMode = UIViewContentModeScaleAspectFit;
        _renderer.delegate = self;
        [self addSubview:_renderer];
    }

    return self;
}

- (void)setTrack:(NSInteger)pcId trackId:(NSString *)trackId {
    NSString *key = trackId ? [NSString stringWithFormat:@"%ld:%@", (long)pcId, trackId] : nil;
    if (key == _trackKey || [key isEqualToString:_trackKey]) {
        return;
    }
    _trackKey = key;
    if (!trackId) {
        [self attach:nil];
        return;
    }

    RCTBridge *bridge = [[JitsiMeet sharedInstance] getReactBridge];
    WebRTCModule *module = [bridge moduleForClass:[WebRTCModule class]];
    if (!module) {
        DDLogWarn(@"PodiumStageView: WebRTCModule unavailable");
        _trackKey = nil;
        return;
    }

    // react-native-webrtc owns its peer connections on its worker queue.
    __weak PodiumStageView *weakSelf = self;
    dispatch_async(module.workerQueue, ^{
        RTCPeerConnection *peerConnection = module.peerConnections[@(pcId)];
        RTCMediaStreamTrack *found = peerConnection.remoteTracks[trackId];
        dispatch_async(dispatch_get_main_queue(), ^{
            PodiumStageView *strongSelf = weakSelf;
            if (!strongSelf || ![key isEqualToString:strongSelf->_trackKey]) {
                return;
            }
            if ([found isKindOfClass:[RTCVideoTrack class]]) {
                [strongSelf attach:(RTCVideoTrack *)found];
            } else {
                DDLogWarn(@"PodiumStageView: no video track for %@", key);
                strongSelf->_trackKey = nil;
                [strongSelf attach:nil];
            }
        });
    });
}

- (void)releaseTrack {
    _trackKey = nil;
    [self attach:nil];
}

- (void)attach:(RTCVideoTrack *)next {
    if (_track == next) {
        return;
    }
    [_track removeRenderer:_renderer];
    _track = next;
    [next addRenderer:_renderer];
}

#pragma mark RTCVideoViewDelegate

- (void)videoView:(id<RTCVideoRenderer>)videoView didChangeVideoSize:(CGSize)size {
    if (size.width <= 0 || size.height <= 0) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onVideoSizeChanged) {
            self.onVideoSizeChanged(size);
        }
    });
}

@end
