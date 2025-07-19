#!/bin/bash

VIDEO_DIR="/videos"
SHOULD_EXIT=false

# Set MPV log level (can be overridden via environment variable)
MPV_LOGLEVEL="${MPV_LOGLEVEL:-vo=warn}"

cleanup() {
    echo "Received termination signal. Stopping gracefully..."
    SHOULD_EXIT=true
    pkill -f mpv
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

echo "Starting mpv Looper..."
echo "Monitoring directory: ${VIDEO_DIR}"

while true; do
  if [ "$SHOULD_EXIT" = true ]; then
    echo "Exiting gracefully..."
    break
  fi

  if [ -z "$(ls -A ${VIDEO_DIR})" ]; then
    echo "No videos found in ${VIDEO_DIR}. Sleeping for 60 seconds."
    sleep 60 &
    wait $!
    continue
  fi

  find "${VIDEO_DIR}" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | while read -r file; do
    filename=$(basename -- "$file")
    echo "Playing file: ${filename}"

    # Play using hardware-accelerated mpv in DRM/KMS mode
    mpv --msg-level="$MPV_LOGLEVEL" --profile=fast --hwdec=vaapi --vo=gpu --gpu-context=drm --fs "$file"
    
    if [ $? -eq 0 ]; then
      echo "Finished playing ${filename}"
    elif [ "$SHOULD_EXIT" = true ]; then
      echo "Playback interrupted"
      break
    else
      echo "ERROR: Playback failed for ${filename}"
      sleep 10 &
      wait $!
    fi
  done

  echo "All videos played. Looping again..."
done
