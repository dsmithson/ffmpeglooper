# Base image: Ubuntu 22.04 LTS
FROM ubuntu:24.04

# Set frontend to noninteractive to avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install FFmpeg, Intel VA-API drivers, and other utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    intel-media-va-driver-non-free \
    vainfo \
    fbset \
    && rm -rf /var/lib/apt/lists/*

# Create a directory for our application
WORKDIR /app

# Copy the video processing script into the container
COPY process-videos.sh .

# Make the script executable
RUN chmod +x process-videos.sh

# Set the default command to run the script
CMD ["/app/process-videos.sh"]

