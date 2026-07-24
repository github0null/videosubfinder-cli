ARG BASE_IMAGE=videosubfinder-build:base
FROM ${BASE_IMAGE}

ENV CFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    CXXFLAGS="-O3 -march=broadwell -mtune=broadwell" \
    DEBIAN_FRONTEND=noninteractive

COPY Build/Docker/common/bundle_runtime_libs.sh /usr/local/bin/bundle_runtime_libs.sh
RUN chmod +x /usr/local/bin/bundle_runtime_libs.sh

COPY . /tmp/work/videosubfinder-src
RUN cd /tmp/work/videosubfinder-src \
    && cp -rf ./Build/Linux_x64/* /tmp/work/ \
    && mkdir -p /tmp/work/settings && cp -rf ./Settings/general.cfg /tmp/work/settings/ \
    && rm -rf linux_build \
    && mkdir -p linux_build \
    && cd linux_build/ \
    && cmake -DCMAKE_BUILD_TYPE=Release -DUSE_CUDA=OFF \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN" \
        .. \
    && cmake --build . --config Release -j $(nproc) \
    && cp ./Interfaces/VideoSubFinderCli/VideoSubFinderCli /tmp/work/VideoSubFinderCli.bin \
    && rm -rf /tmp/work/videosubfinder-src

# Bundle OpenCV / wx / ffmpeg / tbb so Debian 12 hosts need no extra packages.
RUN bash /usr/local/bin/bundle_runtime_libs.sh /tmp/work /tmp/work/VideoSubFinderCli.bin \
      "/usr/local/lib/libwx_baseu-*.so.*" \
      "/usr/local/lib/libopencv_*.so.*" \
    && mv -f /tmp/work/VideoSubFinderCli.bin /tmp/work/VideoSubFinderCli \
    && chmod +x /tmp/work/VideoSubFinderCli /tmp/work/VideoSubFinderCli.run
