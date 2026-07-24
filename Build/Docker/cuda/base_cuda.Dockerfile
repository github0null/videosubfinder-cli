# CUDA 12 devel image. Tesla T4 = sm_75 (included in CUDAKernels arches).
FROM nvidia/cuda:12.3.2-devel-ubuntu22.04 as builder

ARG USE_GUI=0

# Target Xeon E5-2640 v4 (Broadwell): AVX2 yes, AVX-512 no.
ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive \
    CUDA_TOOLKIT_PATH=/usr/local/cuda

# Allow ubuntu to cache package downloads
RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get install -y git cmake wget libtbb-dev \
      libavcodec-dev libavformat-dev libswscale-dev libavfilter-dev \
      libavutil-dev libx264-dev build-essential pkg-config \
    && if [ "$USE_GUI" = "1" ]; then apt-get install -y \
        libgtk-3-dev ffmpeg \
      ; fi

RUN mkdir -p /tmp/work \
    && cd /tmp/work \
    && git clone https://github.com/wxWidgets/wxWidgets.git --branch v3.2.2.1 --depth=1 --recurse-submodules -j8 \
    && cd wxWidgets/ \
    && mkdir buildgtk \
    && cd buildgtk/ \
    && ../configure --disable-gui \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/work/wxWidgets

# OpenCV without embedding AVX-512 as baseline; CUDA left to VideoSubFinder kernels.
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
