ARG BASE_IMAGE=videosubfinder-build:base-cpu-static
FROM ${BASE_IMAGE} AS builder

ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive

COPY . /tmp/work/videosubfinder-src
RUN cd /tmp/work/videosubfinder-src \
    && cp -rf ./Build/Linux_x64/* /tmp/work/ \
    && mkdir -p /tmp/work/settings && cp -rf ./Settings/general.cfg /tmp/work/settings/ \
    && rm -rf linux_build \
    && mkdir -p linux_build \
    && cd linux_build/ \
    && LD_LIBRARY_PATH=/tmp/work/ffmpeg-build-script/workspace/lib:/usr/local/lib:${LD_LIBRARY_PATH:-} \
       PKG_CONFIG_PATH=/tmp/work/ffmpeg-build-script/workspace/lib/pkgconfig:${PKG_CONFIG_PATH:-} \
       PKG_CONFIG_LIBDIR=/tmp/work/ffmpeg-build-script/workspace/lib:${PKG_CONFIG_LIBDIR:-} \
       cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DUSE_CUDA=OFF \
            -DBUILD_FULL_STATIC=YES \
            -DCMAKE_C_FLAGS="${CFLAGS}" \
            -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
            -DFFMPEG_INCLUDE_DIRS=$(readlink -f /tmp/work/ffmpeg-build-script/workspace/include) \
            -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib/x86_64-linux-gnu -L/tmp/work/ffmpeg-build-script/workspace/lib -static-libgcc -static-libstdc++" \
            .. \
    && cmake --build . --config Release -j "$(nproc)" \
    && cp ./Interfaces/VideoSubFinderCli/VideoSubFinderCli /tmp/work/ \
    && chmod +x /tmp/work/VideoSubFinderCli /tmp/work/VideoSubFinderCli.run \
    && rm -rf /tmp/work/videosubfinder-src
