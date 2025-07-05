#!/bin/bash

LOCAL_RECORDINGS_DIR="${PWD}/recordings"
mkdir -p "$LOCAL_RECORDINGS_DIR"

echo "VNC recordings will be saved to: $LOCAL_RECORDINGS_DIR"

docker build -t vnchoneypot .

run_container() {
    echo "[$(date)] Starting VNC honeypot container (will restart in 10 minutes)..."

    docker run --rm \
        -p 5905:5900 \
        -v "$LOCAL_RECORDINGS_DIR:/recordings" \
        -e RECORDINGS_DIR=/recordings \
        -e X11VNC_CREATE_GEOM="${X11VNC_CREATE_GEOM:-1024x768x16}" \
        --name vnc-honeypot \
        vnchoneypot &
    
    DOCKER_PID=$!
    
    # wait for 10 minutes or until interrupted
    SECONDS=0
    while [ $SECONDS -lt 600 ] && kill -0 $DOCKER_PID 2>/dev/null; do
        sleep 1
    done
    
    # if container is still running after 10 minutes, stop it
    if kill -0 $DOCKER_PID 2>/dev/null; then
        echo "[$(date)] Container timeout reached, stopping gracefully..."
        docker stop vnc-honeypot 2>/dev/null || true
    fi
    
    # wait for docker process to finish
    wait $DOCKER_PID 2>/dev/null
}

# flag to control the loop
RUNNING=true

cleanup() {
    echo -e "\n[$(date)] Stopping VNC honeypot..."
    RUNNING=false
    docker stop vnc-honeypot 2>/dev/null || true
    echo "[$(date)] Honeypot stopped. Goodbye!"
    exit 0
}
trap cleanup SIGINT SIGTERM

# auto-restart loop to avoid persistent compromise
while $RUNNING; do
    run_container
    if $RUNNING; then
        echo "[$(date)] Container stopped. Restarting..."
        sleep 2
    fi
done
