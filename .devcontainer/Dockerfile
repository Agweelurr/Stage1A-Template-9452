# Microsoft Java 25 on Debian Trixie: Codespaces-ready (vscode user) and the
# 2027 WPILib native ABI (glibc 2.41). WPILib's own debian-base image is a CI
# compiler toolchain for building allwpilib, not a team workspace — we copy
# its runtime libraries here instead of FROM wpilib/*.
FROM mcr.microsoft.com/devcontainers/java:25-trixie

USER root

# Runtime libs for the prebuilt sim GUI / Glass / Elastic / AdvantageScope
# binaries (SDL3 in 2027, plus Mesa software GL for Codespaces).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        unzip \
        python3 \
        x11-apps \
        libgl1 \
        libglu1-mesa \
        libegl1 \
        libgles2 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        libgbm1 \
        libdrm2 \
        libvulkan1 \
        mesa-vulkan-drivers \
        libsdl3-0 \
        libsdl2-2.0-0 \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libxrandr2 \
        libxinerama1 \
        libxi6 \
        libxcursor1 \
        libxxf86vm1 \
        libx11-xcb1 \
        libxss1 \
        libgtk-3-0t64 \
        libnss3 \
        libatk1.0-0t64 \
        libatk-bridge2.0-0t64 \
        libcups2t64 \
        libasound2t64 \
        libnotify4 \
        libsecret-1-0 \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# WPILib is not on the Marketplace ("use the installer"). Pre-extract the VSIX
# so local Dev Containers have the files before VS Code Server scans extensions.
# Codespaces still needs `code --install-extension` in post-attach.sh.
ARG WPILIB_VSIX_VERSION=2027.0.0-alpha-7
RUN EXT_DIR=/home/vscode/.vscode-server/extensions/wpilibsuite.vscode-wpilib-${WPILIB_VSIX_VERSION} \
    && mkdir -p "$EXT_DIR" \
    && wget -q "https://github.com/wpilibsuite/vscode-wpilib/releases/download/v${WPILIB_VSIX_VERSION}/vscode-wpilib-${WPILIB_VSIX_VERSION}.vsix" \
        -O /tmp/vscode-wpilib.vsix \
    && unzip -q /tmp/vscode-wpilib.vsix 'extension/*' -d /tmp/vscode-wpilib-unpack \
    && cp -r /tmp/vscode-wpilib-unpack/extension/. "$EXT_DIR/" \
    && chown -R vscode:vscode /home/vscode/.vscode-server \
    && rm -rf /tmp/vscode-wpilib-unpack /tmp/vscode-wpilib.vsix

USER vscode
