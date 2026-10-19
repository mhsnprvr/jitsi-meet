package org.jitsi.meet.sdk;

import android.content.Context;
import android.graphics.Color;
import android.view.Gravity;
import android.widget.FrameLayout;

import androidx.annotation.Nullable;

import com.oney.WebRTCModule.EglUtils;
import com.oney.WebRTCModule.WebRTCModule;

import org.jitsi.meet.sdk.log.JitsiMeetLogger;
import org.webrtc.MediaStreamTrack;
import org.webrtc.RendererCommon;
import org.webrtc.SurfaceViewRenderer;
import org.webrtc.VideoTrack;

/**
 * Renders a single remote WebRTC video track (a screen share) outside of the React Native UI, so a
 * host app can show it while the conference itself stays hidden.
 *
 * The renderer is a media overlay surface: it sits above the host's own SurfaceView (Flutter) but
 * below the window, so the host can't draw on top of it.
 */
public class PodiumStageView extends FrameLayout {
    private static final String TAG = PodiumStageView.class.getSimpleName();

    public interface Listener {
        void onVideoSizeChanged(int width, int height);
    }

    private final SurfaceViewRenderer renderer;
    @Nullable private Listener listener;
    @Nullable private VideoTrack track;
    @Nullable private String trackKey;
    private boolean rendererInitialized;

    public PodiumStageView(Context context) {
        super(context);
        setBackgroundColor(Color.BLACK);
        renderer = new SurfaceViewRenderer(context);
        renderer.setZOrderMediaOverlay(true);
        renderer.setScalingType(RendererCommon.ScalingType.SCALE_ASPECT_FIT);
        renderer.setEnableHardwareScaler(true);
        addView(renderer, new LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT, Gravity.CENTER));
    }

    public void setListener(@Nullable Listener listener) {
        this.listener = listener;
    }

    /**
     * Shows the remote track identified the way react-native-webrtc does, or clears the stage when
     * {@code trackId} is null.
     */
    public void setTrack(int pcId, @Nullable String trackId) {
        String key = trackId == null ? null : pcId + ":" + trackId;
        if (key == null ? trackKey == null : key.equals(trackKey)) {
            return;
        }
        trackKey = key;
        if (trackId == null) {
            attach(null);
            return;
        }
        WebRTCModule module = ReactInstanceManagerHolder.getNativeModule(WebRTCModule.class);
        if (module == null) {
            JitsiMeetLogger.w(TAG + " WebRTCModule unavailable");
            return;
        }
        MediaStreamTrack found;
        try {
            found = module.getTrack(pcId, trackId);
        } catch (RuntimeException e) {
            JitsiMeetLogger.w(e, TAG + " track lookup failed");
            found = null;
        }
        if (found instanceof VideoTrack) {
            attach((VideoTrack) found);
        } else {
            JitsiMeetLogger.w(TAG + " no video track for " + key);
            trackKey = null;
            attach(null);
        }
    }

    public void release() {
        trackKey = null;
        attach(null);
        if (rendererInitialized) {
            renderer.release();
            rendererInitialized = false;
        }
    }

    private void ensureRenderer() {
        if (rendererInitialized) return;
        renderer.init(EglUtils.getRootEglBaseContext(), new RendererCommon.RendererEvents() {
            @Override
            public void onFirstFrameRendered() {}

            @Override
            public void onFrameResolutionChanged(int width, int height, int rotation) {
                boolean rotated = rotation == 90 || rotation == 270;
                int w = rotated ? height : width;
                int h = rotated ? width : height;
                post(() -> {
                    if (listener != null) listener.onVideoSizeChanged(w, h);
                });
            }
        });
        rendererInitialized = true;
    }

    private void attach(@Nullable VideoTrack next) {
        if (track == next) return;
        if (track != null) {
            try {
                track.removeSink(renderer);
            } catch (IllegalStateException e) {
                // The track was already disposed by react-native-webrtc.
            }
        }
        track = next;
        if (next == null) {
            if (rendererInitialized) renderer.clearImage();
            return;
        }
        ensureRenderer();
        try {
            next.addSink(renderer);
        } catch (IllegalStateException e) {
            track = null;
            JitsiMeetLogger.w(TAG + " track disposed before it could be shown");
        }
    }
}
