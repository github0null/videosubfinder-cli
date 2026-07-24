FROM debian:12-slim AS builder

ARG USE_GUI=0

# Target Xeon E5-2640 v4 (Broadwell): AVX2 yes, AVX-512 no.
ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive \
    PATH="/usr/lib/ccache:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tmp/work/ffmpeg-build-script/workspace/bin"

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates ccache build-essential curl git cmake pkg-config \
        nasm yasm gzip xz-utils unzip \
        python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/work
RUN --mount=type=cache,target=/root/.ccache,sharing=private \
    cd /tmp/work/ \
    && git clone https://github.com/markus-perl/ffmpeg-build-script.git -b v1.46 --depth=1 \
    && cd ffmpeg-build-script \
    && bash -c '([[ "aarch64" == "$(uname -m)" ]] && sed -i "s|https://github.com/videolan/x265/archive/Release_3.5.tar.gz|https://bitbucket.org/multicoreware/x265_git/get/931178347b3f73e40798fd5180209654536bbaa5.tar.gz|g" ./build-ffmpeg || true)' \
    && bash -c '([[ "aarch64" == "$(uname -m)" ]] && sed -i "s|https://github.com/georgmartius/vid.stab/archive/v1.1.0.tar.gz|https://github.com/meneguzzi/vid.stab/archive/refs/heads/sse2neon.tar.gz|g" ./build-ffmpeg || true)' \
    # SourceForge giflib/opencore mirrors often return HTML; pin working URLs.
    && sed -i 's|download "https://netcologne.dl.sourceforge.net/project/giflib/giflib-5.2.1.tar.gz"|download "https://ftp.debian.org/debian/pool/main/g/giflib/giflib_5.2.1.orig.tar.gz" "giflib-5.2.1.tar.gz"|g' ./build-ffmpeg \
    && sed -i 's|https://netactuate.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.6.tar.gz|https://gigenet.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.6.tar.gz|g' ./build-ffmpeg \
    && sed -i 's/--enable-static/--enable-static --disable-avx512 --disable-avx512icl/g' ./build-ffmpeg \
    && AUTOINSTALL="yes" ./build-ffmpeg --enable-gpl-and-non-free --build --full-static \
    && true

RUN --mount=type=cache,target=/root/.ccache,sharing=private \
    cd /tmp/work \
    && git clone https://github.com/wxWidgets/wxWidgets.git -b v3.2.2.1 --depth=1 --recurse-submodules -j8 \
    && cd wxWidgets/ \
    && mkdir buildgtk \
    && cd buildgtk/ \
    && ../configure --disable-gui --disable-shared --disable-sys-libs \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/work/wxWidgets \
    && true

RUN --mount=type=cache,target=/root/.ccache,sharing=private \
    cd /tmp/work \
    && git clone https://github.com/opencv/opencv.git -b 4.8.0 --depth=1 \
    && cd opencv \
    && mkdir -p build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DWITH_GTK=OFF -DWITH_FFMPEG=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local -DWITH_TBB=ON -DWITH_V4L=ON -DWITH_OPENGL=ON \
        -DWITH_CUBLAS=OFF -DWITH_CUDA=OFF -DWITH_QT=OFF -DBUILD_SHARED_LIBS=OFF \
        -DCPU_BASELINE=SSE4_2 \
        -DCPU_DISPATCH="SSE4_1;SSE4_2;AVX;AVX2;FP16;FMA3" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        .. \
    && cmake --build . --config Release -j "$(nproc)" \
    && make install \
    && rm -rf /tmp/work/opencv \
    && true

RUN grep -R -l "\.so" /usr/local/lib/cmake/opencv4/*.cmake | xargs -I{} sed -i 's/\.so/.a/g' {}

RUN --mount=type=cache,target=/root/.ccache,sharing=private \
    cd /tmp/work \
    && git clone https://github.com/oneapi-src/oneTBB.git -b v2020.3.3 --depth=1 \
    && cd oneTBB \
    && make tbb_build_prefix=BUILDPREFIX extra_inc=big_iron.inc \
        CXXFLAGS="${CXXFLAGS}" CFLAGS="${CFLAGS}" \
    && cp -f ./build/BUILDPREFIX_release/libtbb.a /usr/local/lib/ \
    && cp -f ./build/BUILDPREFIX_release/libtbbmalloc.a /usr/local/lib \
    && cp -rf ./include/tbb /usr/local/include/ \
    && rm -rf /tmp/work/oneTBB \
    && true
