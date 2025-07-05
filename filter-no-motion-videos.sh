#!/bin/bash

# Find videos with no motion using FFmpeg scene detection

RECORDINGS_DIR="${1:-./recordings}"
SCENE_THRESHOLD="0.01"
MIN_SCENE_CHANGES="5"

echo "Checking videos in: $RECORDINGS_DIR"
echo "---"

# Collect files with no motion
no_motion_files=""
find "$RECORDINGS_DIR" -type f -name "*.mp4" | sort | while read -r video; do
    scene_count=$(ffmpeg -i "$video" -vf "select='gt(scene,$SCENE_THRESHOLD)',showinfo" -f null - 2>&1 | grep -c "showinfo" || true)

    if [ "$scene_count" -lt "$MIN_SCENE_CHANGES" ]; then
        echo "$(basename "$video"): $scene_count scene changes - likely no motion!"
        echo "$video" >> /tmp/no_motion_files.txt
    fi
done

# Check if any files were found
if [ ! -f /tmp/no_motion_files.txt ]; then
    echo "No static videos found."
    exit 0
fi

# Ask for confirmation
echo ""
echo -n "Delete these files? (y/N): "
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    while read -r file; do
        rm "$file"
        echo "Deleted: $(basename "$file")"
    done < /tmp/no_motion_files.txt
fi

rm -f /tmp/no_motion_files.txt
