# Build on Debian 12 with CUDA 12 (Tesla T4 = sm_75).
FROM debian:12-slim AS builder

ARG USE_GUI=0
ARG CUDA_TOOLKIT_VERSION=12-4

# Target Xeon E5-2640 v4 (Broadwell): AVX2 yes, AVX-512 no.
ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive \
    CUDA_TOOLKIT_PATH=/usr/local/cuda \
    PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg2 \
    && wget -q https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm -f cuda-keyring_1.1-1_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        git cmake build-essential pkg-config \
        libtbb-dev \
        libavcodec-dev libavformat-dev libswscale-dev libavfilter-dev \
        libavutil-dev libx264-dev \
        cuda-nvcc-${CUDA_TOOLKIT_VERSION} \
        cuda-cudart-dev-${CUDA_TOOLKIT_VERSION} \
        cuda-driver-dev-${CUDA_TOOLKIT_VERSION} \
        cuda-cccl-${CUDA_TOOLKIT_VERSION} \
        libnpp-dev-${CUDA_TOOLKIT_VERSION} \
    && if [ "$USE_GUI" = "1" ]; then apt-get install -y --no-install-recommends \
        libgtk-3-dev ffmpeg \
      ; fi \
    && CUDA_DIR="$(ls -d /usr/local/cuda-[0-9]* 2>/dev/null | sort -V | tail -1)" \
    && test -n "$CUDA_DIR" \
    && rm -rf /usr/local/cuda \
    && ln -s "$CUDA_DIR" /usr/local/cuda \
    && ls -la /usr/local/cuda/bin/nvcc \
    && (ls /usr/local/cuda/lib64/libcudart_static.a \
          /usr/local/cuda/lib64/libnppicc_static.a \
          /usr/local/cuda/lib64/libnppig_static.a \
          /usr/local/cuda/lib64/libnppc_static.a \
          /usr/local/cuda/lib64/libculibos.a \
        || ls /usr/local/cuda/targets/x86_64-linux/lib/libcudart_static.a \
              /usr/local/cuda/targets/x86_64-linux/lib/libnppicc_static.a \
              /usr/local/cuda/targets/x86_64-linux/lib/libnppig_static.a \
              /usr/local/cuda/targets/x86_64-linux/lib/libnppc_static.a \
              /usr/local/cuda/targets/x86_64-linux/lib/libculibos.a) \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/work

RUN cd /tmp/work \
    && git clone https://github.com/wxWidgets/wxWidgets.git --branch v3.2.2.1 --depth=1 --recurse-submodules -j8 \
    && cd wxWidgets/ \
    && mkdir buildgtk \
    && cd buildgtk/ \
    && ../configure --disable-gui \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/work/wxWidgets

# OpenCV uses Debian's libtbb (oneTBB). Do NOT install an older oneTBB into
# /usr/local — mismatched headers vs libtbb.so.12 break the opencv_core link.
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
    && cmake --build . --config Release -j "$(nproc)" \
    && make install \
    && rm -rf /tmp/work/opencv
