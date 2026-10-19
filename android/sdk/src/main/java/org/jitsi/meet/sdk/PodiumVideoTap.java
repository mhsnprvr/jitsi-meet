package org.jitsi.meet.sdk;

import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.oney.WebRTCModule.WebRTCModule;

import org.jitsi.meet.sdk.log.JitsiMeetLogger;
import org.webrtc.MediaStreamTrack;
import org.webrtc.VideoSink;
import org.webrtc.VideoTrack;

import java.util.HashMap;
import java.util.Map;

/**
 * Hands the frames of a WebRTC video track to a host app sink, outside of the React Native UI.
 * Tracks are identified the way react-native-webrtc does: {@code pcId} -1 is a local track.
 * A sink is attached to at most one track at a time. Must be called on the main thread.
 */
public final class PodiumVideoTap {
    private static final String TAG = PodiumVideoTap.class.getSimpleName();

    private static final Map<VideoSink, VideoTrack> attachments = new HashMap<>();

    private PodiumVideoTap() {}

    /**
     * Attaches {@code sink} to the track, returning whether the track was found.
     */
    public static boolean addSink(int pcId, @NonNull String trackId, @NonNull VideoSink sink) {
        checkMainThread();
        removeSink(sink);
        WebRTCModule module = ReactInstanceManagerHolder.getNativeModule(WebRTCModule.class);
        if (module == null) {
            JitsiMeetLogger.w(TAG + " WebRTCModule unavailable");
            return false;
        }
        MediaStreamTrack found;
        try {
            found = module.getTrack(pcId, trackId);
        } catch (RuntimeException e) {
            JitsiMeetLogger.w(e, TAG + " track lookup failed");
            found = null;
        }
        if (!(found instanceof VideoTrack)) {
            JitsiMeetLogger.w(TAG + " no video track for " + pcId + ":" + trackId);
            return false;
        }
        VideoTrack track = (VideoTrack) found;
        try {
            track.addSink(sink);
        } catch (IllegalStateException e) {
            JitsiMeetLogger.w(TAG + " track disposed before it could be tapped");
            return false;
        }
        attachments.put(sink, track);
        return true;
    }

    public static void removeSink(@Nullable VideoSink sink) {
        checkMainThread();
        if (sink == null) return;
        VideoTrack track = attachments.remove(sink);
        if (track == null) return;
        try {
            track.removeSink(sink);
        } catch (IllegalStateException e) {
            // The track was already disposed by react-native-webrtc.
        }
    }

    private static void checkMainThread() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            throw new IllegalStateException("PodiumVideoTap must be used on the main thread");
        }
    }
}
