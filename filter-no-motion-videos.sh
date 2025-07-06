#!/usr/bin/env bash

# parse arguments
AUTO_CONFIRM=false
RECORDINGS_DIR="./recordings"

while [[ $# -gt 0 ]]; do
    case $1 in
        -y)
            AUTO_CONFIRM=true
            shift
            ;;
        *)
            RECORDINGS_DIR="$1"
            shift
            ;;
    esac
done

SCENE_THRESHOLD="0.01"
MIN_SCENE_CHANGES="5"

echo "Checking videos in: $RECORDINGS_DIR"
echo "---"

# Find all video files
mapfile -t video_files < <(find "$RECORDINGS_DIR" -type f -name "*.mp4" | sort)

# Collect files with no motion
no_motion_files=()
for video in "${video_files[@]}"; do
    scene_count=$(ffmpeg -i "$video" -vf "select='gt(scene,$SCENE_THRESHOLD)',showinfo" -f null - 2>&1 | grep -c "showinfo" || true)

    if [ "$scene_count" -lt "$MIN_SCENE_CHANGES" ]; then
        echo "$(basename "$video"): $scene_count scene changes - likely no motion!"
        no_motion_files+=("$video")
    fi
done

# Check if any files were found
if [ ${#no_motion_files[@]} -eq 0 ]; then
    echo "No static videos found."
    exit 0
fi

# check for auto-confirm or ask
if [ "$AUTO_CONFIRM" = true ]; then
    for file in "${no_motion_files[@]}"; do
        rm "$file"
        echo "Deleted: $(basename "$file")"
    done
else
    echo ""
    echo -n "Delete these files? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        for file in "${no_motion_files[@]}"; do
            rm "$file"
            echo "Deleted: $(basename "$file")"
        done
    fi
fi
