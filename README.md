# FFmpeg Looper

This repository contains a Dockerized solution for continuously looping through and playing video files using FFmpeg. It's designed to play videos from a directory to a local display's framebuffer (e.g., a monitor connected to your server).

## How It Works

The `process-videos.sh` script runs in an infinite loop, scanning the `/videos` directory inside the container for video files. It will play each video file one by one to the framebuffer device (`/dev/fb0`). Once all videos have been played, it will start over from the beginning, creating a continuous loop.

## Getting Started

### Prerequisites

-   [Docker](https://docs.docker.com/get-docker/) installed on your system.
-   A display connected to your server with access to the framebuffer device (`/dev/fb0`).
-   Your user must be in the `video` group on the host to access `/dev/fb0`.

### Building the Docker Image

To build the Docker image, clone this repository and run the following command in the root directory:

```bash
docker build -t dsmithson/ffmpeg-looper:latest .
```

### Running the Container

To run the container, you need to mount a directory from your host machine to the `/videos` directory inside the container, and also mount the framebuffer device.

```bash
docker run -d --rm \
  --device=/dev/fb0:/dev/fb0 \
  -v /path/to/your/videos:/videos \
  --name ffmpeg-looper \
  dsmithson/ffmpeg-looper:latest
```

-   `-d`: Runs the container in detached mode.
-   `--rm`: Automatically removes the container when it exits.
-   `--device=/dev/fb0:/dev/fb0`: This passes the framebuffer device to the container so FFmpeg can play video to it.
-   `-v /path/to/your/videos:/videos`: Mounts your local video directory to the `/videos` directory in the container. **Replace `/path/to/your/videos` with the actual path to your videos.**
-   `--name ffmpeg-looper`: Assigns a name to the container.
-   `dsmithson/ffmpeg-looper:latest`: The name of the image you built earlier.

## Customization

The FFmpeg command can be customized by editing the `process-videos.sh` script. Look for the following section in the script:

```bash
read fb_width fb_height < <(fbset | awk '/geometry/ {print $2, $3}')
ffmpeg -re -i "$file" -vf "scale=${fb_width}:${fb_height}" -pix_fmt bgra -f fbdev /dev/fb0
```

You can change the `ffmpeg` command to whatever you need. After modifying the script, you'll need to rebuild the Docker image.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.