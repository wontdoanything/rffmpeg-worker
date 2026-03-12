FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETOS
ARG TARGETARCH

#RUN echo "RUN=$TARGETOS    ARCH=$TARGETARCH"
#COPY ./${TARGETOS}_${TARGETARCH}/libllvm15_15.0.7-10_${TARGETARCH}.deb /root/libllvm15_15.0.7-10_${TARGETARCH}.deb
#COPY ./${TARGETOS}_${TARGETARCH}/libz3-4_4.8.12-3.1_${TARGETARCH}.deb /root/libz3-4_4.8.12-3.1_${TARGETARCH}.deb
#COPY ./${TARGETOS}_${TARGETARCH}/mesa-vulkan-drivers_23.2.1-1ubuntu3_${TARGETARCH}.deb /root/mesa-vulkan-drivers_23.2.1-1ubuntu3_${TARGETARCH}.deb

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
    mesa-vulkan-drivers \
    libplacebo-dev \
    libshaderc-dev \
    ninja-build \
    spirv-tools \
 && rm -rf /var/lib/apt/lists/*


#RUN dpkg -i /root/libz3-4_4.8.12-3.1_${TARGETARCH}.deb && \
#    dpkg -i /root/libllvm15_15.0.7-10_${TARGETARCH}.deb && \
#    dpkg -i /root/mesa-vulkan-drivers_23.2.1-1ubuntu3_${TARGETARCH}.deb || apt-get -f install -y && \
#    apt-mark hold mesa-vulkan-drivers && \
#    rm -rf /var/lib/apt/lists/*  && \
#    rm -rf /root/*.deb


WORKDIR /build



RUN git clone --depth 1 --branch release/7.1 --single-branch https://git.ffmpeg.org/ffmpeg.git

WORKDIR /build/ffmpeg

RUN pkg-config --libs vulkan
RUN pkg-config --modversion vulkan
RUN pkg-config --modversion libplacebo

RUN ls /usr/include/vulkan


RUN pkg-config --cflags vulkan

#ENV PKG_CONFIG_PATH=/usr/lib/${TARGETARCH}-linux-gnu-linux-gnu/pkgconfig

RUN if [ "$TARGETARCH" = "amd64" ]; then export DEB_ARCH=x86_64-linux-gnu; \
    elif [ "$TARGETARCH" = "arm64" ]; then export DEB_ARCH=aarch64-linux-gnu; \
    else echo "Unsupported TARGETARCH $TARGETARCH"; exit 1; fi && \
    echo "Using DEB_ARCH=$DEB_ARCH"

# 设置 pkg-config 搜索路径
ENV PKG_CONFIG_PATH=/usr/lib/${DEB_ARCH}/pkgconfig:/usr/lib/pkgconfig

RUN pkg-config --debug vulkan
RUN ls -l /usr/lib/*-linux-gnu/libvulkan*

# 模拟 configure 内部测试
# 创建一个合法 main
RUN echo '#include <vulkan/vulkan.h>' > test_vulkan.c
RUN echo 'int main() { return 0; }' >> test_vulkan.c
RUN cc test_vulkan.c -lvulkan -o test_vulkan
RUN ./test_vulkan
RUN echo $?


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
    --extra-cflags="-I/usr/include" \
    --extra-ldflags="-L/usr/lib/${DEB_ARCH1}" \
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
