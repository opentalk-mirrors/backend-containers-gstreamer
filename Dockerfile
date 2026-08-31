# SPDX-FileCopyrightText: OpenTalk GmbH <mail@opentalk.eu>
#
# SPDX-License-Identifier: EUPL-1.2

FROM ubuntu:26.04 AS builder

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y --no-install-recommends git ca-certificates && update-ca-certificates

ARG GSTREAMER_GIT=https://gitlab.freedesktop.org/gstreamer/gstreamer.git
RUN git clone $GSTREAMER_GIT

RUN apt-get install -y \
    ninja-build python3-venv python3-pip \
    # Gstreamer
    bison flex cmake nasm pkg-config libssl-dev librtmp-dev \
    # VAAPI DRM
    libva-dev libdrm-dev libudev-dev

RUN python3 -m venv /pyenv
RUN /pyenv/bin/pip3 install meson setuptools    

WORKDIR /gstreamer

ARG GSTREAMER_CHECKOUT=1.26
RUN git checkout $GSTREAMER_CHECKOUT

RUN /pyenv/bin/meson setup /build/ \
    -Dprefix=/usr -Dlibdir=/usr/lib \
    -Dgpl=enabled -Dgst-plugins-bad:va=enabled -Dvaapi=enabled -Dwebrtc=enabled -Dlibav=enabled \
    -Dlibnice=enabled -Dlibnice:gupnp=disabled -Dpython=disabled -Dgst-plugins-bad:rtmp=enabled -Dgst-plugins-bad:rtmp2=enabled  \
    -D optimization=3 -D b_lto=true

WORKDIR /build

RUN ninja install
RUN DESTDIR=/gstreamer-install ninja install

# ==== Base production image

FROM ubuntu:26.04 AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    # VAAPI via DRM
    libva2 libva-drm2 libudev1 librtmp1 libexpat1 \
    # Generic dependencies
    openssl

RUN ln -s /usr/lib/x86_64-linux-gnu/libpython3.12.so.1 /usr/lib/x86_64-linux-gnu/libpython3.12.so

COPY --from=builder /gstreamer-install/ /

# ==== With intel drivers

FROM base AS intel
RUN apt-get install -y --no-install-recommends intel-media-va-driver 

# ==== With nvidia drivers

FROM base AS nvidia
RUN apt-get install -y --no-install-recommends nvidia-vaapi-driver
