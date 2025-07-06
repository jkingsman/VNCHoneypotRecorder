#!/bin/bash

RECORDINGS_DIR="${RECORDINGS_DIR:-/tmp/recordings}"

mkdir -p "$RECORDINGS_DIR"

LOGFILE="$RECORDINGS_DIR/recording.log"

echo "[$(date)] Recording monitor started" >> "$LOGFILE"

has_vnc_connections() {
    netstat -tn 2>/dev/null | grep -q ":5900.*ESTABLISHED"
}

# grabs first connected IP for filename
get_client_ip() {
    # Get the remote address (IP:port) from netstat
    remote_addr=$(netstat -tn 2>/dev/null | grep ":5900.*ESTABLISHED" | head -1 | awk '{print $5}')

    # Handle IPv6 addresses (enclosed in brackets) and IPv4 addresses
    if [[ "$remote_addr" =~ ^\[(.+)\]:([0-9]+)$ ]]; then
        # IPv6 format: [2001:db8::1]:12345
        echo "${BASH_REMATCH[1]}" | tr ':' '_'  # Replace colons with underscores for filename compatibility
    elif [[ "$remote_addr" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+)$ ]]; then
        # IPv4 format: 192.168.1.1:12345
        echo "${BASH_REMATCH[1]}"
    else
        # Fallback: try to extract everything before the last colon
        echo "$remote_addr" | sed 's/:[^:]*$//' | tr ':' '_'
    fi
}

start_recording() {
    if [ -f /tmp/ffmpeg_recording.pid ]; then
        return
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    CLIENT_IP=$(get_client_ip)
    if [ -z "$CLIENT_IP" ]; then
        CLIENT_IP="unknown"
    fi

    FILENAME="$RECORDINGS_DIR/vnc_session_${TIMESTAMP}_${CLIENT_IP}.mp4"

    echo "[$(date)] Starting recording to ${FILENAME}" >> "$LOGFILE"

    # grab actual screen size from x11
    GEOM=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}')
    if [ -z "$GEOM" ]; then
        GEOM="1024x768"
    fi

    # ffmpeg options for fragmented safety if it gets interrupted
    # ffmpeg itself is renamed in the Dockerfile
    /usr/local/bin/systemd-helper -f x11grab \
        -video_size $GEOM \
        -framerate 30 \
        -i ${DISPLAY} \
        -c:v libx264 \
        -preset fast \
        -crf 23 \
        -pix_fmt yuv420p \
        -g 30 \
        -keyint_min 30 \
        -movflags +frag_keyframe+empty_moov+default_base_moof+faststart \
        -fflags +genpts+discardcorrupt \
        -avoid_negative_ts make_zero \
        -max_muxing_queue_size 1024 \
        "$FILENAME" \
        >> "$LOGFILE" 2>&1 &

    FFMPEG_PID=$!
    echo $FFMPEG_PID > /tmp/ffmpeg_recording.pid
    echo $FILENAME > /tmp/ffmpeg_recording.filename
    echo "[$(date)] FFmpeg started with PID: $FFMPEG_PID" >> "$LOGFILE"
}

stop_recording() {
    if [ -f /tmp/ffmpeg_recording.pid ]; then
        PID=$(cat /tmp/ffmpeg_recording.pid)
        FILENAME=$(cat /tmp/ffmpeg_recording.filename 2>/dev/null || echo "unknown")

        echo "[$(date)] Stopping recording (PID: $PID)" >> "$LOGFILE"

        # sigint lets ffmpeg finish the file properly
        kill -INT $PID 2>/dev/null

        for i in {1..10}; do
            if ! kill -0 $PID 2>/dev/null; then
                break
            fi
            sleep 0.5
        done

        if kill -0 $PID 2>/dev/null; then
            echo "[$(date)] Force killing ffmpeg after timeout" >> "$LOGFILE"
            kill -9 $PID 2>/dev/null
        fi

        rm -f /tmp/ffmpeg_recording.pid /tmp/ffmpeg_recording.filename
        echo "[$(date)] Recording stopped. File: ${FILENAME}" >> "$LOGFILE"
    fi
}

trap 'stop_recording; exit 0' SIGTERM SIGINT

RECORDING=false
NO_CONNECTION_COUNT=0

while true; do
    if has_vnc_connections; then
        NO_CONNECTION_COUNT=0
        if [ "$RECORDING" = false ]; then
            start_recording
            RECORDING=true
        fi
    else
        if [ "$RECORDING" = true ]; then
            # wait a bit in case they're just reconnecting
            ((NO_CONNECTION_COUNT++))
            if [ $NO_CONNECTION_COUNT -ge 3 ]; then
                stop_recording
                RECORDING=false
                NO_CONNECTION_COUNT=0
            fi
        fi
    fi
    sleep 1
done
