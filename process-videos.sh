#!/bin/bash

# Directory where videos are mounted inside the container
VIDEO_DIR="/videos"

# Set FFmpeg log level, default to 'warning' if not set
FFMPEG_LOGLEVEL="${FFMPEG_LOGLEVEL:-warning}"

# Flag to indicate if we should exit
SHOULD_EXIT=false

# Signal handler function
cleanup() {
    echo "Received termination signal. Stopping gracefully..."
    SHOULD_EXIT=true
    # Kill any running ffmpeg processes
    pkill -f ffmpeg
    exit 0
}

# Trap termination signals
trap cleanup SIGTERM SIGINT SIGQUIT

echo "Starting FFmpeg Looper..."
echo "Monitoring directory: ${VIDEO_DIR}"

# Continuously loop to process new videos
while true; do
  # Check if we should exit
  if [ "$SHOULD_EXIT" = true ]; then
    echo "Exiting gracefully..."
    break
  fi

  if [ -z "$(ls -A ${VIDEO_DIR})" ]; then
    echo "No videos found in ${VIDEO_DIR}.  Sleeping for 60 seconds."
    sleep 60 &
    wait $!  # Wait for sleep, but allow interruption by signals
    continue
  fi

  echo "Searching for video files (.mp4, .mkv, .avi, .mov)..."
  
  # Find video files, excluding the processed directory
  find "${VIDEO_DIR}" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | while read -r file; do
    filename=$(basename -- "$file")
    
    echo "Playing file: ${file}"

    # =================================================================================
    # This plays the video to the framebuffer using Intel hardware acceleration.
    # We try multiple hardware acceleration methods in order of preference:
    # 1. Intel VA-API (most compatible)
    # 2. Intel QSV (QuickSync Video)  
    # 3. Software fallback
    # =================================================================================
    read fb_width fb_height < <(fbset | awk '/geometry/ {print $2, $3}')
    echo "Detected framebuffer resolution: ${fb_width}x${fb_height}"
    
    # Try Intel VA-API first (most compatible)
    echo "Attempting hardware-accelerated playback with Intel VA-API..."
    echo "File info: $(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name,width,height,pix_fmt -of csv=p=0 "$file" 2>/dev/null || echo 'unknown')"
    
    # Check if file resolution matches framebuffer resolution
    file_resolution=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$file" 2>/dev/null)
    fb_resolution="${fb_width},${fb_height}"
    
    echo "File resolution: ${file_resolution}"
    echo "Framebuffer resolution: ${fb_resolution}"
    
    if [ "$file_resolution" = "$fb_resolution" ]; then
      echo "Resolution match detected - attempting direct hardware decode without scaling..."
      ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
             -re -i "$file" \
             -vf "hwupload,hwdownload,format=bgra" \
             -pix_fmt bgra -f fbdev /dev/fb0 &
    else
      echo "Resolution mismatch - using hardware decode with VA-API scaling..."
      ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
             -re -i "$file" \
             -vf "hwupload,scale_vaapi=${fb_width}:${fb_height},hwdownload,format=bgra" \
             -pix_fmt bgra -f fbdev /dev/fb0 &
    fi
    FFMPEG_PID=$!
    
    # Wait for ffmpeg to complete, but allow interruption
    wait $FFMPEG_PID
    FFMPEG_EXIT_CODE=$?
    
    # If full VA-API failed, try simpler VA-API approach (hardware decode, software scale)
    if [ $FFMPEG_EXIT_CODE -ne 0 ] && [ "$SHOULD_EXIT" = false ]; then
      echo "Full VA-API failed, trying hardware decode with software scale..."
      echo "This will use hardware decode but software scaling - expect moderate CPU usage"
      ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -re -i "$file" \
             -vf "scale=${fb_width}:${fb_height}" -pix_fmt bgra -f fbdev /dev/fb0 &
      FFMPEG_PID=$!
      wait $FFMPEG_PID
      FFMPEG_EXIT_CODE=$?
    fi
    
    # If VA-API failed, try QSV
    if [ $FFMPEG_EXIT_CODE -ne 0 ] && [ "$SHOULD_EXIT" = false ]; then
      echo "VA-API failed, trying QSV hardware acceleration..."
      ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -hwaccel qsv -re -i "$file" -vf "scale_qsv=${fb_width}:${fb_height}" -pix_fmt bgra -f fbdev /dev/fb0 &
      FFMPEG_PID=$!
      wait $FFMPEG_PID
      FFMPEG_EXIT_CODE=$?
    fi
    
    # If both hardware methods failed, fall back to software
    if [ $FFMPEG_EXIT_CODE -ne 0 ] && [ "$SHOULD_EXIT" = false ]; then
      echo "Hardware acceleration failed, falling back to software decoding..."
      ffmpeg -loglevel "$FFMPEG_LOGLEVEL" -re -i "$file" -vf "scale=${fb_width}:${fb_height}" -pix_fmt bgra -f fbdev /dev/fb0 &
      FFMPEG_PID=$!
      wait $FFMPEG_PID
      FFMPEG_EXIT_CODE=$?
    fi

    if [ $FFMPEG_EXIT_CODE -eq 0 ]; then
      echo "Finished playing ${filename}"
    elif [ "$SHOULD_EXIT" = true ]; then
      echo "Interrupted playback of ${filename} due to termination signal"
      break
    else
      echo "ERROR: Failed to play ${filename}"
      # Optional: handle the error, e.g., sleep for a bit before retrying
      sleep 10 &
      wait $!
    fi
  done

  echo "All videos played. Looping again..."
done