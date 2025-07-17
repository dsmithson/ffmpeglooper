#!/bin/bash

# Directory where videos are mounted inside the container
VIDEO_DIR="/videos"

# Set FFmpeg log level, default to 'warning' if not set
FFMPEG_LOGLEVEL="${FFMPEG_LOGLEVEL:-warning}"

echo "Starting FFmpeg Looper..."
echo "Monitoring directory: ${VIDEO_DIR}"

# Continuously loop to process new videos
while true; do
  if [ -z "$(ls -A ${VIDEO_DIR})" ]; then
    echo "No videos found in ${VIDEO_DIR}.  Sleeping for 60 seconds."
    sleep 60
    continue
  fi

  echo "Searching for video files (.mp4, .mkv, .avi, .mov)..."
  
  # Find video files, excluding the processed directory
  find "${VIDEO_DIR}" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | while read -r file; do
    filename=$(basename -- "$file")
    
    echo "Playing file: ${file}"

    # =================================================================================
    # This plays the video to the framebuffer using Intel QSV hardware acceleration.
    # Note we read in the resolution of the framebuffer using fbset.
    #
    # -hwaccel qsv: Use Intel QuickSync Video for hardware decoding
    # -re: Read input at native frame rate.
    # -i "$file": Specifies the input file.
    # -vf "scale_qsv=<width>:<height>": Hardware scaling using Intel QSV
    # -pix_fmt bgra: Pixel format for the framebuffer.
    # -f fbdev /dev/fb0: Output to the framebuffer device.
    # =================================================================================
    read fb_width fb_height < <(fbset | awk '/geometry/ {print $2, $3}')
    echo "Detected framebuffer resolution: ${fb_width}x${fb_height}"
    
    # Try hardware acceleration first, fallback to software if it fails
    echo "Attempting hardware-accelerated playback with Intel QSV..."
    ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -hwaccel qsv -re -i "$file" -vf "scale_qsv=${fb_width}:${fb_height}" -pix_fmt bgra -f fbdev /dev/fb0
    
    # Check if hardware acceleration failed
    if [ $? -ne 0 ]; then
      echo "Hardware acceleration failed, falling back to software decoding..."
      ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -re -i "$file" -vf "scale=${fb_width}:${fb_height}" -pix_fmt bgra -f fbdev /dev/fb0
    fi

    if [ $? -eq 0 ]; then
      echo "Finished playing ${filename}"
    else
      echo "ERROR: Failed to play ${filename}"
      # Optional: handle the error, e.g., sleep for a bit before retrying
      sleep 10
    fi
  done

  echo "All videos played. Looping again..."
done