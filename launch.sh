#!/bin/bash

LOCAL_RECORDINGS_DIR="${PWD}/recordings"
mkdir -p "$LOCAL_RECORDINGS_DIR"

echo "VNC recordings will be saved to: $LOCAL_RECORDINGS_DIR"

docker build -t vnchoneypot .

copy_recordings() {
    CONTAINER_NAME=$1
    echo "[$(date)] Copying recordings from container..."
    docker cp "$CONTAINER_NAME":/tmp/recordings/. "$LOCAL_RECORDINGS_DIR"
    echo "[$(date)] Logs and/or recordings copied to: $LOCAL_RECORDINGS_DIR"
}

run_container() {
    echo "[$(date)] Starting VNC honeypot container (will restart in 10 minutes)..."

    CONTAINER_NAME="vnc-honeypot-$(date +%s)"

    docker run --rm \
        -p 5900:5900 \
        --hostname new_machine \
        --network host \
        -e X11VNC_CREATE_GEOM="${X11VNC_CREATE_GEOM:-1024x768x16}" \
        --name "$CONTAINER_NAME" \
        vnchoneypot &

    DOCKER_PID=$!

    # wait for 10 minutes or until interrupted
    SECONDS=0
    while [ $SECONDS -lt 600 ] && kill -0 $DOCKER_PID 2>/dev/null; do
        sleep 1
    done

    # if container is still running after 10 minutes, stop it
    if kill -0 $DOCKER_PID 2>/dev/null; then
        echo "[$(date)] Container timeout reached, copying recordings before stopping..."
        copy_recordings "$CONTAINER_NAME"
        echo "[$(date)] Stopping container gracefully..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
    fi

    # wait for docker process to finish
    wait $DOCKER_PID 2>/dev/null
}

# flag to control the loop
RUNNING=true

cleanup() {
    echo -e "\n[$(date)] Stopping VNC honeypot..."
    RUNNING=false

    # exfiltrate recordings
    for container in $(docker ps --filter "name=vnc-honeypot" --format "{{.Names}}"); do
        copy_recordings "$container"
        docker stop "$container" 2>/dev/null || true
    done

    echo "[$(date)] Container stopped. Exiting..."
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
