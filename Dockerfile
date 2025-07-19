# Ubuntu 24.04 base image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install mpv and Intel VAAPI support
RUN apt-get update && apt-get install -y --no-install-recommends \
    mpv \
    libva-drm2 \
    intel-media-va-driver-non-free \
    fbset \
    intel-gpu-tools \
    vainfo \
    && rm -rf /var/lib/apt/lists/*

# ENV variables for VAAPI
ENV LIBVA_DRIVER_NAME=iHD
ENV LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri

WORKDIR /app

COPY process-videos.sh .

RUN chmod +x process-videos.sh

CMD ["/app/process-videos.sh"]
