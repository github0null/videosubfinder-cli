FROM ubuntu:22.04 as builder

# Target Xeon E5-2640 v4 (Broadwell): AVX2 yes, AVX-512 no.
ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive

# Allow ubuntu to cache package downloads
RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt,sharing=private \
    apt-get update
RUN --mount=type=cache,target=/var/cache/apt,sharing=private \
    apt-get install -y git cmake wget libtbb-dev \
      libavcodec-dev libavformat-dev libswscale-dev libavfilter-dev \
      libavutil-dev libx264-dev build-essential pkg-config

RUN mkdir -p /tmp/work \
    && cd /tmp/work \
    && git clone https://github.com/wxWidgets/wxWidgets.git \
    && cd wxWidgets/ \
    && git checkout v3.2.2.1 \
    && git submodule update --init --recursive \
    && mkdir buildgtk \
    && cd buildgtk/ \
    && ../configure --disable-gui \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/work/wxWidgets

# OpenCV: SSE4.2 baseline + dispatch up to AVX2 (no AVX-512 baseline/dispatch).
RUN cd /tmp/work \
    && git clone https://github.com/opencv/opencv.git -b 4.8.0 --depth=1 \
    && cd opencv \
    && mkdir -p build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release \
        -DWITH_GTK=OFF -DWITH_FFMPEG=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DWITH_TBB=ON -DWITH_V4L=ON -DWITH_OPENGL=ON \
        -DWITH_CUBLAS=OFF -DWITH_CUDA=OFF -DWITH_QT=OFF \
        -DCPU_BASELINE=SSE4_2 \
        -DCPU_DISPATCH="SSE4_1;SSE4_2;AVX;AVX2;FP16;FMA3" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        .. \
    && cmake --build . --config Release -j $(nproc) \
    && make install \
    && rm -rf /tmp/work/opencv
