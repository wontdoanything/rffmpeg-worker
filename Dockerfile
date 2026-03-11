FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    git \
    pkg-config \
    yasm \
    nasm \
    libsmbclient-dev \
    libbluray-dev \
    libssl-dev \
    libvulkan-dev \
    libvulkan1 \
    libplacebo-dev \
#    vulkan-tools \
    ninja-build \
    ca-certificates \
    vulkan-validationlayers-dev \
    && rm -rf /var/lib/apt/lists/*


WORKDIR /build

RUN git clone --depth 1 --branch release/7.1 --single-branch https://git.ffmpeg.org/ffmpeg.git

WORKDIR /build/ffmpeg

RUN pkg-config --modversion vulkan

RUN ./configure \
    --disable-debug \
    --disable-doc \
    --disable-ffplay \
    --enable-ffmpeg \
    --enable-ffprobe \
    --enable-libsmbclient \
    --enable-libbluray \
    --enable-gpl \
    --enable-version3 \
    --enable-openssl \
    --enable-vulkan \
    --enable-libplacebo \
    --extra-version="7.1" \
    --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && strip /usr/local/bin/ffmpeg || true \
    && strip /usr/local/bin/ffprobe || true

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    openssh-server \
    libsmbclient \
    libbluray2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd

COPY --from=builder /usr/local /usr/local
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
