FROM docker.io/library/ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    xvfb xauth mesa-vulkan-drivers libvulkan1 libgl1-mesa-dri libglx-mesa0 libegl1 \
    libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libxrender1 libasound2t64 libpulse0 \
    libfontconfig1 libxkbcommon0 libxkbcommon-x11-0 libwayland-client0 libwayland-cursor0 libwayland-egl1 libdbus-1-3 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
