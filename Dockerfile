FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETOS
ARG TARGETARCH

RUN echo "RUN=$TARGETOS    ARCH=$TARGETARCH"
COPY ./${TARGETOS}_${TARGETARCH}/libllvm15_15.0.7-10_${TARGETARCH}.deb /root/libllvm15_15.0.7-10_${TARGETARCH}.deb
COPY ./${TARGETOS}_${TARGETARCH}/libz3-4_4.8.12-3.1_${TARGETARCH}.deb /root/libz3-4_4.8.12-3.1_${TARGETARCH}.deb
COPY ./${TARGETOS}_${TARGETARCH}/mesa-vulkan-drivers_23.2.1-1ubuntu3_${TARGETARCH}.deb /root/mesa-vulkan-drivers_23.2.1-1ubuntu3_${TARGETARCH}.deb

RUN apt update && apt install -y \
    build-essential \
    git \
    pkg-config \
    yasm \
    nasm \
    python3-minimal \
    libsmbclient-dev \
    libbluray-dev \
    libssl-dev \
    ca-certificates \
    libvulkan-dev \
    libvulkan1 \
    vulkan-headers \
    libplacebo-dev \
    vulkan-tools \
    ninja-build \
    spirv-tools \
    libshaderc-dev \
    vulkan-validationlayers-dev \
    dpkg -i /root/libz3-4_4.8.12-3.1_${TARGETARCH}.deb && \
    dpkg -i /root/libllvm15_15.0.7-10_${TARGETARCH}.deb && \
    dpkg -i /root/mesa-vulkan-drivers_23.2.1-1ubuntu3_${TARGETARCH}.deb || apt-get -f install -y && \
    apt-mark hold mesa-vulkan-drivers && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/*.deb


WORKDIR /build

RUN git clone --depth 1 --branch release/7.1 --single-branch https://git.ffmpeg.org/ffmpeg.git

WORKDIR /build/ffmpeg

RUN pkg-config --modversion vulkan && pkg-config --libs vulkan && pkg-config --cflags vulkan

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
